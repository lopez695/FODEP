"""Ce que le declarant saisit se retrouve dans la declaration.

L'attestation ADPE est la seule partie du FODEP que l'application ne calcule
pas : son contenu vient entierement de l'ecran de saisie. Une case perdue en
route ne se verrait qu'a la lecture de la declaration transmise, trop tard.
Ces cas suivent donc chaque champ de bout en bout : ecran, base, classeur.
"""

from __future__ import annotations

from io import BytesIO
import unicodedata

from openpyxl import load_workbook
import pytest

from app.rapports.fodep import construire_fodep
from app.rapports.fodep.saisies import (
    CHAMPS_ADPE,
    CHAMPS_ECLATES,
    PAYS_UEMOA,
    catalogue_adpe,
    enregistrer_saisies,
    lire_saisies,
)
from app.rapports.services import lire_cases_a_saisir


def _valeur_pour(cellule: str, libelle: str, type_champ: str) -> str:
    """Une valeur plausible, propre a la case, pour la reconnaitre a l'arrivee."""

    if type_champ == "pays":
        return "Senegal" if "Senegal" in PAYS_UEMOA else PAYS_UEMOA[6]
    if type_champ == "email":
        return "controle." + cellule.lower() + "@banque.test"
    if type_champ == "telephone":
        return "0022133" + cellule.strip("ABCDEFGHIJKLMNOPQRSTUVWXYZ").zfill(6)
    if type_champ == "date":
        return "2026-03-31"
    if type_champ == "code":
        return "01234" if cellule == "N7" else "K"
    return "Valeur " + cellule


@pytest.fixture
def saisies_restaurees():
    """Rend la table des saisies telle qu'elle etait avant le cas."""

    avant = lire_saisies()
    yield
    apres = lire_saisies()
    enregistrer_saisies(
        [
            {"etat": etat, "cellule": cellule, "valeur": None, "texte": None}
            for (etat, cellule) in apres
        ]
    )
    enregistrer_saisies(
        [
            {
                "etat": etat,
                "cellule": cellule,
                "valeur": saisie.valeur,
                "texte": saisie.texte,
                "commentaire": saisie.commentaire,
            }
            for (etat, cellule), saisie in avant.items()
        ]
    )


def test_chaque_champ_de_l_attestation_survit_a_l_enregistrement(saisies_restaurees):
    attendus = {
        cellule: _valeur_pour(cellule, libelle, type_champ)
        for cellule, libelle, _, type_champ in CHAMPS_ADPE
    }

    touchees = enregistrer_saisies(
        [
            {"etat": "ADPE", "cellule": cellule, "texte": texte}
            for cellule, texte in attendus.items()
        ]
    )
    assert touchees == len(CHAMPS_ADPE)

    # 1. La base rend exactement ce qui lui a ete confie.
    enregistrees = lire_saisies()
    for cellule, texte in attendus.items():
        assert ("ADPE", cellule) in enregistrees, cellule
        assert enregistrees[("ADPE", cellule)].texte == texte, cellule

    # 2. L'ecran les represente : c'est ce que le declarant relit en revenant.
    catalogue = {
        case.cellule: case
        for etat in lire_cases_a_saisir().etats
        for case in etat.cases
        if etat.etat == "ADPE"
    }
    for cellule, texte in attendus.items():
        assert catalogue[cellule].texte == texte, cellule

    # 3. Le classeur transmis les porte, a la cellule que le formulaire prevoit.
    feuille = load_workbook(BytesIO(construire_fodep().contenu))["ADPE"]
    for cellule, texte in attendus.items():
        eclatee = CHAMPS_ECLATES.get(("ADPE", cellule))
        if eclatee:
            ecrit = "".join(str(feuille[case].value or "") for case in eclatee)
        else:
            ecrit = str(feuille[cellule].value or "")
        assert ecrit == texte, cellule


def test_une_case_videe_est_effacee_et_non_conservee(saisies_restaurees):
    enregistrer_saisies([{"etat": "ADPE", "cellule": "T5", "texte": "Banque temoin"}])
    assert lire_saisies()[("ADPE", "T5")].texte == "Banque temoin"

    enregistrer_saisies([{"etat": "ADPE", "cellule": "T5", "texte": "   "}])
    assert ("ADPE", "T5") not in lire_saisies()


def test_l_etat_se_choisit_parmi_les_huit_membres_de_l_union():
    """La case C5 identifie la declaration : elle ne se tape pas.

    Le FODEP est la declaration prudentielle de l'UMOA. Laisser taper le nom
    de l'Etat exposait la case a la faute de frappe et a l'orthographe
    approximative, sur une valeur qui n'a que huit reponses possibles.
    """

    etat = next(case for case in catalogue_adpe() if case.cellule == "C5")

    assert etat.type_saisie == "pays"
    assert tuple(etat.choix) == PAYS_UEMOA
    assert len(PAYS_UEMOA) == 8
    assert "Burkina Faso" in PAYS_UEMOA
    # Ordre alphabetique francais, ou l'accent ne deplace pas la lettre :
    # « Benin » precede « Burkina Faso », ce que le tri par point de code
    # Unicode ferait l'inverse.
    def sans_accent(nom: str) -> str:
        decompose = unicodedata.normalize("NFD", nom)
        return "".join(c for c in decompose if not unicodedata.combining(c)).casefold()

    assert list(PAYS_UEMOA) == sorted(PAYS_UEMOA, key=sans_accent)

    # Les autres cases restent des lignes de saisie libre.
    assert [case.cellule for case in catalogue_adpe() if case.choix] == ["C5"]


def test_la_date_d_arrete_choisie_est_conservee(saisies_restaurees):
    """La date d'arrete se choisit sur l'ecran de saisie : elle s'y enregistre.

    Elle n'etait retenue que le temps de la session. Choisie, puis la page
    rechargee ou l'application rouverte, elle repartait de la date de fin du
    reporting — et l'attestation portait une date que le declarant n'avait pas
    voulue.
    """

    from datetime import date

    from app.rapports.fodep.saisies import lire_date_arrete
    from app.rapports.services import enregistrer_saisies_fodep, lire_cases_a_saisir

    depart = lire_date_arrete()
    try:
        enregistrer_saisies_fodep([], date(2026, 3, 31))
        assert lire_date_arrete() == date(2026, 3, 31)
        assert lire_cases_a_saisir().date_arrete == date(2026, 3, 31)

        # Enregistrer des cases sans toucher a la date ne l'efface pas : sans
        # cela, la premiere saisie suivante la ferait disparaitre.
        enregistrer_saisies_fodep([], None)
        assert lire_date_arrete() == date(2026, 3, 31)

        enregistrer_saisies_fodep([], date(2026, 6, 30))
        assert lire_date_arrete() == date(2026, 6, 30)
    finally:
        if depart is not None:
            enregistrer_saisies_fodep([], depart)
