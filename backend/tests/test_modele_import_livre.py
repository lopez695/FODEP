"""Le modele d'import livre doit offrir tout ce que l'import sait lire.

`build_template_workbook` sert un fichier statique quand il existe, sans le
regenerer depuis la specification. Ce fichier avait derive : 26 des 30 colonnes
optionnelles de « Template donnees » manquaient, dont `Type_autre_actif`. Sans
elle, aucune nature d'autre actif ne pouvait etre declaree : l'EP36, l'EP37 et
le poste IM011 de l'EP3M restaient vides, et la norme RA009 de l'EP01 se
declarait « CONFORME » faute d'assiette. Deux colonnes *requises* manquaient
aussi sur « CRM_non_financee ».

Ces tests portent sur le classeur que l'utilisateur telecharge, pas sur le
generateur : c'est le fichier servi qui decide de ce qu'on peut declarer.
`modeles_import/completer_modele_import.py --verifier` fait le meme controle en
ligne de commande.
"""

from __future__ import annotations

from io import BytesIO
import warnings

from openpyxl import load_workbook
import pytest

from database.services.excel_import_service import (
    EXPECTED_COLUMNS_BY_SHEET,
    EXPECTED_SHEETS,
    OPTIONAL_COLUMNS_BY_SHEET,
    ExcelImportService,
    OTHER_ASSET_TYPE_OPTIONS,
)


@pytest.fixture(scope="module")
def modele_livre():
    service = ExcelImportService.__new__(ExcelImportService)
    with warnings.catch_warnings():
        # openpyxl previent qu'il ne sait pas relire l'extension x14 des
        # validations : sans effet sur les en-tetes et les listes lues ici.
        warnings.simplefilter("ignore")
        contenu = ExcelImportService.build_template_workbook(service)
        return load_workbook(BytesIO(contenu))


def test_le_modele_livre_porte_toutes_les_colonnes_attendues(modele_livre):
    manques: list[str] = []

    for nom_feuille in EXPECTED_SHEETS:
        assert nom_feuille in modele_livre.sheetnames, nom_feuille
        feuille = modele_livre[nom_feuille]
        presentes = {
            feuille.cell(row=1, column=colonne).value
            for colonne in range(1, feuille.max_column + 1)
        }
        requises = list(EXPECTED_COLUMNS_BY_SHEET.get(nom_feuille, ()))
        optionnelles = list(OPTIONAL_COLUMNS_BY_SHEET.get(nom_feuille, ()))
        for colonne in requises + optionnelles:
            if colonne not in presentes:
                marque = "requise" if colonne in requises else "optionnelle"
                manques.append(f"{nom_feuille} : {colonne} ({marque})")

    assert not manques, (
        "Colonnes absentes du modele livre — l'utilisateur ne peut pas les "
        "renseigner :\n" + "\n".join(manques)
    )


def test_la_liste_des_natures_d_autres_actifs_est_complete(modele_livre):
    """La colonne « Type_autre_actif » doit proposer les 13 natures.

    Une nature absente de la liste deroulante est inaccessible a la saisie, et
    Excel refuse la valeur tapee a la main puisque la validation est stricte.
    """

    feuille = modele_livre["Template données"]
    entetes = {
        feuille.cell(row=1, column=colonne).value: colonne
        for colonne in range(1, feuille.max_column + 1)
    }
    assert "Type_autre_actif" in entetes

    # Les options vivent soit dans la formule elle-meme, soit sur la feuille
    # technique qu'elle designe. On ramene les deux cas a un ensemble.
    proposees: set[str] = set()
    for validation in feuille.data_validations.dataValidation:
        formule = str(validation.formula1 or "")
        if "Type_autre_actif" in formule or "$A$3" in formule:
            if formule.startswith('"'):
                proposees.update(
                    valeur.strip() for valeur in formule.strip('"').split(",")
                )
            else:
                nom_feuille, plage = formule.split("!")
                source = modele_livre[nom_feuille.strip("'")]
                for ligne in source[plage.replace("$", "")]:
                    for cellule in ligne:
                        if cellule.value:
                            proposees.add(str(cellule.value).strip())

    absentes = [
        nature for nature in OTHER_ASSET_TYPE_OPTIONS if nature not in proposees
    ]
    assert not absentes, "Natures absentes de la liste deroulante : " + str(absentes)


def test_les_feuilles_de_reference_bceao_sont_conservees(modele_livre):
    """Completer le modele ne doit pas couter ses feuilles explicatives.

    Elles documentent la ponderation de chaque categorie : c'est ce qui rend le
    fichier remplissable sans avoir le dispositif prudentiel sous les yeux.
    """

    for feuille in ("(a) souverains", "(k) autres actifs", "Guide"):
        assert feuille in modele_livre.sheetnames, feuille

    autres_actifs = modele_livre["(k) autres actifs"]
    libelles = [
        str(autres_actifs.cell(row=rang, column=1).value or "")
        for rang in range(1, autres_actifs.max_row + 1)
    ]
    joints = " | ".join(libelles)
    # Les deux natures ajoutees au referentiel doivent y porter leur ponderation.
    assert "Immobilisations hors exploitation" in joints
    assert "Immobilisations incorporelles" in joints
