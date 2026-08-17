"""Espaces de travail : une base de donnees par compte.

Chaque compte importe ce qu'il veut sans jamais toucher aux donnees d'un
autre. L'isolation ne repose pas sur un filtre applique aux requetes SQL --
il suffirait d'en oublier une pour ouvrir une fuite -- mais sur des fichiers
distincts : deux comptes n'ouvrent jamais la meme base.
"""

from __future__ import annotations

import logging
from pathlib import Path
import re
import shutil
import sqlite3
from threading import Lock

from app.core.runtime_paths import app_data_root, seed_data_path
from database.connection import DATABASE_PATH, database_manager, utiliser_espace

logger = logging.getLogger(__name__)

_ESPACES_DIR = app_data_root() / "espaces"

# Espaces deja prepares depuis le demarrage du processus : migrations jouees
# et regles de calcul a jour. Evite de refaire ce travail a chaque requete.
_espaces_prets: set[str] = set()
_verrou = Lock()


def nom_de_fichier(identifiant: str) -> str:
    """Transforme un identifiant de compte en nom de fichier sur.

    Un identifiant contient ce que l'administrateur y a mis : sans
    normalisation, « ../../etc/passwd » designerait un fichier hors du
    dossier des espaces.
    """

    normalise = re.sub(r"[^a-zA-Z0-9_-]+", "_", identifiant.strip().lower())
    normalise = normalise.strip("_")
    return normalise or "compte"


def chemin_espace(identifiant: str) -> Path:
    return _ESPACES_DIR / f"{nom_de_fichier(identifiant)}.db"


# Tables conservees dans un espace neuf : le dispositif prudentiel lui-meme.
# Grilles de ponderation, facteurs de conversion, notations, definitions
# d'indicateurs, parametres de calcul. Les vider rendrait tout calcul
# impossible.
#
# Tout le reste est efface. C'est volontairement l'inverse d'une liste de
# tables a vider : une table de donnees ajoutee demain serait alors oubliee, et
# un nouvel utilisateur decouvrirait le portefeuille de demonstration dans son
# espace. Ici, l'oubli se traduit par une table vide -- visible et sans
# consequence sur les donnees d'autrui.
_TABLES_REFERENCE: frozenset[str] = frozenset(
    {
        "schema_migrations",
        # Conservee, mais nettoyee cle par cle : voir _CLES_METADONNEES_TECHNIQUES.
        "metadonnees_app",
        # Grilles lues par l'ecran Referentiels.
        "baremes_ponderation",
        "baremes_ccf",
        "references_notation",
        "references_pays_souverains",
        # Memes grilles sous leur nom d'avant le renommage de 2021 : elles
        # servent de source au rapatriement joue au demarrage.
        "ccf_references",
        "rating_references",
        "risk_weight_references",
        "ro_kri_definitions",
        "op_beta_lignes",
        "op_parametres_aib",
        "op_parametres_as",
        "op_parametres_seuils",
        "op_risk_parametres",
    }
)


# Seules cles de `metadonnees_app` conservees dans un espace neuf.
#
# Cette table melange du technique et des DONNEES : elle porte l'exigence de
# fonds propres du risque de marche et le portefeuille de marche lui-meme.
# Garder la table entiere faisait apparaitre, dans un espace vide, un RWA
# marche de 204 Md herite de la demonstration -- et un capital requis de
# 18,42 Md face a zero exposition.
#
# Comme pour les tables, on declare ce qu'on GARDE : une cle ajoutee demain
# sera purgee par defaut plutot que transmise a tous les nouveaux comptes.
_CLES_METADONNEES_TECHNIQUES: frozenset[str] = frozenset(
    {
        "exposure_calc_rules_version",
        "exposure_calc_rules_recalculated_at",
        "storage_backend",
        "market_storage_backend",
    }
)


def _vider_donnees_metier(chemin: Path) -> None:
    """Efface tout ce qui appartient a un utilisateur, garde le dispositif.

    Un espace neuf doit etre entierement vide : expositions, contreparties,
    garanties, fonds propres, positions de marche, incidents operationnels.
    Sans cela, le nouvel arrivant croirait consulter un portefeuille reel
    alors qu'il regarde le jeu de demonstration.
    """

    connexion = sqlite3.connect(chemin)
    try:
        connexion.execute("PRAGMA foreign_keys = OFF")
        tables = [
            str(ligne[0])
            for ligne in connexion.execute(
                "SELECT name FROM sqlite_master "
                "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
            )
        ]
        for table in tables:
            if table in _TABLES_REFERENCE:
                continue
            connexion.execute(f'DELETE FROM "{table}"')

        if "metadonnees_app" in tables:
            marques = ", ".join("?" for _ in _CLES_METADONNEES_TECHNIQUES)
            connexion.execute(
                f"DELETE FROM metadonnees_app WHERE cle NOT IN ({marques})",
                tuple(_CLES_METADONNEES_TECHNIQUES),
            )
        connexion.commit()
        connexion.execute("VACUUM")
    finally:
        connexion.close()


def _source_de_depart() -> Path:
    """Base servant de point de depart a un nouvel espace.

    Le jeu de demonstration livre avec l'application, de preference a la base
    commune : celle-ci porte les comptes et leurs empreintes de mots de passe,
    qui n'ont rien a faire dans l'espace d'un utilisateur.
    """

    graine = seed_data_path("rwa_data.db")
    return graine if graine.exists() else DATABASE_PATH


def preparer_espace(identifiant: str) -> Path:
    """Retourne l'espace du compte, en le creant au besoin.

    Un espace neuf est ENTIEREMENT vide de donnees : chacun part de zero et
    importe les siennes. Seul le dispositif prudentiel (grilles, parametres)
    est conserve, sans quoi aucun calcul ne serait possible.

    La structure est reprise de la base de reference plutot que reconstruite
    depuis le schema : la chaine de migrations s'appuie sur des tables
    heritees et ne sait plus produire une base neuve a elle seule.
    """

    chemin = chemin_espace(identifiant)
    cle = chemin.name

    with _verrou:
        if cle in _espaces_prets and chemin.exists():
            return chemin

        _ESPACES_DIR.mkdir(parents=True, exist_ok=True)
        if not chemin.exists():
            source = _source_de_depart()
            if source.exists():
                shutil.copy2(source, chemin)
                _vider_donnees_metier(chemin)
                logger.info(
                    "Espace de travail vierge cree pour « %s ».",
                    identifiant,
                )

        # Schema et migrations joues sur CET espace : une base copiee d'une
        # version anterieure doit rattraper son retard avant d'etre servie.
        jeton = utiliser_espace(chemin)
        try:
            database_manager.initialize()
            _rejouer_regles_si_besoin(identifiant)
        finally:
            from database.connection import restaurer_espace

            restaurer_espace(jeton)

        _espaces_prets.add(cle)
        return chemin


def _rejouer_regles_si_besoin(identifiant: str) -> None:
    """Aligne l'espace sur la version courante des regles de calcul."""

    try:
        from database.services.exposure_recalculation_service import (
            recalculate_all_exposures,
        )

        resultat = recalculate_all_exposures()
        if resultat.get("status") == "completed":
            logger.info(
                "Espace « %s » : %s expositions recalculees sur la version %s.",
                identifiant,
                resultat.get("recalculated_count"),
                resultat.get("version"),
            )
    except Exception:
        # Un espace qui ne se recalcule pas reste consultable avec ses valeurs
        # precedentes : mieux vaut une donnee datee qu'une session refusee.
        logger.exception(
            "Recalcul reglementaire impossible pour l'espace « %s ».",
            identifiant,
        )
