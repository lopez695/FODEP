"""Contenu du FODEP tel que le classeur le presente.

L'interface sait produire un PDF de la declaration. Ce PDF doit etre le classeur
imprime, pas une mise en page inventee : memes lignes, memes colonnes, memes
fusions, memes intitules en gras. Ce module extrait donc la *forme* autant que
les valeurs — largeurs de colonnes, cellules fusionnees, alignements — pour que
le lecteur retrouve l'etat qu'il connait.

L'extraction vit cote serveur parce que la bibliotheque Excel du poste de travail
echoue a decoder ce formulaire — « Null check operator used on a null value » des
le decodage — alors qu'openpyxl le relit sans peine, puisqu'il vient de l'ecrire.
Le classeur reste la seule source : le PDF n'est jamais un second calcul.
"""

from __future__ import annotations

from datetime import date

from openpyxl.utils import get_column_letter
from pydantic import BaseModel, Field

from app.rapports.fodep.service import (
    nom_fichier_fodep,
    renseigner_classeur_fodep,
)

# Largeur retenue par etat. Les etats du FODEP n'en portent pas davantage, et
# au-dela les colonnes deviennent illisibles sur une page A4 paysage.
COLONNES_MAX = 14

# Largeur de colonne par defaut d'Excel, en caracteres : openpyxl ne renseigne
# `width` que pour les colonnes explicitement dimensionnees.
LARGEUR_PAR_DEFAUT = 8.43

# Separateur de milliers : espace fine insecable, comme le veut la typographie
# francaise et comme l'interface formate ses montants. Insecable pour qu'un
# montant ne se coupe pas en fin de ligne, fine pour ne pas trouer le nombre.
ESPACE_FINE = " "


class CelluleFodep(BaseModel):
    """Une cellule du formulaire, avec ce qu'il faut pour la redessiner."""

    texte: str = ""

    #: Le formulaire met ses intitules et ses totaux en gras.
    gras: bool = False

    #: Les montants et les ratios sont alignes a droite dans le classeur.
    droite: bool = False

    #: Nombre de colonnes couvertes, reprises des fusions du formulaire. Les
    #: titres d'etat et les intitules de section en couvrent plusieurs.
    colonnes: int = 1


class LigneFodep(BaseModel):
    cellules: list[CelluleFodep] = Field(default_factory=list)


class EtatFodep(BaseModel):
    """Un etat du formulaire, reduit a ses lignes porteuses."""

    nom: str

    #: Largeurs des colonnes, dans l'unite d'Excel. Les conserver evite un PDF
    #: aux colonnes egales, ou l'intitule d'un poste serait aussi etroit que la
    #: colonne d'un code.
    largeurs: list[float] = Field(default_factory=list)

    lignes: list[LigneFodep] = Field(default_factory=list)


class ContenuFodep(BaseModel):
    """Le classeur rendu imprimable, avec ce qui doit voyager avec lui."""

    nom_fichier: str
    date_arrete: date

    #: Reserves de lecture de l'export. Elles ne figurent pas dans le classeur :
    #: l'interface les affiche, le PDF n'a pas a les inventer.
    anomalies: list[str]

    etats: list[EtatFodep]


def _texte(valeur) -> str:
    """Cellule rendue lisible, ou vide quand elle n'a rien a dire."""

    if valeur is None:
        return ""
    if isinstance(valeur, bool):
        return "OUI" if valeur else "NON"
    if isinstance(valeur, str):
        texte = valeur.strip()
        # Une formule n'a pas de valeur hors d'Excel : le classeur est ecrit
        # sans etre evalue. Afficher « =SI(...) » ferait passer une mecanique
        # pour un resultat ; la case reste vide, comme dans le classeur non
        # encore ouvert.
        return "" if texte.startswith("=") else texte
    if isinstance(valeur, date):
        return valeur.strftime("%d/%m/%Y")
    if isinstance(valeur, float):
        if valeur == int(valeur):
            return f"{int(valeur):,}".replace(",", ESPACE_FINE)
        return f"{valeur:.4f}".replace(".", ",")
    if isinstance(valeur, int):
        return f"{valeur:,}".replace(",", ESPACE_FINE)
    return str(valeur).strip()


