"""Connexion SQLite, initialisation et utilitaires de base."""

from __future__ import annotations

from contextlib import contextmanager
from contextvars import ContextVar
from datetime import datetime
from pathlib import Path
import re
import shutil
import sqlite3
from threading import Lock
from typing import Iterator

from app.core.runtime_paths import (
    app_data_root,
    backups_dir,
    ensure_seed_data_file,
    resource_path,
)

DATA_DIR = app_data_root()
BACKUP_DIR = backups_dir()
DATABASE_PATH = ensure_seed_data_file("rwa_data.db")
SCHEMA_PATH = resource_path("database", "schema.sql")
MIGRATIONS_DIR = resource_path("database", "migrations")


# Espace de travail de la requete en cours.
#
# Chaque compte possede sa propre base : ce qu'il importe ne doit jamais
# apparaitre chez un autre. Le chemin est pose par le garde d'authentification
# au debut de la requete, et lu ici au moment d'ouvrir la connexion. Ainsi
# TOUS les depots suivent automatiquement, sans qu'aucune requete SQL n'ait a
# porter un identifiant d'utilisateur : impossible d'en oublier une.
#
# Hors requete (demarrage, taches de fond, application de bureau), la valeur
# est absente et la base par defaut s'applique.
_espace_courant: ContextVar[Path | None] = ContextVar("_espace_courant", default=None)


def utiliser_espace(chemin: Path | None):
    """Bascule la base utilisee par le reste de la requete."""

    return _espace_courant.set(chemin)


def restaurer_espace(jeton) -> None:
    _espace_courant.reset(jeton)


def espace_courant() -> Path:
    """Base effectivement utilisee : celle de la requete, sinon la commune."""

    return _espace_courant.get() or DATABASE_PATH


@contextmanager
def base_commune() -> Iterator[None]:
    """Force la base commune le temps du bloc.

    Les comptes et les sessions n'appartiennent a aucun espace de travail :
    ils vivent dans la base commune. Sans cette bascule, une deconnexion
    ecrirait dans l'espace de l'utilisateur et la session ne serait jamais
    revoquee.
    """

    jeton = _espace_courant.set(None)
    try:
        yield
    finally:
        _espace_courant.reset(jeton)


def utcnow_iso() -> str:
    return datetime.utcnow().replace(microsecond=0).isoformat()


