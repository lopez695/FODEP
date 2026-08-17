"""Gestion de l'equipe depuis l'application.

L'offre d'hebergement gratuite n'ouvre aucune console : sans ces routes,
ajouter un troisieme membre imposerait de modifier la configuration du
serveur et de le redeployer. La gestion est donc reservee au role
« edition » -- y compris la simple LISTE, qui revele les identifiants et les
dernieres connexions de toute l'equipe.
"""

from __future__ import annotations

import importlib
import os

import pytest
from fastapi.testclient import TestClient

_SECRET = "secret-de-test-suffisamment-long-pour-etre-accepte"
_MDP_EDITION = "MotDePasseEditionEssai2026"
_MDP_CONSULTATION = "MotDePasseConsultEssai2026"


@pytest.fixture(scope="module")
def client():
    """Monte l'API avec authentification active et comptes de test.

    Les modules d'authentification sont rechargés : `settings` est un objet
    capturé à l'import, et un autre module de test qui recharge la
    configuration laisserait ici un secret périmé — les jetons émis ne
    seraient alors plus vérifiables.
    """

    os.environ["RWA_AUTH_ENABLED"] = "1"
    os.environ["RWA_JWT_SECRET"] = _SECRET
    os.environ["RWA_REFRESH_COOKIE_SECURE"] = "0"

    from app.core import config as config_module

    importlib.reload(config_module)
    for nom in (
        "app.auth.security",
        "app.auth.repository",
        "app.auth.service",
        "app.auth.guard",
        "app.auth.routes",
        "app.main",
    ):
        importlib.reload(importlib.import_module(nom))

    from app.auth.repository import auth_repository
    from app.auth.service import creer_compte
    from app.main import app
    from database.connection import database_manager

    database_manager.initialize()
    for identifiant, role, mot_de_passe in (
        ("equipe_editeur", "edition", _MDP_EDITION),
        ("equipe_lecteur", "consultation", _MDP_CONSULTATION),
    ):
        if _depot().get_user(identifiant) is None:
            creer_compte(
                identifiant=identifiant,
                mot_de_passe=mot_de_passe,
                role=role,
            )
    # Client monte SANS le cycle de vie de l'application : le demarrage lance
    # des traitements de fond qui reecriraient les expositions pendant les
    # autres tests. La base est deja initialisee juste au-dessus.
    yield TestClient(app)

    # L'authentification ne doit pas rester active pour les modules suivants,
    # qui appellent les services metier directement, sans jeton.
    os.environ["RWA_AUTH_ENABLED"] = "0"
    importlib.reload(config_module)
    for nom in ("app.auth.guard", "app.auth.routes", "app.main"):
        importlib.reload(importlib.import_module(nom))


def _depot():
    from app.auth.repository import auth_repository

    return auth_repository


def _jeton(client: TestClient, identifiant: str, mot_de_passe: str) -> str:
    reponse = client.post(
        "/auth/login",
        json={"identifiant": identifiant, "mot_de_passe": mot_de_passe},
    )
    assert reponse.status_code == 200, reponse.text
    return reponse.json()["access_token"]


def _entetes(jeton: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {jeton}"}


def test_un_editeur_ajoute_un_membre(client):
    jeton = _jeton(client, "equipe_editeur", _MDP_EDITION)
    identifiant = "equipe_nouveau_membre"
    if _depot().get_user(identifiant) is not None:
        pytest.skip("Compte deja present dans la base de test.")

    reponse = client.post(
        "/auth/comptes",
        headers=_entetes(jeton),
        json={
            "identifiant": identifiant,
            "mot_de_passe": "MotDePasseNouveauMembre2026",
            "role": "consultation",
            "nom_complet": "Nouveau Membre",
        },
    )

    assert reponse.status_code == 201, reponse.text
    charge = reponse.json()
    assert charge["identifiant"] == identifiant
    assert charge["role"] == "consultation"
    assert charge["actif"] is True
    # Le nouveau membre peut se connecter immediatement.
    assert _jeton(client, identifiant, "MotDePasseNouveauMembre2026")


def test_un_lecteur_ne_peut_pas_lister_l_equipe(client):
    jeton = _jeton(client, "equipe_lecteur", _MDP_CONSULTATION)
    reponse = client.get("/auth/comptes", headers=_entetes(jeton))
    assert reponse.status_code == 403, (
        "La liste des comptes revele les identifiants et les dernieres "
        "connexions : elle ne doit pas etre lisible en consultation."
    )


def test_un_lecteur_ne_peut_pas_ajouter_de_membre(client):
    jeton = _jeton(client, "equipe_lecteur", _MDP_CONSULTATION)
    reponse = client.post(
        "/auth/comptes",
        headers=_entetes(jeton),
        json={
            "identifiant": "compte_interdit",
            "mot_de_passe": "MotDePasseInterdit2026",
            "role": "edition",
        },
    )
    assert reponse.status_code == 403
    assert _depot().get_user("compte_interdit") is None


def test_sans_jeton_la_gestion_est_fermee(client):
    assert client.get("/auth/comptes").status_code == 401
    assert (
        client.post(
            "/auth/comptes",
            json={
                "identifiant": "x",
                "mot_de_passe": "MotDePasseQuelconque2026",
                "role": "edition",
            },
        ).status_code
        == 401
    )


def test_un_mot_de_passe_trop_court_est_refuse(client):
    jeton = _jeton(client, "equipe_editeur", _MDP_EDITION)
    reponse = client.post(
        "/auth/comptes",
        headers=_entetes(jeton),
        json={
            "identifiant": "compte_faible",
            "mot_de_passe": "court",
            "role": "consultation",
        },
    )
    assert reponse.status_code == 422
    assert _depot().get_user("compte_faible") is None


def test_un_identifiant_deja_pris_est_refuse(client):
    jeton = _jeton(client, "equipe_editeur", _MDP_EDITION)
    reponse = client.post(
        "/auth/comptes",
        headers=_entetes(jeton),
        json={
            "identifiant": "equipe_lecteur",
            "mot_de_passe": "MotDePasseQuelconque2026",
            "role": "edition",
        },
    )
    assert reponse.status_code == 400


def test_on_ne_peut_pas_se_desactiver_soi_meme(client):
    """Sinon le dernier editeur se ferme la porte sans moyen de revenir."""

    jeton = _jeton(client, "equipe_editeur", _MDP_EDITION)
    reponse = client.put(
        "/auth/comptes/equipe_editeur/activation",
        headers=_entetes(jeton),
        json={"actif": False},
    )
    assert reponse.status_code == 400
    assert _depot().get_user("equipe_editeur")["actif"] is True
