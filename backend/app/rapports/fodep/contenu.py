"""Contenu du FODEP tel que le classeur le presente.

L'interface sait produire un PDF de la declaration. Ce PDF doit etre le classeur
imprime, pas une mise en page inventee : memes lignes, memes colonnes, memes
fusions, memes intitules en gras. Ce module extrait donc la *forme* autant que
les valeurs — largeurs de colonnes, cellules fusionnees, alignements — pour que
le lecteur retrouve l'etat qu'il connait.

La premiere feuille du classeur est la page de garde de la BCEAO, et elle ne
porte qu'un seul texte : tout le reste y est de la couleur et une image. Elle
oblige donc l'extraction a relever ce qu'un tableau seul n'aurait pas demande —
la teinte des cellules fusionnees verticalement, et les images ancrees.

L'extraction vit cote serveur parce que la bibliotheque Excel du poste de travail
echoue a decoder ce formulaire — « Null check operator used on a null value » des
le decodage — alors qu'openpyxl le relit sans peine, puisqu'il vient de l'ecrire.
Le classeur reste la seule source : le PDF n'est jamais un second calcul.
"""

from __future__ import annotations

from base64 import b64encode
from datetime import date

from pydantic import BaseModel, Field

from app.rapports.fodep.reserves import Reserve
from app.rapports.fodep.service import (
    nom_fichier_fodep,
    renseigner_classeur_fodep,
)

# Garde-fou de largeur, pas une regle de mise en page.
#
# Il valait 14, au temps ou le PDF imprimait tout sur une A4 paysage sans savoir
# se reduire : au-dela, les colonnes devenaient illisibles. Mais cinq etats
# portent du texte plus loin — l'ADPE jusqu'a la colonne 25, l'EP07 jusqu'a la
# 54e — et la declaration imprimee en perdait des colonnes entieres. C'est le
# PDF qui choisit maintenant son format et sa reduction ; ce plafond ne sert
# plus qu'a ne pas suivre un formatage aberrant a l'infini.
COLONNES_MAX = 60

# Largeur de colonne par defaut d'Excel, en caracteres : openpyxl ne renseigne
# `width` que pour les colonnes explicitement dimensionnees.
LARGEUR_PAR_DEFAUT = 8.43

# Separateur de milliers : espace fine insecable, comme le veut la typographie
# francaise et comme l'interface formate ses montants. Insecable pour qu'un
# montant ne se coupe pas en fin de ligne, fine pour ne pas trouer le nombre.
ESPACE_FINE = " "

# Symboles des jeux d'icones, du plus bas au plus haut.
#
# Le formulaire n'en emploie qu'un, « 3Symbols2 » — croix, point d'exclamation,
# coche — sur la feuille qui coche les etats a renseigner. Les caracteres
# retenus sont ceux que la police du PDF sait dessiner : elle porte la coche
# U+2713 mais pas la croix U+2717, remplacee par le signe multiplie.
# Les couleurs sont celles qu'Excel donne a ses icones : sans elles, la feuille
# des etats a renseigner sort en colonnes de coches et de croix noires, ou rien
# ne distingue au premier coup d'oeil ce qui est exige de ce qui ne l'est pas.
# Ce sont les seules couleurs de texte du formulaire — le classeur n'en emploie
# nulle part ailleurs.
VERT = "3FA45B"
AMBRE = "E8A33D"
ROUGE = "C0504D"

SYMBOLES_PAR_JEU: dict[str, tuple[tuple[str, str], ...]] = {
    "3Symbols": (("×", ROUGE), ("!", AMBRE), ("✓", VERT)),
    "3Symbols2": (("×", ROUGE), ("!", AMBRE), ("✓", VERT)),
}


