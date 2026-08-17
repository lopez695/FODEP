"""Fabrique le modèle FODEP vierge livré avec l'application.

Le FODEP est le Formulaire de Déclaration Prudentielle de la BCEAO : un
classeur de 44 feuilles dont la mise en page, les libellés, les codes DISPRU
et les coefficients réglementaires font foi. L'application ne le reconstruit
donc pas — elle part du formulaire officiel et n'écrit que les cellules de
saisie.

Ce script prend un FODEP réel (nécessairement rempli par un établissement) et
en retire toutes les données déclarées, pour ne garder que le formulaire. Le
tri s'appuie sur le verrouillage des cellules posé par la BCEAO : dans le
formulaire, tout ce qui est structurel (libellés, codes DISPRU, coefficients
de pondération, FCEC, référence de l'état source) est verrouillé, et seules
les cellules à renseigner sont déverrouillées. Effacer les cellules
déverrouillées porteuses d'une valeur suffit donc à revenir au formulaire
vierge, sans avoir à énumérer les plages à la main.

Usage :
    python scripts/preparer_modele_fodep.py <FODEP_source.xlsx>
        [--sortie app/rapports/fodep/modele_fodep.xlsx]
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

from openpyxl import load_workbook


# Les huit premières lignes de chaque état portent le titre, l'identifiant de
# l'état et les en-têtes de colonnes. Quelques-unes sont déverrouillées par
# construction (zones de mise en forme) sans être des cellules de saisie :
# on ne descend donc jamais au-dessus de cette limite.
PREMIERE_LIGNE_DE_SAISIE = 8

# EP01 colonne F = « Niveau à respecter » : le seuil réglementaire de chaque
# norme (7,5 %, 8,5 %, 11,5 %, 25 %...). Il est déverrouillé — la BCEAO le
# fait évoluer avec les dispositions transitoires — mais il fait partie du
# formulaire, pas de la déclaration : on le conserve.
CELLULES_CONSERVEES: dict[str, set[str]] = {"EP01": {"F"}}

# La feuille d'attestation ne porte aucun montant déclaré : uniquement
# l'identification de l'établissement et les coordonnées des signataires. Ses
# cases sont déverrouillées jusque dans les intitulés (« Date d'arrêté », les
# lettres AAAA/MM/JJ du gabarit de date), que le nettoyage effacerait à tort.
FEUILLES_NON_NETTOYEES: frozenset[str] = frozenset({"ADPE"})


def vider_donnees_declarees(chemin_source: Path, chemin_sortie: Path) -> dict[str, int]:
    """Écrit en `chemin_sortie` le formulaire privé des données déclarées."""

    classeur = load_workbook(chemin_source)
    effacements: dict[str, int] = {}

    for nom_feuille in classeur.sheetnames:
        if nom_feuille in FEUILLES_NON_NETTOYEES:
            continue
        feuille = classeur[nom_feuille]
        colonnes_conservees = CELLULES_CONSERVEES.get(nom_feuille, set())
        efface = 0
        for ligne in feuille.iter_rows(min_row=PREMIERE_LIGNE_DE_SAISIE):
            for cellule in ligne:
                if cellule.value is None:
                    continue
                if cellule.protection is None or cellule.protection.locked:
                    continue
                if cellule.column_letter in colonnes_conservees:
                    continue
                cellule.value = None
                efface += 1
        if efface:
            effacements[nom_feuille] = efface

    chemin_sortie.parent.mkdir(parents=True, exist_ok=True)
    classeur.save(chemin_sortie)
    classeur.close()
    return effacements


def main(argv: list[str] | None = None) -> int:
    analyseur = argparse.ArgumentParser(description=__doc__)
    analyseur.add_argument("source", type=Path, help="FODEP officiel à nettoyer.")
    analyseur.add_argument(
        "--sortie",
        type=Path,
        default=Path(__file__).resolve().parents[1]
        / "app"
        / "rapports"
        / "fodep"
        / "modele_fodep.xlsx",
        help="Chemin du modèle vierge à produire.",
    )
    arguments = analyseur.parse_args(argv)

    if not arguments.source.exists():
        print(f"Source introuvable : {arguments.source}", file=sys.stderr)
        return 1

    effacements = vider_donnees_declarees(arguments.source, arguments.sortie)
    total = sum(effacements.values())
    print(f"Modèle écrit : {arguments.sortie}")
    print(f"{total} cellules déclarées effacées sur {len(effacements)} feuilles.")
    for nom_feuille, nombre in effacements.items():
        print(f"  {nom_feuille:24s} {nombre:5d}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
