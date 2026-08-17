"""L'identification des contreparties se reprend du classeur d'import.

Le FODEP exige, pour ses états EP30, EP38 et EP39, des données qui décrivent
la contrepartie et non l'exposition. Sur un portefeuille de plusieurs
centaines de lignes, les saisir une à une dans l'interface n'est pas tenable :
elles doivent voyager avec le classeur.
"""

from __future__ import annotations

import sqlite3

import pytest

from app.groupes_clients.identification_import import (
    appliquer_identifications,
    collecter_identifications,
)


@pytest.fixture
def base():
    """Base minimale portant les seules tables que la passe touche."""

    connexion = sqlite3.connect(":memory:")
    connexion.row_factory = sqlite3.Row
    connexion.executescript(
        """
        CREATE TABLE groupes_clients(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nom TEXT UNIQUE,
            numero_centrale_risques TEXT,
            cree_le TEXT,
            modifie_le TEXT
        );
        CREATE TABLE contreparties(
            id TEXT, nom TEXT, groupe_id INTEGER, categorie_lien TEXT,
            numero_centrale_risques TEXT, secteur_activite TEXT,
            categorie_partie_liee TEXT, modifie_le TEXT
        );
        INSERT INTO contreparties(id, nom) VALUES
            ('1', 'SOCIETE ALPHA'), ('2', 'M. DIALLO'), ('3', 'SOCIETE BETA');
        """
    )
    return connexion


def _contrepartie(base, nom: str) -> dict:
    ligne = base.execute("SELECT * FROM contreparties WHERE nom = ?", (nom,)).fetchone()
    return dict(ligne)


def test_les_lignes_d_une_meme_contrepartie_se_completent():
    """Renseigner une seule ligne d'une contrepartie doit suffire.

    Une contrepartie porte souvent des dizaines d'expositions : exiger la même
    valeur sur chacune serait une invitation à la faute de frappe.
    """

    identifications = collecter_identifications(
        [
            {"Contrepartie": "SOCIETE ALPHA", "N_Centrale_risques": "CR-100"},
            {"Contrepartie": "SOCIETE ALPHA", "Secteur_activite": "Agro-industrie"},
            {"Contrepartie": "SOCIETE ALPHA"},
        ]
    )

    assert identifications["SOCIETE ALPHA"] == {
        "N_Centrale_risques": "CR-100",
        "Secteur_activite": "Agro-industrie",
    }


def test_une_ligne_sans_contrepartie_est_ignoree():
    assert collecter_identifications([{"N_Centrale_risques": "CR-999"}]) == {}


def test_le_groupe_cite_est_cree_avec_son_numero(base):
    """Nommer un groupe dans le classeur doit suffire à le constituer."""

    stats = appliquer_identifications(
        base,
        collecter_identifications(
            [
                {
                    "Contrepartie": "SOCIETE ALPHA",
                    "Groupe_clients_lies": "Groupe Alpha",
                    "N_Centrale_risques_groupe": "GR-01",
                    "Categorie_lien": "Controle de droit",
                }
            ]
        ),
    )

    assert stats["groupes_crees"] == 1
    groupe = base.execute("SELECT * FROM groupes_clients").fetchone()
    assert groupe["nom"] == "Groupe Alpha"
    assert groupe["numero_centrale_risques"] == "GR-01"
    assert _contrepartie(base, "SOCIETE ALPHA")["groupe_id"] == groupe["id"]


def test_les_libelles_du_classeur_deviennent_des_identifiants(base):
    """Le classeur propose des libellés lisibles, la base stocke des codes."""

    appliquer_identifications(
        base,
        collecter_identifications(
            [
                {
                    "Contrepartie": "M. DIALLO",
                    "Partie_liee": "Membre de l'organe executif",
                    "Categorie_lien": "Dependance economique",
                }
            ]
        ),
    )

    diallo = _contrepartie(base, "M. DIALLO")
    assert diallo["categorie_partie_liee"] == "organe_executif"
    assert diallo["categorie_lien"] == "dependance_economique"


def test_une_categorie_inventee_est_ignoree_et_comptee(base):
    """Écrire une valeur non reconnue ferait rejeter l'EP30.

    Mieux vaut laisser la colonne vide — l'export signale déjà les
    identifications incomplètes — que d'inscrire une qualification que le
    formulaire n'admet pas.
    """

    stats = appliquer_identifications(
        base,
        collecter_identifications(
            [{"Contrepartie": "SOCIETE BETA", "Categorie_lien": "Amitié de longue date"}]
        ),
    )

    assert stats["valeurs_ignorees"] == 1
    assert _contrepartie(base, "SOCIETE BETA")["categorie_lien"] is None


def test_un_second_import_n_efface_pas_ce_qu_il_ne_renseigne_pas(base):
    """Un classeur qui ne parle que du secteur ne doit rien perdre d'autre."""

    appliquer_identifications(
        base,
        collecter_identifications(
            [{"Contrepartie": "SOCIETE ALPHA", "N_Centrale_risques": "CR-100"}]
        ),
    )
    appliquer_identifications(
        base,
        collecter_identifications(
            [{"Contrepartie": "SOCIETE ALPHA", "Secteur_activite": "Agro-industrie"}]
        ),
    )

    alpha = _contrepartie(base, "SOCIETE ALPHA")
    assert alpha["numero_centrale_risques"] == "CR-100"
    assert alpha["secteur_activite"] == "Agro-industrie"
