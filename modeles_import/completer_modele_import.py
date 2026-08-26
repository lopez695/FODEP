"""Complete le modele d'import livre avec les colonnes que l'import attend.

`build_template_workbook` sert un fichier statique, `backend/data/
modele_import_rwa.xlsx`, sans jamais le regenerer depuis la specification. Il
avait donc derive : 26 des 30 colonnes optionnelles de « Template donnees »
manquaient — dont `Type_autre_actif`, sans laquelle aucune nature d'autre actif
ne peut etre declaree, ce qui laissait l'EP36, l'EP37 et le poste IM011 de
l'EP3M vides et la norme RA009 non mesuree. Deux colonnes *requises* manquaient
aussi sur « CRM_non_financee ».

Ce script comble l'ecart sans toucher aux feuilles de reference de la BCEAO —
`(a)` a `(l)`, « Mapping des ponderations », « Guide » —, que le generateur de
secours du service ne reproduit pas.

Il est idempotent : relance apres relance, il n'ajoute que ce qui manque. Une
copie de sauvegarde est deposee au premier passage.

Listes deroulantes : simples, pas en cascade. Le generateur de secours propose
des listes dependantes de la categorie via INDIRECT ; les reproduire ici
demanderait de reecrire ses plages nommees dans un classeur qui a ses propres
conventions. L'import valide de toute facon chaque valeur contre la meme liste,
categorie ou pas.

Usage :
    python modeles_import/completer_modele_import.py [--verifier]

`--verifier` n'ecrit rien et sort en erreur si le modele est incomplet : de quoi
le brancher sur un controle avant livraison.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import sys

RACINE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RACINE / "backend"))

from openpyxl import load_workbook  # noqa: E402
from openpyxl.styles import Alignment, Font, PatternFill  # noqa: E402
from openpyxl.utils import get_column_letter, quote_sheetname  # noqa: E402
from openpyxl.worksheet.datavalidation import DataValidation  # noqa: E402

from database.services.excel_import_service import (  # noqa: E402
    EXPECTED_COLUMNS_BY_SHEET,
    EXPECTED_SHEETS,
    FIXED_OPTIONS_BY_COLUMN,
    IMPORT_SHEET_SPECS,
    OPTIONAL_COLUMNS_BY_SHEET,
)

MODELE = RACINE / "backend" / "data" / "modele_import_rwa.xlsx"
SAUVEGARDE = MODELE.with_suffix(".xlsx.avant_completion")

# Feuille technique portant les listes trop longues pour tenir dans une formule
# de validation (Excel plafonne `formula1` a 255 caracteres).
FEUILLE_LISTES = "Listes (completees)"
LIMITE_FORMULE = 240

# Lignes de saisie couvertes par les listes deroulantes.
DERNIERE_LIGNE = 2001

OUI_NON = ("Oui", "Non")

# La feuille « (k) autres actifs » documente la ponderation de chaque nature.
# Les deux naturees ajoutees au referentiel n'y figuraient pas. Les coefficients
# sont ceux de la colonne (b) de l'EP20 du FODEP ; les incorporelles n'y ont pas
# de ligne puisqu'elles se retranchent des fonds propres.
NATURES_A_DOCUMENTER: tuple[tuple[str, str], ...] = (
    ("Immobilisations hors exploitation", "1"),
    (
        "Immobilisations incorporelles "
        "(deduites des fonds propres de base, poste IM011 de l'EP3M)",
        "0",
    ),
)


def _colonnes_oui_non() -> set[str]:
    """Colonnes booleennes, d'apres la specification des feuilles."""

    booleennes: set[str] = set()
    for spec in IMPORT_SHEET_SPECS:
        for colonne in spec.required_columns + spec.optional_columns:
            if str(getattr(colonne, "value_type", "")).lower() in {"bool", "boolean", "oui/non"}:
                booleennes.add(colonne.name)
    return booleennes


def _entetes(feuille) -> dict[str, int]:
    return {
        feuille.cell(row=1, column=c).value: c
        for c in range(1, feuille.max_column + 1)
        if feuille.cell(row=1, column=c).value
    }


def _feuille_des_listes(classeur):
    if FEUILLE_LISTES in classeur.sheetnames:
        return classeur[FEUILLE_LISTES]
    feuille = classeur.create_sheet(FEUILLE_LISTES)
    feuille.sheet_state = "hidden"
    feuille.cell(row=1, column=1, value="Sources des listes deroulantes ajoutees")
    feuille.cell(row=1, column=1).font = Font(bold=True, size=9)
    return feuille


def _plage_pour(classeur, colonne: str, options: tuple) -> str:
    """Ecrit les options sur la feuille technique et renvoie la plage absolue."""

    feuille = _feuille_des_listes(classeur)
    entetes = {
        feuille.cell(row=2, column=c).value: c
        for c in range(1, feuille.max_column + 1)
        if feuille.cell(row=2, column=c).value
    }
    if colonne in entetes:
        index = entetes[colonne]
    else:
        index = max(entetes.values(), default=0) + 1
        feuille.cell(row=2, column=index, value=colonne).font = Font(bold=True, size=9)
        for rang, option in enumerate(options, start=3):
            feuille.cell(row=rang, column=index, value=option)

    lettre = get_column_letter(index)
    return (
        f"{quote_sheetname(FEUILLE_LISTES)}!${lettre}$3"
        f":${lettre}${2 + len(options)}"
    )