class CelluleFodep(BaseModel):
    """Une cellule du formulaire, avec ce qu'il faut pour la redessiner."""

    texte: str = ""

    #: Le formulaire met ses intitules et ses totaux en gras.
    gras: bool = False

    #: Les montants et les ratios sont alignes a droite dans le classeur.
    droite: bool = False

    #: Texte centre dans sa cellule, comme les en-tetes de colonne.
    centre: bool = False

    #: Couleur du texte en RVB (« 3FA45B »). Absente, le texte est noir. Le
    #: formulaire ne colore aucun texte : la seule couleur vient des icones que
    #: sa mise en forme conditionnelle dessine, vertes ou rouges.
    couleur: str | None = None

    #: Nombre de colonnes couvertes, reprises des fusions du formulaire. Les
    #: titres d'etat et les intitules de section en couvrent plusieurs.
    colonnes: int = 1

    #: Couleur de fond en RVB (« FFF2CC »). Le formulaire teinte les cases a
    #: renseigner et ses en-tetes ; sans elles, le lecteur ne distingue plus ce
    #: que l'etablissement a declare de ce que le formulaire lui demandait. Le
    #: blanc n'est pas transmis : c'est deja la couleur du papier.
    fond: str | None = None

    #: Cotes bordes, parmi « l », « r », « t » et « b ». Le formulaire n'encadre
    #: que ses tableaux : border toutes les cellules donnait une grille uniforme
    #: qui ne ressemblait a aucune page du classeur. C'est aussi ce qui rend les
    #: fusions verticales continues, leur trait ne courant qu'en haut de la
    #: premiere cellule et en bas de la derniere.
    bordures: str = ""

    #: Taille de police du classeur : 10 pour le corps, jusqu'a 20 pour les
    #: titres. C'est elle qui donne au document sa hierarchie.
    taille: float | None = None

    #: Image ancree sur la cellule, encodee en base64. Le formulaire n'en porte
    #: qu'une — le logo de la BCEAO, sur sa page de garde — mais elle fait la
    #: page : sans elle, la declaration imprimee n'est plus reconnaissable comme
    #: le document que l'etablissement transmet.
    image: str | None = None


class LigneFodep(BaseModel):
    cellules: list[CelluleFodep] = Field(default_factory=list)

    #: Hauteur reglee dans le classeur, en points. Le formulaire aere ses
    #: lignes et donne a ses en-tetes deux ou trois fois la hauteur d'une
    #: ligne de donnees ; sans elle, toutes se serrent a la taille de leur
    #: texte et la page perd la forme du formulaire.
    hauteur: float | None = None

    #: Ligne d'en-tete, a reimprimer en haut de chaque page. Le classeur les
    #: designe lui-meme : c'est son reglage d'impression (« lignes a repeter en
    #: haut »). Un etat de cent lignes se lit autrement quand sa deuxieme page
    #: rappelle de quel etat et de quelles colonnes il s'agit.
    entete: bool = False


class EtatFodep(BaseModel):
    """Un etat du formulaire, reduit a ses lignes porteuses."""

    nom: str

    #: Largeurs des colonnes, dans l'unite d'Excel. Les conserver evite un PDF
    #: aux colonnes egales, ou l'intitule d'un poste serait aussi etroit que la
    #: colonne d'un code.
    largeurs: list[float] = Field(default_factory=list)

    #: Orientation reglee dans le classeur. Dix-neuf etats du FODEP sont en
    #: portrait : les imprimer tous en paysage etirait leurs colonnes sur une
    #: page trois fois trop large pour eux.
    paysage: bool = True

    lignes: list[LigneFodep] = Field(default_factory=list)


class ContenuFodep(BaseModel):
    """Le classeur rendu imprimable, avec ce qui doit voyager avec lui."""

    nom_fichier: str
    date_arrete: date

    #: Reserves de lecture de l'export, chacune avec sa nature. Elles ne
    #: figurent pas dans le classeur : l'interface les affiche, le PDF n'a pas
    #: a les inventer.
    anomalies: list[Reserve]

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
    """Derniere colonne portant une valeur, un trait ou une couleur.

    Le trait compte autant que le texte : la derniere colonne d'un tableau peut
    n'etre qu'une case a renseigner, vide et bordee. S'arreter au dernier texte
    lui retirait son bord droit.

    La couleur compte aussi, et c'est toute la page de garde : elle ne porte
    qu'un seul texte, en troisieme colonne, et douze colonnes de bandeaux. S'y
    arreter reduisait la couverture de la BCEAO a un rectangle bleu de deux
    colonnes, sans ses bandes de couleur ni son cartouche.
    """

    derniere = 0
    for ligne in feuille.iter_rows(max_col=COLONNES_MAX):
        for cellule in ligne:
            if _texte(cellule.value) or _bordures(cellule) or _fond(cellule):
                derniere = max(derniere, cellule.column)
    return derniere


