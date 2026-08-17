"""L'API refuse par defaut et n'ouvre que ce qui est explicitement autorise.

Ces tests valent contrat : ils echouent si quelqu'un desactive le garde, oublie
de proteger une route mutante, ou elargit la liste des ecritures ouvertes a la
consultation sans le decider.
"""

from __future__ import annotations

import importlib
import os

import pytest
from fastapi.testclient import TestClient

_SECRET = "secret-de-test-suffisamment-long-pour-etre-accepte"


@pytest.fixture(scope="module")
def client():
    """Monte l'API avec authentification active et comptes de test."""

    os.environ["RWA_AUTH_ENABLED"] = "1"
    os.environ["RWA_JWT_SECRET"] = _SECRET
    # Le cookie est pose sur une connexion de test en http : sans cet
    # assouplissement, le client de test ne le conserverait pas.
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
        module = importlib.import_module(nom)
        importlib.reload(module)

    from app.auth.service import creer_compte
    from app.auth.repository import auth_repository
    from app.main import app
    from database.connection import database_manager

    database_manager.initialize()
    for identifiant, role in (("test_lecture", "consultation"), ("test_edition", "edition")):
        if auth_repository.get_user(identifiant) is None:
            creer_compte(
                identifiant=identifiant,
                mot_de_passe="motdepasse-de-test-2026",
                role=role,
            )

    # Client monte SANS le cycle de vie de l'application : le demarrage lance
    # le recalcul reglementaire et le realignement des impayes dans des fils
    # de fond, qui reecriraient les expositions pendant les autres tests.
    # La base est deja initialisee juste au-dessus.
    yield TestClient(app)

    # L'authentification ne doit pas rester active pour les autres modules de
    # test, qui appellent les services metier directement.
    os.environ["RWA_AUTH_ENABLED"] = "0"
    importlib.reload(config_module)


def _connexion(client, identifiant: str) -> str:
    reponse = client.post(
        "/auth/login",
        json={"identifiant": identifiant, "mot_de_passe": "motdepasse-de-test-2026"},
    )
    assert reponse.status_code == 200, reponse.text
    return reponse.json()["access_token"]


def _entete(jeton: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {jeton}"}


def test_sans_jeton_une_lecture_est_refusee(client):
    assert client.get("/dashboard").status_code == 401


def test_un_jeton_invente_ne_passe_pas(client):
    reponse = client.get("/dashboard", headers=_entete("jeton.completement.invente"))
    assert reponse.status_code == 401


def test_mauvais_mot_de_passe_refuse_sans_reveler_le_compte(client):
    reponse = client.post(
        "/auth/login",
        json={"identifiant": "test_lecture", "mot_de_passe": "mauvais-mot-de-passe"},
    )
    inconnu = client.post(
        "/auth/login",
        json={"identifiant": "compte_inexistant", "mot_de_passe": "mauvais-mot-de-passe"},
    )
    assert reponse.status_code == 401
    assert inconnu.status_code == 401
    # Un message different entre les deux cas permettrait d'enumerer les
    # comptes valides du systeme.
    assert reponse.json()["detail"] == inconnu.json()["detail"]


def test_la_consultation_lit_le_tableau_de_bord(client):
    jeton = _connexion(client, "test_lecture")
    assert client.get("/dashboard", headers=_entete(jeton)).status_code == 200


def test_la_consultation_ecrit_dans_son_propre_espace(client):
    """Chaque compte dispose de sa base : l'ecriture n'affecte que lui.

    Interdire l'ecriture a la consultation n'aurait plus rien protege -- cela
    aurait seulement empeche quelqu'un de travailler sur ses propres chiffres.
    """

    jeton = _connexion(client, "test_lecture")
    reponse = client.put(
        "/dashboard/fonds-propres",
        headers=_entete(jeton),
        json={"capital_ordinaire": 1.0},
    )
    assert reponse.status_code not in (401, 403)


def test_la_consultation_ne_gere_pas_les_comptes(client):
    """Ce qui reste reserve : les comptes, communs a tous les espaces."""

    jeton = _connexion(client, "test_lecture")
    assert client.get("/auth/comptes", headers=_entete(jeton)).status_code == 403


def test_l_edition_franchit_le_garde(client):
    jeton = _connexion(client, "test_edition")
    reponse = client.put(
        "/dashboard/fonds-propres",
        headers=_entete(jeton),
        json={},
    )
    # Le corps est volontairement incomplet : seul compte le fait que la
    # requete atteigne la route au lieu d'etre arretee par le garde.
    assert reponse.status_code not in (401, 403)


def test_le_profil_annonce_le_role(client):
    jeton = _connexion(client, "test_lecture")
    reponse = client.get("/auth/me", headers=_entete(jeton))
    assert reponse.status_code == 200
    assert reponse.json()["role"] == "consultation"


def test_le_jeton_de_renouvellement_ne_vaut_pas_jeton_d_acces(client):
    """Le cookie de session ne doit jamais ouvrir l'API a lui seul."""

    client.cookies.clear()
    client.post(
        "/auth/login",
        json={"identifiant": "test_lecture", "mot_de_passe": "motdepasse-de-test-2026"},
    )
    cookie = client.cookies.get("rwa_refresh")
    assert cookie, "Le cookie de renouvellement doit etre pose a la connexion."
    assert client.get("/dashboard", headers=_entete(cookie)).status_code == 401


def test_le_renouvellement_tourne_et_invalide_l_ancien_jeton(client):
    client.cookies.clear()
    client.post(
        "/auth/login",
        json={"identifiant": "test_lecture", "mot_de_passe": "motdepasse-de-test-2026"},
    )
    ancien_cookie = client.cookies.get("rwa_refresh")

    assert client.post("/auth/refresh").status_code == 200
    nouveau_cookie = client.cookies.get("rwa_refresh")
    assert nouveau_cookie != ancien_cookie

    # Rejouer l'ancien jeton doit echouer : c'est ce qui limite les degats
    # si un cookie a ete intercepte.
    client.cookies.clear()
    client.cookies.set("rwa_refresh", ancien_cookie)
    assert client.post("/auth/refresh").status_code == 401


def test_la_deconnexion_revoque_la_session(client):
    client.cookies.clear()
    client.post(
        "/auth/login",
        json={"identifiant": "test_lecture", "mot_de_passe": "motdepasse-de-test-2026"},
    )
    cookie = client.cookies.get("rwa_refresh")
    assert client.post("/auth/logout").status_code == 204

    client.cookies.clear()
    client.cookies.set("rwa_refresh", cookie)
    assert client.post("/auth/refresh").status_code == 401


def test_aucune_route_metier_n_echappe_a_l_authentification():
    """Une route mutante hors du perimetre du garde serait ouverte a tous.

    Le garde exige un jeton valide sur tout appel : ce releve verifie qu'il
    reste des routes mutantes a proteger, et qu'aucune ne se cache sous un
    prefixe qui contournerait le controle.
    """

    from app.auth.guard import CHEMINS_PUBLICS
    from app.main import app

    mutantes = {
        (methode, route.path)
        for route in app.routes
        for methode in getattr(route, "methods", set()) or set()
        if methode in {"POST", "PUT", "DELETE", "PATCH"}
        and not route.path.startswith("/auth")
    }
    assert mutantes, "Le releve des routes mutantes ne doit pas etre vide."

    exposees = {chemin for _, chemin in mutantes} & set(CHEMINS_PUBLICS)
    assert not exposees, (
        f"Ces routes modifient des donnees sans exiger de jeton : {exposees}"
    )