def _validation(classeur, colonne: str, options: tuple) -> DataValidation | None:
    if not options:
        return None
    inline = ",".join(str(option) for option in options)
    formule = (
        f'"{inline}"' if len(inline) <= LIMITE_FORMULE
        else _plage_pour(classeur, colonne, options)
    )
    return DataValidation(
        type="list",
        formula1=formule,
        allow_blank=True,
        showDropDown=False,
        showErrorMessage=True,
        errorTitle="Valeur non reconnue",
        error=(
            "Choisissez une valeur dans la liste deroulante pour que le calcul "
            "prudentiel s'applique a cette ligne."
        ),
    )


def _completer_les_natures(classeur) -> list[str]:
    """Ajoute a « (k) autres actifs » les natures qui y manquaient."""

    ajouts: list[str] = []
    nom = next((n for n in classeur.sheetnames if n.startswith("(k)")), None)
    if nom is None:
        return ajouts

    feuille = classeur[nom]
    presentes = {
        str(feuille.cell(row=r, column=1).value or "").strip()
        for r in range(1, feuille.max_row + 1)
    }
    for libelle, ponderation in NATURES_A_DOCUMENTER:
        racine = libelle.split(" (")[0]
        if any(racine == valeur or racine in valeur for valeur in presentes):
            continue
        rang = feuille.max_row + 1
        feuille.cell(row=rang, column=1, value=libelle).alignment = Alignment(
            wrap_text=True, vertical="center"
        )
        feuille.cell(row=rang, column=2, value=ponderation)
        ajouts.append(f"{nom} : + {racine}")
    return ajouts


def completer(*, ecrire: bool) -> list[str]:
    """Renvoie la liste des manques. Les comble si `ecrire`."""

    classeur = load_workbook(MODELE)
    booleennes = _colonnes_oui_non()
    manques: list[str] = []

    for nom_feuille in EXPECTED_SHEETS:
        if nom_feuille not in classeur.sheetnames:
            manques.append(f"{nom_feuille} : feuille absente")
            continue

        feuille = classeur[nom_feuille]
        attendues = list(EXPECTED_COLUMNS_BY_SHEET.get(nom_feuille, ())) + list(
            OPTIONAL_COLUMNS_BY_SHEET.get(nom_feuille, ())
        )
        presentes = _entetes(feuille)
        requises = set(EXPECTED_COLUMNS_BY_SHEET.get(nom_feuille, ()))

        for colonne in attendues:
            if colonne in presentes:
                continue
            marque = "requise" if colonne in requises else "optionnelle"
            manques.append(f"{nom_feuille} : + {colonne} ({marque})")
            if not ecrire:
                continue

            index = feuille.max_column + 1
            cellule = feuille.cell(row=1, column=index, value=colonne)
            is_oui_non = colonne in booleennes
            if colonne in requises:
                font_color = "1D4ED8"
                fill_color = "DBEAFE"
            elif is_oui_non:
                font_color = "065F46"
                fill_color = "D1FAE5"
            else:
                font_color = "475569"
                fill_color = "F1F5F9"

            cellule.font = Font(bold=True, size=10, color=font_color)
            cellule.fill = PatternFill("solid", fgColor=fill_color)
            cellule.alignment = Alignment(
                horizontal="center", vertical="center", wrap_text=True
            )
            feuille.column_dimensions[get_column_letter(index)].width = max(
                16, min(38, len(colonne) + 4)
            )

            options = (
                OUI_NON if is_oui_non
                else FIXED_OPTIONS_BY_COLUMN.get(colonne, ())
            )
            validation = _validation(classeur, colonne, options)
            if validation is not None:
                feuille.add_data_validation(validation)
                lettre = get_column_letter(index)
                validation.add(f"{lettre}2:{lettre}{DERNIERE_LIGNE}")

    manques.extend(_completer_les_natures(classeur) if ecrire else [])

    if ecrire and manques:
        if not SAUVEGARDE.exists():
            shutil.copy2(MODELE, SAUVEGARDE)
        classeur.save(MODELE)
    return manques


def main() -> int:
    analyseur = argparse.ArgumentParser(description=__doc__)
    analyseur.add_argument(
        "--verifier",
        action="store_true",
        help="n'ecrit rien ; sort en erreur si le modele est incomplet",
    )
    arguments = analyseur.parse_args()

    manques = completer(ecrire=not arguments.verifier)
    if not manques:
        print("Modele d'import complet : rien a ajouter.")
        return 0

    verbe = "Manquant" if arguments.verifier else "Ajoute"
    print(f"{verbe} ({len(manques)}) :")
    for manque in manques:
        print("  -", manque)
    if arguments.verifier:
        return 1
    print(f"\nSauvegarde : {SAUVEGARDE.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