def _fusions(
    feuille, derniere: int
) -> tuple[
    dict[tuple[int, int], int],
    set[tuple[int, int]],
    dict[tuple[int, int], tuple[int, int]],
]:
    """Portees des fusions, cellules qu'elles recouvrent, et leur ancre.

    Le formulaire fusionne ses titres d'etat et ses intitules de section sur
    toute la largeur. Sans cette information, un titre de cent trente caracteres
    se retrouve comprime dans la colonne des codes DISPRU — et une colonne plus
    etroite qu'un seul de ses mots ne peut pas se mettre en page.

    L'ancre est la cellule de tete de la fusion, celle ou Excel range la valeur
    *et la couleur* du bloc entier : les rangs suivants sont vides dans le
    fichier. Les bandes verticales de la page de garde, fusionnees sur
    vingt-deux lignes, ne se coloraient donc que sur leur premiere ligne.
    """

    portees: dict[tuple[int, int], int] = {}
    recouvertes: set[tuple[int, int]] = set()
    ancres: dict[tuple[int, int], tuple[int, int]] = {}
    for plage in feuille.merged_cells.ranges:
        if plage.min_col > derniere:
            continue
        largeur = min(plage.max_col, derniere) - plage.min_col + 1
        for rang in range(plage.min_row, plage.max_row + 1):
            portees[(rang, plage.min_col)] = largeur
            if rang != plage.min_row:
                ancres[(rang, plage.min_col)] = (plage.min_row, plage.min_col)
            for colonne in range(plage.min_col + 1, plage.max_col + 1):
                recouvertes.add((rang, colonne))
    return portees, recouvertes, ancres


def _fond(cellule) -> str | None:
    """Couleur de remplissage, en RVB, ou rien si la cellule n'en porte pas."""

    remplissage = cellule.fill
    if remplissage is None or not remplissage.patternType:
        return None
    rvb = getattr(remplissage.fgColor, "rgb", None)
    if not isinstance(rvb, str) or len(rvb) not in (6, 8):
        return None
    couleur = rvb[-6:].upper()
    return None if couleur == "FFFFFF" else couleur


def _bordures(cellule) -> str:
    """Cotes bordes de la cellule, dans l'ordre gauche, droite, haut, bas."""

    bordure = cellule.border
    if bordure is None:
        return ""
    return "".join(
        cote[0]
        for cote in ("left", "right", "top", "bottom")
        if getattr(bordure, cote).style
    )


def _porte_quelque_chose(cellule: CelluleFodep) -> bool:
    """La cellule a-t-elle de quoi etre dessinee ?

    Une cellule sans texte compte quand meme si elle est bordee ou teintee :
    c'est une case a renseigner restee vide, et le tableau qui la contient
    perdrait sa forme si on la retirait.
    """

    return bool(
        cellule.texte or cellule.bordures or cellule.fond or cellule.image
    )


def _est_a_droite(cellule, symbole: str | None = None) -> bool:
    if cellule.alignment and cellule.alignment.horizontal == "right":
        return True
    # Une icone n'est plus un nombre : elle suit l'alignement declare, et le
    # formulaire centre ses coches dans leur colonne.
    if symbole is not None:
        return False
    # Un nombre sans alignement declare est cadre a droite par Excel.
    return isinstance(cellule.value, (int, float)) and not isinstance(
        cellule.value, bool
    )


def _lignes_de_titre(feuille) -> set[int]:
    """Lignes que le classeur reimprime en haut de chaque page.

    Le reglage est celui du formulaire lui-meme (« $1:$15 » pour l'EP30) : il
    dit ou finit l'en-tete et ou commence le tableau.
    """

    reglage = feuille.print_title_rows
    if not reglage:
        return set()
    try:
        debut, fin = reglage.replace("$", "").split(":")
        return set(range(int(debut), int(fin) + 1))
    except (ValueError, AttributeError):
        return set()