def _derniere_colonne(feuille) -> int:
    """Derniere colonne portant une valeur, plafonnee a COLONNES_MAX."""

    derniere = 0
    for ligne in feuille.iter_rows(max_col=COLONNES_MAX):
        for cellule in ligne:
            if _texte(cellule.value):
                derniere = max(derniere, cellule.column)
    return derniere


def _fusions(
    feuille, derniere: int
) -> tuple[dict[tuple[int, int], int], set[tuple[int, int]]]:
    """Portees des fusions, et cellules qu'elles recouvrent.

    Le formulaire fusionne ses titres d'etat et ses intitules de section sur
    toute la largeur. Sans cette information, un titre de cent trente caracteres
    se retrouve comprime dans la colonne des codes DISPRU — et une colonne plus
    etroite qu'un seul de ses mots ne peut pas se mettre en page.
    """

    portees: dict[tuple[int, int], int] = {}
    recouvertes: set[tuple[int, int]] = set()
    for plage in feuille.merged_cells.ranges:
        if plage.min_col > derniere:
            continue
        largeur = min(plage.max_col, derniere) - plage.min_col + 1
        for rang in range(plage.min_row, plage.max_row + 1):
            portees[(rang, plage.min_col)] = largeur
            for colonne in range(plage.min_col + 1, plage.max_col + 1):
                recouvertes.add((rang, colonne))
    return portees, recouvertes


def _est_a_droite(cellule) -> bool:
    if cellule.alignment and cellule.alignment.horizontal == "right":
        return True
    # Un nombre sans alignement declare est cadre a droite par Excel.
    return isinstance(cellule.value, (int, float)) and not isinstance(
        cellule.value, bool
    )


def _lignes_du_formulaire(feuille, derniere: int) -> list[LigneFodep]:
    portees, recouvertes = _fusions(feuille, derniere)
    lignes: list[LigneFodep] = []

    for ligne in feuille.iter_rows(max_col=derniere):
        cellules: list[CelluleFodep] = []
        for cellule in ligne:
            position = (cellule.row, cellule.column)
            if position in recouvertes:
                continue
            cellules.append(
                CelluleFodep(
                    texte=_texte(cellule.value),
                    gras=bool(cellule.font and cellule.font.bold),
                    droite=_est_a_droite(cellule),
                    colonnes=portees.get(position, 1),
                )
            )

        # Le formulaire compte beaucoup de lignes vides, reservees a la mise en
        # page : les reporter donnerait un PDF de blancs.
        if not any(cellule.texte for cellule in cellules):
            continue
        # Les colonnes vides de queue n'elargissent le tableau pour rien.
        while cellules and not cellules[-1].texte:
            cellules.pop()
        lignes.append(LigneFodep(cellules=cellules))

    return lignes


def _largeurs(feuille, derniere: int) -> list[float]:
    largeurs: list[float] = []
    for colonne in range(1, derniere + 1):
        dimension = feuille.column_dimensions.get(get_column_letter(colonne))
        largeur = dimension.width if dimension and dimension.width else None
        largeurs.append(float(largeur or LARGEUR_PAR_DEFAUT))
    return largeurs


def contenu_fodep(date_arrete: date | None = None) -> ContenuFodep:
    """Renseigne le FODEP puis en extrait le contenu, etat par etat.

    Le classeur est lu la ou il est produit, en memoire. L'ecrire dans un
    tampon pour le relire aussitot coutait huit secondes par apercu et ne
    rendait rien de plus : le classeur enregistre est le meme que celui qu'on
    tenait deja.
    """

    produit = renseigner_classeur_fodep(date_arrete)
    try:
        classeur = produit.classeur
        etats: list[EtatFodep] = []
        for nom in classeur.sheetnames:
            feuille = classeur[nom]
            derniere = _derniere_colonne(feuille)
            if derniere == 0:
                continue
            lignes = _lignes_du_formulaire(feuille, derniere)
            if lignes:
                etats.append(
                    EtatFodep(
                        nom=nom,
                        largeurs=_largeurs(feuille, derniere),
                        lignes=lignes,
                    )
                )

        return ContenuFodep(
            nom_fichier=nom_fichier_fodep(produit.date_arrete),
            date_arrete=produit.date_arrete,
            anomalies=list(produit.anomalies),
            etats=etats,
        )
    finally:
        produit.classeur.close()
