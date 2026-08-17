"""Acces base pour les comptes et les sessions."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from database.connection import base_commune, database_manager, utcnow_iso


def _row_to_user(row: Any) -> dict[str, Any]:
    return {
        "id": int(row["id"]),
        "identifiant": str(row["identifiant"]),
        "mot_de_passe_hash": str(row["mot_de_passe_hash"]),
        "role": str(row["role"]),
        "nom_complet": row["nom_complet"],
        "actif": bool(row["actif"]),
        "derniere_connexion": row["derniere_connexion"],
    }


class AuthRepository:
    """Lit et ecrit les comptes applicatifs et leurs sessions."""

    def get_user(self, identifiant: str) -> dict[str, Any] | None:
        with base_commune(), database_manager.read_connection() as connection:
            row = connection.execute(
                "SELECT * FROM utilisateurs WHERE identifiant = ?",
                (identifiant.strip(),),
            ).fetchone()
        return _row_to_user(row) if row else None

    def list_users(self) -> list[dict[str, Any]]:
        with base_commune(), database_manager.read_connection() as connection:
            rows = connection.execute(
                "SELECT * FROM utilisateurs ORDER BY identifiant"
            ).fetchall()
        return [_row_to_user(row) for row in rows]

    def create_user(
        self,
        *,
        identifiant: str,
        mot_de_passe_hash: str,
        role: str,
        nom_complet: str | None = None,
    ) -> None:
        maintenant = utcnow_iso()
        with base_commune(), database_manager.transaction() as connection:
            connection.execute(
                """
                INSERT INTO utilisateurs(
                    identifiant, mot_de_passe_hash, role, nom_complet,
                    actif, cree_le, modifie_le
                )
                VALUES(?, ?, ?, ?, 1, ?, ?)
                """,
                (
                    identifiant.strip(),
                    mot_de_passe_hash,
                    role,
                    nom_complet,
                    maintenant,
                    maintenant,
                ),
            )

    def update_password(self, *, identifiant: str, mot_de_passe_hash: str) -> bool:
        with base_commune(), database_manager.transaction() as connection:
            cursor = connection.execute(
                """
                UPDATE utilisateurs
                SET mot_de_passe_hash = ?, modifie_le = ?
                WHERE identifiant = ?
                """,
                (mot_de_passe_hash, utcnow_iso(), identifiant.strip()),
            )
            return cursor.rowcount > 0

    def set_active(self, *, identifiant: str, actif: bool) -> bool:
        with base_commune(), database_manager.transaction() as connection:
            cursor = connection.execute(
                "UPDATE utilisateurs SET actif = ?, modifie_le = ? WHERE identifiant = ?",
                (1 if actif else 0, utcnow_iso(), identifiant.strip()),
            )
            return cursor.rowcount > 0

    def touch_last_login(self, *, utilisateur_id: int) -> None:
        with base_commune(), database_manager.transaction() as connection:
            connection.execute(
                "UPDATE utilisateurs SET derniere_connexion = ? WHERE id = ?",
                (utcnow_iso(), utilisateur_id),
            )

    def open_session(
        self,
        *,
        session_id: str,
        utilisateur_id: int,
        jeton_hash: str,
        expire_le: datetime,
    ) -> None:
        with base_commune(), database_manager.transaction() as connection:
            connection.execute(
                """
                INSERT INTO sessions_utilisateur(
                    id, utilisateur_id, jeton_hash, cree_le, expire_le
                )
                VALUES(?, ?, ?, ?, ?)
                """,
                (
                    session_id,
                    utilisateur_id,
                    jeton_hash,
                    utcnow_iso(),
                    expire_le.astimezone(timezone.utc).replace(tzinfo=None).isoformat(
                        timespec="seconds"
                    ),
                ),
            )

    def get_active_session(self, *, session_id: str, jeton_hash: str) -> dict[str, Any] | None:
        """Retourne la session si elle existe, n'est pas revoquee et correspond au jeton."""

        with base_commune(), database_manager.read_connection() as connection:
            row = connection.execute(
                """
                SELECT id, utilisateur_id, jeton_hash, expire_le, revoque_le
                FROM sessions_utilisateur
                WHERE id = ?
                """,
                (session_id,),
            ).fetchone()
        if row is None or row["revoque_le"] is not None:
            return None
        # Le jeton presente doit etre exactement celui enregistre : une session
        # deja tournee ne peut pas etre rejouee avec l'ancien jeton.
        if str(row["jeton_hash"]) != jeton_hash:
            return None
        return {
            "id": str(row["id"]),
            "utilisateur_id": int(row["utilisateur_id"]),
            "expire_le": str(row["expire_le"]),
        }

    def revoke_session(self, *, session_id: str) -> None:
        with base_commune(), database_manager.transaction() as connection:
            connection.execute(
                "UPDATE sessions_utilisateur SET revoque_le = ? WHERE id = ? AND revoque_le IS NULL",
                (utcnow_iso(), session_id),
            )

    def revoke_user_sessions(self, *, utilisateur_id: int) -> None:
        with base_commune(), database_manager.transaction() as connection:
            connection.execute(
                """
                UPDATE sessions_utilisateur
                SET revoque_le = ?
                WHERE utilisateur_id = ? AND revoque_le IS NULL
                """,
                (utcnow_iso(), utilisateur_id),
            )

    def purge_expired_sessions(self) -> int:
        with base_commune(), database_manager.transaction() as connection:
            cursor = connection.execute(
                "DELETE FROM sessions_utilisateur WHERE expire_le < ?",
                (utcnow_iso(),),
            )
            return cursor.rowcount


auth_repository = AuthRepository()