def _icones(feuille) -> dict[tuple[int, int], tuple[str, str]]:
    """Cellules dont le classeur remplace la valeur par une icone.

    La feuille « Liste des etats prudentiels a renseigner » coche chaque etat
    pour les trois bases de declaration. Elle ne porte pourtant aucune coche :
    elle porte 68 et 32, que le classeur *n'affiche pas* — une mise en forme
    conditionnelle « jeu d'icones » y substitue un symbole et masque le nombre.
    Le PDF montrait donc une colonne de 68 et de 32 la ou le declarant lit des
    croix et des coches.

    Le seuil de chaque icone est lu dans la regle, pas devine : les bornes sont
    exprimees en pourcentage de l'ecart entre la plus petite et la plus grande
    valeur de la plage. Un jeu d'icones que ce module ne sait pas dessiner
    laisse le nombre en place — mieux vaut une valeur brute qu'un symbole
    invente.
    """

    icones: dict[tuple[int, int], tuple[str, str]] = {}
    for mise_en_forme in feuille.conditional_formatting:
        for regle in mise_en_forme.rules:
            jeu = regle.iconSet
            if regle.type != "iconSet" or jeu is None or jeu.showValue:
                continue
            symboles = SYMBOLES_PAR_JEU.get(jeu.iconSet)
            if symboles is None or len(symboles) != len(jeu.cfvo):
                continue

            positions = [
                (rang, colonne)
                for plage in mise_en_forme.sqref.ranges
                for rang in range(plage.min_row, plage.max_row + 1)
                for colonne in range(plage.min_col, plage.max_col + 1)
            ]
            valeurs = {
                position: feuille.cell(row=position[0], column=position[1]).value
                for position in positions
            }
            nombres = [
                valeur
                for valeur in valeurs.values()
                if isinstance(valeur, (int, float))
                and not isinstance(valeur, bool)
            ]
            if not nombres:
                continue

            seuils = _seuils(jeu.cfvo, min(nombres), max(nombres))
            if seuils is None:
                continue
            if jeu.reverse:
                symboles = tuple(reversed(symboles))

            for position, valeur in valeurs.items():
                if valeur in (None, "") or not isinstance(valeur, (int, float)):
                    continue
                rang = max(
                    (index for index, seuil in enumerate(seuils) if valeur >= seuil),
                    default=0,
                )
                icones[position] = symboles[rang]
    return icones


def _seuils(bornes, plancher: float, plafond: float) -> list[float] | None:
    """Valeur a partir de laquelle chaque icone s'applique.

    Les bornes d'un jeu d'icones s'expriment en pourcentage de l'ecart, en
    valeur absolue, ou par une formule. Les deux premieres se calculent ici ;
    une formule demanderait d'evaluer le classeur, ce que ce module ne fait
    jamais — la regle est alors abandonnee et le nombre reste affiche.
    """

    parts = {"min": 0.0, "max": 1.0}
    seuils: list[float] = []
    for borne in bornes:
        if borne.type == "num":
            seuils.append(float(borne.val))
            continue
        part = (
            float(borne.val or 0) / 100
            if borne.type == "percent"
            else parts.get(borne.type)
        )
        if part is None:
            return None
        seuils.append(plancher + part * (plafond - plancher))
    return seuils


def _hauteur_de_ligne(feuille, rang: int) -> float:
    dimension = feuille.row_dimensions.get(rang)
    if dimension is not None and dimension.height:
        return float(dimension.height)
    return float(feuille.sheet_format.defaultRowHeight or 15)


def _images_ancrees(feuille, derniere: int) -> dict[int, LigneFodep]:
    """Images du classeur, rendues comme des lignes a part.

    Le formulaire n'en porte qu'une, le logo de la BCEAO sur sa page de garde,
    et elle n'est pas un ornement : c'est a elle qu'on reconnait la couverture
    de la declaration. Elle est ancree sur une plage de cellules ; on lui rend
    une ligne de la hauteur des rangs qu'elle couvre et de la largeur des
    colonnes qu'elle traverse, inseree la ou elle commence.

    Les rangs qu'une image recouvre sont vides dans ce formulaire, et
    l'extraction les ecarte : la ligne d'image ne chevauche rien. Elle
    s'ajouterait a une ligne de texte, plutot que de la recouvrir, si une
    version ulterieure du formulaire posait une image par-dessus un tableau.
    """

    lignes: dict[int, LigneFodep] = {}
    for image in getattr(feuille, "_images", []):
        ancre = getattr(image, "anchor", None)
        depart = getattr(ancre, "_from", None)
        arrivee = getattr(ancre, "to", None)
        if depart is None or arrivee is None:
            continue

        premiere = depart.row + 1
        colonne = depart.col + 1
        if colonne > derniere:
            continue
        portee = min(arrivee.col + 1, derniere) - colonne + 1
        dernier_rang = max(arrivee.row + 1, premiere)

        cellules = [CelluleFodep() for _ in range(1, colonne)]
        cellules.append(
            CelluleFodep(
                colonnes=max(portee, 1),
                centre=True,
                image=b64encode(image._data()).decode("ascii"),
            )
        )
        lignes[premiere] = LigneFodep(
            cellules=cellules,
            hauteur=sum(
                _hauteur_de_ligne(feuille, rang)
                for rang in range(premiere, dernier_rang + 1)
            ),
        )
    return lignes