class DatabaseManager:
    """Gère la base SQLite locale de l'application."""

    def __init__(
        self,
        db_path: Path = DATABASE_PATH,
        schema_path: Path = SCHEMA_PATH,
        migrations_dir: Path = MIGRATIONS_DIR,
    ) -> None:
        self.db_path = db_path
        self.schema_path = schema_path
        self.migrations_dir = migrations_dir
        self._lock = Lock()

    def connect(self) -> sqlite3.Connection:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        # Le chemin est resolu a CHAQUE connexion, jamais memorise : c'est ce
        # qui permet a deux requetes simultanees de travailler sur deux
        # espaces differents sans se marcher dessus.
        connection = sqlite3.connect(
            espace_courant() if self.db_path == DATABASE_PATH else self.db_path,
            timeout=30,
            check_same_thread=False,
        )
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA journal_mode = WAL")
        connection.execute("PRAGMA synchronous = NORMAL")
        connection.execute("PRAGMA temp_store = MEMORY")
        connection.execute("PRAGMA cache_size = -64000")
        connection.execute("PRAGMA mmap_size = 268435456")
        connection.execute("PRAGMA busy_timeout = 30000")
        return connection

    def initialize(self) -> None:
        with self._lock:
            connection = self.connect()
            try:
                connection.execute(
                    """
                    CREATE TABLE IF NOT EXISTS schema_migrations (
                        version INTEGER PRIMARY KEY,
                        name TEXT NOT NULL,
                        applied_at TEXT NOT NULL
                    )
                    """
                )
                schema_sql = self.schema_path.read_text(encoding="utf-8")
                connection.executescript(schema_sql)
                self._apply_migrations(connection)
                self._ensure_runtime_compatibility(connection)
                connection.commit()
            finally:
                connection.close()

    def _apply_migrations(self, connection: sqlite3.Connection) -> None:
        if not self.migrations_dir.exists():
            return
        applied_versions = {
            int(row["version"])
            for row in connection.execute("SELECT version FROM schema_migrations")
        }

        # Plusieurs fichiers peuvent partager le même préfixe numérique (collision
        # de version, ex. 012_residential_mortgage_rules.sql et
        # 012_retail_rules.sql). Regrouper par version avant d'itérer garantit
        # qu'aucun script n'est plus jamais ignoré silencieusement : tous les
        # fichiers d'une même version sont exécutés (dans l'ordre alphabétique)
        # avant que la version ne soit marquée comme appliquée.
        migrations_by_version: dict[int, list[Path]] = {}
        for migration_path in sorted(self.migrations_dir.glob("*.sql")):
            prefix = migration_path.stem.split("_", maxsplit=1)[0]
            try:
                version = int(prefix)
            except ValueError:
                continue
            migrations_by_version.setdefault(version, []).append(migration_path)

        for version in sorted(migrations_by_version):
            if version in applied_versions:
                continue
            migration_paths = migrations_by_version[version]
            names = []
            for migration_path in migration_paths:
                sql = migration_path.read_text(encoding="utf-8")
                if sql.strip():
                    for statement in self._iter_sql_statements(sql):
                        try:
                            connection.execute(statement)
                        except sqlite3.OperationalError as exc:
                            if self._can_ignore_migration_error(connection, statement, exc):
                                continue
                            raise
                names.append(migration_path.stem)
            connection.execute(
                """
                INSERT INTO schema_migrations(version, name, applied_at)
                VALUES (?, ?, ?)
                """,
                (version, " + ".join(names), utcnow_iso()),
            )
            applied_versions.add(version)

    def _iter_sql_statements(self, sql: str) -> list[str]:
        """Découpe un script SQL simple en instructions exécutables."""
        cleaned_lines: list[str] = []
        for line in sql.splitlines():
            stripped = line.strip()
            if stripped.startswith("--"):
                continue
            cleaned_lines.append(line)
        cleaned_sql = "\n".join(cleaned_lines)
        return [statement.strip() for statement in cleaned_sql.split(";") if statement.strip()]

    def _can_ignore_migration_error(
        self,
        connection: sqlite3.Connection,
        statement: str,
        error: sqlite3.OperationalError,
    ) -> bool:
        message = str(error).lower()
        if "duplicate column name" in message:
            match = re.search(
                r"alter\s+table\s+([a-zA-Z_][\w]*)\s+add\s+column\s+([a-zA-Z_][\w]*)",
                statement,
                flags=re.IGNORECASE,
            )
            if not match:
                return False
            table_name, column_name = match.group(1), match.group(2)
            existing_columns = {
                str(row["name"]).lower()
                for row in connection.execute(f"PRAGMA table_info({table_name})")
            }
            return column_name.lower() in existing_columns
        if "already another table or index with this name" in message:
            match = re.search(
                r"alter\s+table\s+([a-zA-Z_][\w]*)\s+rename\s+to\s+([a-zA-Z_][\w]*)",
                statement,
                flags=re.IGNORECASE,
            )
            if not match:
                return False
            target_name = match.group(2)
            return (
                connection.execute(
                    """
                    SELECT 1
                    FROM sqlite_master
                    WHERE lower(name) = lower(?)
                      AND type IN ('table', 'index', 'view', 'trigger')
                    LIMIT 1
                    """,
                    (target_name,),
                ).fetchone()
                is not None
            )
        if "already exists" in message:
            return True
        # DROP COLUMN sur une colonne déjà supprimée (DB déjà migrée ou schéma frais)
        if "no such column" in message:
            if re.search(r"alter\s+table\s+\S+\s+drop\s+column", statement, re.IGNORECASE):
                return True
            # RENAME COLUMN sur une colonne absente = déjà renommée
            if re.search(r"alter\s+table\s+\S+\s+rename\s+column", statement, re.IGNORECASE):
                return True
            # INSERT...SELECT depuis des colonnes absentes : schéma frais, rien à migrer
            if statement.strip().upper().startswith("INSERT"):
                return True
        # Table absente : déjà renommée/restructurée par une migration ultérieure,
        # ou schéma frais où schema.sql contient directement la structure finale.
        # Dans les deux cas, il n'y a rien à migrer.
        if "no such table" in message:
            return True
        return False

    # Renommages de la migration 021 restés sans effet : (table française,
    # table anglaise d'origine, colonnes françaises, colonnes anglaises).
    _REFERENTIELS_A_REPRENDRE: tuple[tuple[str, str, str, str], ...] = (
        (
            "baremes_ponderation",
            "risk_weight_references",
            "id, segment, notation, ponderation, approche",
            "id, segment, rating, risk_weight, approach",
        ),
        (
            "baremes_ccf",
            "ccf_references",
            "id, type_engagement, ccf",
            "id, engagement_type, ccf",
        ),
        (
            "references_notation",
            "rating_references",
            "id, libelle, description, ordre_tri",
            "id, label, description, sort_order",
        ),
    )

    def _reprendre_referentiels_orphelins(
        self, connection: sqlite3.Connection
    ) -> None:
        """Rapatrie les référentiels restés dans les tables d'avant 2021.

        `schema.sql` s'exécute AVANT les migrations et crée déjà les tables
        françaises. Le « ALTER TABLE ... RENAME TO » de la migration 021
        échouait donc sur « une table de ce nom existe déjà » — erreur que le
        moteur ignore volontairement pour rendre les migrations rejouables.

        Le renommage devait pourtant emporter les données : elles sont restées
        dans les tables anglaises, invisibles de l'écran Référentiels qui lit
        les françaises. Le moteur de calcul, lui, porte ses propres grilles :
        rien ne signalait la perte.
        """

        tables_presentes = {
            str(ligne["name"]).lower()
            for ligne in connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }

        for cible, source, colonnes_cible, colonnes_source in (
            self._REFERENTIELS_A_REPRENDRE
        ):
            if cible not in tables_presentes or source not in tables_presentes:
                continue
            # On ne remplit que le vide : une table déjà alimentée fait foi,
            # y compris si elle a été corrigée à la main depuis.
            deja = connection.execute(
                f'SELECT COUNT(*) FROM "{cible}"'
            ).fetchone()[0]
            if deja:
                continue
            connection.execute(
                f'INSERT INTO "{cible}"({colonnes_cible}) '
                f'SELECT {colonnes_source} FROM "{source}"'
            )

    def _ensure_runtime_compatibility(self, connection: sqlite3.Connection) -> None:
        # Note : les colonnes de type prudentiel ont été déplacées dans leurs
        # sous-tables respectives par la migration 019. La migration 021 a renommé
        # toutes les tables et colonnes en français.
        self._reprendre_referentiels_orphelins(connection)
        self._ensure_table_column(
            connection,
            table_name="expositions",
            column_name="champs_source_json",
            column_definition="TEXT NOT NULL DEFAULT '{}'",
        )
        for column_name, column_definition in (
            ("devise_collateral", "TEXT NOT NULL DEFAULT 'XOF'"),
            (
                "type_collateral",
                "TEXT NOT NULL DEFAULT 'Liquidités dans la même devise'",
            ),
            ("convertible_indice_principal", "INTEGER NOT NULL DEFAULT 1"),
            ("opcvm_decote_max", "REAL NOT NULL DEFAULT 0.30"),
            ("elements_panier_json", "TEXT NOT NULL DEFAULT '[]'"),
            ("devise_exposition", "TEXT NOT NULL DEFAULT 'XOF'"),
            ("ponderation", "REAL NOT NULL DEFAULT 0"),
            ("collateral_eligible", "INTEGER NOT NULL DEFAULT 1"),
            ("motif_ineligibilite", "TEXT NOT NULL DEFAULT ''"),
            ("he", "REAL NOT NULL DEFAULT 0"),
            ("hc", "REAL NOT NULL DEFAULT 0"),
            ("hfx", "REAL NOT NULL DEFAULT 0"),
            ("eva", "REAL NOT NULL DEFAULT 0"),
            ("cva", "REAL NOT NULL DEFAULT 0"),
            ("ead_apres_crm_financee", "REAL NOT NULL DEFAULT 0"),
            ("rwa_final", "REAL NOT NULL DEFAULT 0"),
            ("gain_crm", "REAL NOT NULL DEFAULT 0"),
        ):
            self._ensure_table_column(
                connection,
                table_name="crm_financee",
                column_name=column_name,
                column_definition=column_definition,
            )

    def _ensure_table_column(
        self,
        connection: sqlite3.Connection,
        *,
        table_name: str,
        column_name: str,
        column_definition: str,
    ) -> None:
        existing_columns = {
            str(row["name"])
            for row in connection.execute(f"PRAGMA table_info({table_name})")
        }
        if column_name in existing_columns:
            return
        connection.execute(
            f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_definition}"
        )

    @contextmanager
    def read_connection(self) -> Iterator[sqlite3.Connection]:
        """Fournit une connexion en lecture qui se ferme automatiquement."""
        connection = self.connect()
        try:
            yield connection
        finally:
            connection.close()

    @contextmanager
    def transaction(self) -> Iterator[sqlite3.Connection]:
        connection = self.connect()
        try:
            connection.execute("BEGIN")
            yield connection
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    def create_backup(self, prefix: str = "rwa_data") -> Path | None:
        if not self.db_path.exists():
            return None
        BACKUP_DIR.mkdir(parents=True, exist_ok=True)
        backup_path = BACKUP_DIR / f"{prefix}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.db"
        shutil.copy2(self.db_path, backup_path)
        return backup_path


database_manager = DatabaseManager()
