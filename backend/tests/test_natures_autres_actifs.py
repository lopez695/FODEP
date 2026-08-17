"""Les natures d'autres actifs doivent etre coherentes de bout en bout.

Trois listes decrivent la meme colonne « Type_autre_actif » :

  - OTHER_ASSET_TYPE_OPTIONS, qui valide l'import Excel ;
  - otherAssetTypeOptions cote Flutter, qui alimente la liste deroulante ;
  - TYPES_AUTRES_ACTIFS, qui remplit les fichiers de demonstration.

Une nature absente de l'une d'elles se paie : absente de la liste d'import, elle
fait rejeter le fichier ; absente de la liste Flutter, elle est silencieusement
reclassee en « Autres elements d'actifs non definis » des qu'on modifie la
ligne. Dans les deux cas, l'etat du FODEP qu'elle seule alimente sort vide sans
que rien ne le signale — c'est arrive a l'EP36 et au poste IM011 de l'EP3M.
"""

from __future__ import annotations

from pathlib import Path
import re

from openpyxl import load_workbook

from app.core.natures_immobilisations import (
    NATURE_IMMO_EXPLOITATION,
    NATURE_IMMO_HORS_EXPLOITATION,
    NATURE_IMMO_INCORPORELLE,
)
from app.rapports.fodep.agregation import (
    LIGNE_EP20_PAR_DEFAUT,
    LIGNES_EP20_PAR_NATURE,
    NATURES_DEDUITES_DES_FONDS_PROPRES,
)
from database.services.rwa_calculation_service import (
    OTHER_ASSET_TYPE_OPTIONS,
    lookup_other_asset_risk_weight,
)

RACINE = Path(__file__).resolve().parents[2]
MODELE_FODEP = RACINE / "backend" / "app" / "rapports" / "fodep" / "modele_fodep.xlsx"


def _natures_du_frontend() -> list[str]:
    """Libelles de otherAssetTypeOptions, resolus depuis les constantes Dart."""

    source = (
        RACINE
        / "frontend"
        / "lib"
        / "modules"
        / "expositions"
        / "models"
        / "exposition_models.dart"
    ).read_text(encoding="utf-8")

    constantes = dict(
        re.findall(
            r"const String (otherAsset\w+)\s*=\s*\n?\s*'([^']+)'",
            source,
        )
    )
    bloc = re.search(
        r"const List<String> otherAssetTypeOptions = \[(.*?)\];",
        source,
        re.DOTALL,
    )
    assert bloc is not None, "otherAssetTypeOptions introuvable."

    return [
        constantes[nom]
        for nom in (ligne.strip().rstrip(",") for ligne in bloc.group(1).splitlines())
        if nom in constantes
    ]


def test_les_natures_sont_les_memes_a_l_import_et_a_la_saisie():
    frontend = _natures_du_frontend()
    # Garde-fou : une extraction muette rendrait la comparaison vide, donc vraie.
    assert len(frontend) >= 13
    assert set(frontend) == set(OTHER_ASSET_TYPE_OPTIONS)


def test_les_natures_que_l_export_lit_sont_importables():
    """Ces trois natures alimentent l'EP20, l'EP36, l'EP37 et l'EP3M.

    L'export les lit dans `exposition_autre_actif.type_actif`. Si l'import les
    refuse, ces etats ne peuvent pas etre renseignes du tout.
    """

    for nature in (
        NATURE_IMMO_EXPLOITATION,
        NATURE_IMMO_HORS_EXPLOITATION,
        NATURE_IMMO_INCORPORELLE,
    ):
        assert nature in OTHER_ASSET_TYPE_OPTIONS, nature


def _ponderations_de_l_ep20() -> dict[str, float]:
    """Coefficient de ponderation de chaque ligne de l'EP20, colonne (b).

    Lu dans le modele FODEP, pas recopie : c'est le formulaire transmis a la
    BCEAO qui fixe ces coefficients, et le calcul interne doit s'y conformer.
    """

    feuille = load_workbook(MODELE_FODEP)["EP20"]
    ponderations: dict[str, float] = {}
    for rang in range(1, feuille.max_row + 1):
        code = feuille.cell(row=rang, column=1).value
        poids = feuille.cell(row=rang, column=4).value
        if code and isinstance(poids, (int, float)):
            ponderations[str(code).strip()] = float(poids)
    return ponderations


def test_les_ponderations_internes_suivent_celles_du_fodep():
    """Le ratio affiche par l'outil doit etre celui que le FODEP declare.

    Chaque nature d'autre actif tombe sur une ligne de l'EP20, qui porte sa
    ponderation reglementaire. Une nature ponderee autrement en interne donne un
    APR — donc un ratio de solvabilite — different de l'etat transmis.
    """

    ponderations = _ponderations_de_l_ep20()
    ecarts: list[str] = []

    for nature in OTHER_ASSET_TYPE_OPTIONS:
        if nature in NATURES_DEDUITES_DES_FONDS_PROPRES:
            # Retranchee des fonds propres, donc absente des actifs ponderes :
            # l'EP20 ne lui donne pas de ligne, l'interne doit lire zero.
            attendue = 0.0
        else:
            ligne = LIGNES_EP20_PAR_NATURE.get(nature, LIGNE_EP20_PAR_DEFAUT)
            assert ligne in ponderations, f"{ligne} absente de l'EP20."
            attendue = ponderations[ligne]

        obtenue = lookup_other_asset_risk_weight(nature)
        if obtenue != attendue:
            ecarts.append(f"{nature} : FODEP {attendue}, interne {obtenue}")

    assert not ecarts, "Ponderations divergentes :\n" + "\n".join(ecarts)


def test_les_fichiers_de_demonstration_couvrent_ces_natures():
    """Sans elles dans le referentiel de demonstration, l'EP36 et l'EP3M
    sortaient vides des jeux d'essai, ce qui masquait les deux anomalies."""

    referentiels = (RACINE / "modeles_import" / "_referentiels.py").read_text(
        encoding="utf-8"
    )
    # La parenthese fermante est cherchee en debut de ligne : les commentaires
    # du bloc en contiennent, une recherche non gourmande s'arreterait dessus.
    bloc = re.search(r"TYPES_AUTRES_ACTIFS = \((.*?)\n\)", referentiels, re.DOTALL)
    assert bloc is not None
    natures = re.findall(r'"([^"]+)"', bloc.group(1))

    assert NATURE_IMMO_HORS_EXPLOITATION in natures
    assert NATURE_IMMO_INCORPORELLE in natures
    # Un poids par nature, sinon random.choices leve une ValueError.
    generateur = (RACINE / "modeles_import" / "gen_credit.py").read_text(
        encoding="utf-8"
    )
    poids = re.search(r"_POIDS_AUTRES_ACTIFS = \(([^)]*)\)", generateur)
    assert poids is not None
    assert len([p for p in poids.group(1).split(",") if p.strip()]) == len(natures)