def _lignes_du_formulaire(feuille, derniere: int) -> list[LigneFodep]:
    portees, recouvertes, ancres = _fusions(feuille, derniere)
    titres = _lignes_de_titre(feuille)
    images = _images_ancrees(feuille, derniere)
    icones = _icones(feuille)
    lignes: list[LigneFodep] = []

    for ligne in feuille.iter_rows(max_col=derniere):
        rang = ligne[0].row
        if rang in images:
            lignes.append(images[rang])

        cellules: list[CelluleFodep] = []
        for cellule in ligne:
            position = (cellule.row, cellule.column)
            if position in recouvertes:
                continue
            # Sous la tete d'une fusion, la cellule est vide dans le fichier :
            # sa couleur est restee sur l'ancre. Le trait, lui, s'y trouve bien
            # — c'est ce qui ferme le bas d'un bloc fusionne.
            tete = ancres.get(position)
            fond = _fond(cellule) or (
                _fond(feuille.cell(row=tete[0], column=tete[1])) if tete else None
            )
            icone = icones.get(position)
            symbole = icone[0] if icone else None
            cellules.append(
                CelluleFodep(
                    texte=symbole if symbole is not None else _texte(cellule.value),
                    couleur=icone[1] if icone else None,
                    # Excel trace ses icones pleines ; un caractere de texte a
                    # la meme place doit peser autant, sinon la coche parait
                    # effacee a cote de celle du classeur.
                    gras=bool(icone) or bool(cellule.font and cellule.font.bold),
                    droite=_est_a_droite(cellule, symbole),
                    centre=bool(
                        cellule.alignment
                        and cellule.alignment.horizontal == "center"
                    ),
                    colonnes=portees.get(position, 1),
                    fond=fond,
                    bordures=_bordures(cellule),
                    taille=float(cellule.font.sz)
                    if cellule.font and cellule.font.sz
                    else None,
                )
            )

        # Le formulaire compte beaucoup de lignes vides, reservees a la mise en
        # page : les reporter donnerait un PDF de blancs. Une ligne sans texte
        # mais bordee, elle, appartient a un tableau et se garde.
        if not any(_porte_quelque_chose(cellule) for cellule in cellules):
            continue
        # Les colonnes de queue qui ne portent rien du tout n'elargissent le
        # tableau pour rien.
        while cellules and not _porte_quelque_chose(cellules[-1]):
            cellules.pop()
        dimension = feuille.row_dimensions.get(rang)
        lignes.append(
            LigneFodep(
                cellules=cellules,
                hauteur=float(dimension.height)
                if dimension is not None and dimension.height
                else None,
                entete=rang in titres,
            )
        )

    return lignes


def _largeurs(feuille, derniere: int) -> list[float]:
    """Largeur de chaque colonne, dans l'unite d'Excel.

    Le classeur regle ses largeurs par PLAGES : une seule entree « C:E » vaut
    pour les trois colonnes. Les lire par lettre ne servait donc que la
    premiere de chaque plage -- les suivantes retombaient sur la largeur par
    defaut. Sur la liste des etats a renseigner, « Individuelle » gardait ses
    22 unites tandis que « Sous-consolidee » et « Consolidee » tombaient a 10,
    trop etroites pour leur propre intitule, coupe en plein mot. Le classeur
    compte cent soixante-dix plages de ce genre.

    La largeur par defaut est celle que la feuille declare, et non une
    constante : une feuille qui la regle a 10 n'a pas les memes colonnes
    qu'une feuille qui la laisse a 8,43.
    """

    par_colonne: dict[int, float] = {}
    for dimension in feuille.column_dimensions.values():
        if not dimension.width:
            continue
        debut = dimension.min or 1
        fin = min(dimension.max or debut, derniere)
        for colonne in range(debut, fin + 1):
            par_colonne[colonne] = float(dimension.width)

    defaut = float(feuille.sheet_format.defaultColWidth or LARGEUR_PAR_DEFAUT)
    return [
        par_colonne.get(colonne, defaut) for colonne in range(1, derniere + 1)
    ]


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
                        paysage=feuille.page_setup.orientation != "portrait",
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
