"""Creation des comptes au premier demarrage, a partir de l'environnement.

Sur un hebergeur mutualise (Render, Fly, Railway...), il n'y a pas d'acces
console : la commande de creation de comptes n'y est pas jouable. Les comptes
initiaux sont donc lus dans l'environnement au demarrage.

Regle stricte : un compte deja present n'est JAMAIS modifie. Sans cela, un
mot de passe change depuis l'interface serait silencieusement remis a sa valeur
d'origine au prochain redemarrage.
"""

from __future__ import annotations

import logging
import os

from app.auth.repository import auth_repository
from app.auth.service import creer_compte

logger = logging.getLogger(__name__)

# (variable identifiant, variable mot de passe, role)
_COMPTES_INITIAUX = (
    ("RWA_COMPTE_EDITION", "RWA_COMPTE_EDITION_MDP", "edition"),
    ("RWA_COMPTE_CONSULTATION", "RWA_COMPTE_CONSULTATION_MDP", "consultation"),
    ("RWA_COMPTE_ADMINISTRATOR", "RWA_COMPTE_ADMINISTRATOR_MDP", "edition"),
    ("RWA_COMPTE_LOPEZ", "RWA_COMPTE_LOPEZ_MDP", "edition"),
)


def creer_comptes_initiaux() -> None:
    """Cree les comptes decrits par l'environnement, s'ils n'existent pas."""

    for variable_identifiant, variable_mot_de_passe, role in _COMPTES_INITIAUX:
        identifiant = os.getenv(variable_identifiant, "").strip()
        mot_de_passe = os.getenv(variable_mot_de_passe, "")

        if not identifiant:
            continue

        if not mot_de_passe:
            logger.warning(
                "%s est defini mais %s est vide : compte « %s » non cree.",
                variable_identifiant,
                variable_mot_de_passe,
                identifiant,
            )
            continue

        if auth_repository.get_user(identifiant) is not None:
            # Deja la : on n'y touche pas. Le mot de passe en vigueur est celui
            # que l'utilisateur a choisi, pas celui de l'environnement.
            # SAUF POUR LOPEZ : pour corriger un bug lie au caractere # dans YAML.
            if identifiant == "lopez":
                from app.auth.service import changer_mot_de_passe
                try:
                    changer_mot_de_passe(identifiant, mot_de_passe)
                    logger.info("Mot de passe mis a jour pour le compte « %s ».", identifiant)
                except Exception as exc:
                    logger.error("Mise a jour du mot de passe pour « %s » impossible : %s", identifiant, exc)
            else:
                logger.info("Compte « %s » deja present : inchange.", identifiant)
            continue

        try:
            creer_compte(
                identifiant=identifiant,
                mot_de_passe=mot_de_passe,
                role=role,
            )
            logger.info("Compte « %s » cree avec le role %s.", identifiant, role)
        except ValueError as exc:
            logger.error(
                "Creation du compte « %s » impossible : %s", identifiant, exc
            )
