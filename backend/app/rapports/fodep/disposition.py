"""Lecture de la disposition des états prudentiels du FODEP.

Les états du FODEP ne sont pas décrits ici par des numéros de ligne codés en
dur : ils sont relus dans le formulaire officiel au moment de l'export. Une
mise à jour du formulaire par la BCEAO (une pondération ajoutée, un bloc
décalé de deux lignes) est ainsi absorbée en remplaçant le seul fichier
`modele_fodep.xlsx`, sans retoucher le code de remplissage.

Deux repères suffisent à reconstruire la structure :

* la colonne A porte le « code DISPRU », clé unique de chaque poste ;
* sur les états de risque de crédit EP12 à EP19, la colonne B porte soit un
  coefficient de pondération, soit le mot « Total » qui ferme un bloc.
"""

from __future__ import annotations

from dataclasses import dataclass
import re

from openpyxl.cell.cell import MergedCell

from app.core.runtime_paths import resource_path

# Le formulaire officiel, vierge. Il vit ici parce que ce module est celui qui
# relit la disposition des états : le service de remplissage et le catalogue des
# saisies manuelles s'y réfèrent tous les deux, et un chemin recopié dans deux
# fichiers finit par diverger.
CHEMIN_MODELE = resource_path("app", "rapports", "fodep", "modele_fodep.xlsx")


# Les quatre blocs des états EP12 à EP19, dans leur ordre d'apparition. Tous
# les états n'en comportent pas quatre : EP17, EP18 et EP19 s'arrêtent aux
# engagements hors bilan, faute d'expositions au risque de contrepartie.
BLOC_BILAN = "bilan"
BLOC_ENGAGEMENT_FINANCEMENT = "engagement_financement"
BLOC_AUTRES_HORS_BILAN = "autres_hors_bilan"
BLOC_CONTREPARTIE = "contrepartie"

ORDRE_DES_BLOCS: tuple[str, ...] = (
    BLOC_BILAN,
    BLOC_ENGAGEMENT_FINANCEMENT,
    BLOC_AUTRES_HORS_BILAN,
    BLOC_CONTREPARTIE,
)

PREMIERE_LIGNE_UTILE = 9

MOTIF_CODE_DISPRU = re.compile(
    r"[A-Z]{2,4}\d{2,3}(?:\s*/\s*[A-Z]{2,4}\d{2,3})?"
)


@dataclass(frozen=True)
class BlocPonderations:
    """Un bloc d'un état de risque de crédit : ses pondérations et son total."""

    nom: str
    lignes_par_ponderation: dict[float, int]
    ligne_total: int

    @property
    def ponderations(self) -> tuple[float, ...]:
        return tuple(sorted(self.lignes_par_ponderation))

    def ligne_pour(self, ponderation: float) -> int | None:
        """Ligne exacte d'une pondération, ou None si le bloc ne l'offre pas."""

        for poids, ligne in self.lignes_par_ponderation.items():
            if abs(poids - ponderation) < 1e-9:
                return ligne
        return None


@dataclass(frozen=True)
class DispositionCategorie:
    """Disposition complète d'un état EP12 à EP19."""

    blocs: dict[str, BlocPonderations]
    ligne_total_general: int

    def bloc(self, nom: str) -> BlocPonderations | None:
        return self.blocs.get(nom)


def _nombre_ou_none(valeur: object) -> float | None:
    """Convertit une cellule en coefficient, ou None si ce n'en est pas un.

    Les coefficients du formulaire sont stockés en texte (« 0,2 » saisi dans
    une cellule au format texte) : une conversion directe par `float` est donc
    indispensable, et l'échec normal.
    """

    if valeur is None:
        return None
    if isinstance(valeur, (int, float)):
        return float(valeur)
    texte = str(valeur).strip().replace(",", ".")
    if not texte:
        return None
    try:
        return float(texte)
    except ValueError:
        return None


def lire_disposition_categorie(feuille) -> DispositionCategorie:
    """Reconstruit la disposition d'un état de risque de crédit EP12 à EP19."""

    blocs: dict[str, BlocPonderations] = {}
    ligne_total_general = 0
    ponderations_en_cours: dict[float, int] = {}
    index_bloc = 0

    for ligne in range(PREMIERE_LIGNE_UTILE, feuille.max_row + 1):
        libelle = feuille.cell(row=ligne, column=2).value
        if libelle is None:
            continue
        texte = str(libelle).strip()

        if texte.upper().startswith("TOTAL EXPOSITIONS"):
            ligne_total_general = ligne
            continue

        if texte.casefold() == "total":
            if ponderations_en_cours and index_bloc < len(ORDRE_DES_BLOCS):
                nom = ORDRE_DES_BLOCS[index_bloc]
                blocs[nom] = BlocPonderations(
                    nom=nom,
                    lignes_par_ponderation=dict(ponderations_en_cours),
                    ligne_total=ligne,
                )
                index_bloc += 1
            ponderations_en_cours = {}
            continue

        coefficient = _nombre_ou_none(texte)
        if coefficient is not None:
            ponderations_en_cours[coefficient] = ligne

    if not blocs or not ligne_total_general:
        raise ValueError(
            f"Disposition illisible sur la feuille « {feuille.title} » : "
            "le modèle FODEP embarqué ne correspond pas au format attendu."
        )
    return DispositionCategorie(blocs=blocs, ligne_total_general=ligne_total_general)


FEUILLE_LISTE_DES_ETATS = "Liste_EP_à_renseigner"

# La feuille « Liste des états prudentiels à renseigner » coche chaque état
# pour les trois bases de déclaration. La coche est portée par une valeur
# numérique qu'une police symbole transforme en ✔ ou en ✘ à l'écran.
MARQUEUR_ETAT_REQUIS = 68
COLONNE_PAR_BASE: dict[str, int] = {
    "individuelle": 3,
    "sous_consolidee": 4,
    "consolidee": 5,
}

# Les feuilles « poste pour mémoire » ne figurent pas dans la liste : elles
# prolongent l'état auquel elles se rattachent et en suivent le sort.
ETATS_MEMOIRE: dict[str, str] = {"EP3M": "EP03", "EP5M": "EP05"}


def lire_etats_requis(classeur, *, base: str = "individuelle") -> set[str]:
    """Retourne les états que le formulaire exige pour une base de déclaration.

    Le périmètre n'est pas décidé par le code : il est lu dans le formulaire
    lui-même. Une banque déclarant sur base individuelle n'a pas à renseigner
    le calcul des fonds propres consolidés, et la BCEAO peut faire évoluer ce
    découpage sans que l'export ait à être retouché.
    """

    try:
        colonne = COLONNE_PAR_BASE[base]
    except KeyError as exc:
        raise ValueError(
            f"Base de déclaration inconnue : {base!r}. "
            f"Attendu : {', '.join(COLONNE_PAR_BASE)}."
        ) from exc

    feuille = classeur[FEUILLE_LISTE_DES_ETATS]
    requis: set[str] = set()
    for ligne in range(PREMIERE_LIGNE_UTILE, feuille.max_row + 1):
        etat = feuille.cell(row=ligne, column=1).value
        if etat is None or not str(etat).strip().upper().startswith("EP"):
            continue
        if feuille.cell(row=ligne, column=colonne).value == MARQUEUR_ETAT_REQUIS:
            requis.add(str(etat).strip())

    for memoire, parent in ETATS_MEMOIRE.items():
        if parent in requis:
            requis.add(memoire)
    return requis


def indexer_codes_dispru(feuille, *, colonne: int = 1) -> dict[str, int]:
    """Associe chaque code DISPRU d'un état à son numéro de ligne.

    La colonne des codes porte aussi des intitulés (« Code DISPRU » en tête de
    tableau, titres de postes mémoire) : seule la forme d'un code est retenue,
    deux à quatre lettres suivies de deux ou trois chiffres. L'EP02, qui
    renvoie à la fois à la base individuelle et à la base consolidée, porte
    deux codes séparés par une barre oblique : cette forme est admise telle
    quelle, puisque c'est ainsi que la feuille la présente.
    """

    index: dict[str, int] = {}
    for ligne in range(PREMIERE_LIGNE_UTILE, feuille.max_row + 1):
        valeur = feuille.cell(row=ligne, column=colonne).value
        if valeur is None:
            continue
        code = str(valeur).strip()
        if MOTIF_CODE_DISPRU.fullmatch(code):
            index.setdefault(code, ligne)
    return index


def styles_ouverts(classeur) -> frozenset[int] | None:
    """Index des styles que la BCEAO a laissés ouverts à la saisie.

    Un classeur ne porte qu'une poignée de styles de protection — quatre pour
    le FODEP — et chaque cellule s'y réfère par un numéro. Les relever une
    fois permet ensuite de reconnaître une case ouverte sur ce seul numéro.

    L'intérêt n'est pas cosmétique. Lire `cellule.protection` construit deux
    objets par cellule, et le balayage en visite deux millions et demi : c'est
    la moitié du temps de production du formulaire. Comparer un entier ne coûte
    rien.

    Retourne `None` si openpyxl ne présente pas cette table — la lecture
    repasse alors par le chemin ordinaire, plus lent mais toujours juste.
    """

    try:
        return frozenset(
            index
            for index, protection in enumerate(classeur._protections)
            if not protection.locked
        )
    except AttributeError:
        return None


def _est_a_completer(cellule, styles_de_saisie: frozenset[int] | None = None) -> bool:
    """Indique si une cellule est une case de saisie encore vide.

    Le verrouillage posé par la BCEAO sert de garde-fou : seules les cellules
    qu'elle a ouvertes à la saisie sont concernées, jamais un libellé, un code
    DISPRU ni un coefficient de pondération. Les cellules fusionnées sont
    écartées : seule la première du groupe porte une valeur.
    """

    if isinstance(cellule, MergedCell) or cellule.value is not None:
        return False
    if styles_de_saisie is None:
        return cellule.protection is not None and not cellule.protection.locked
    # Une cellule que le fichier ne style pas explicitement porte le style par
    # defaut, qui est verrouille : elle n'est pas une case a renseigner.
    style = cellule._style
    return style is not None and style.protectionId in styles_de_saisie


def _ligne_entamee(feuille, ligne: int, premiere_colonne: int = 2) -> bool:
    """La ligne porte-t-elle déjà une déclaration ?

    Sert aux états qui déclarent une liste — grands risques, clients des
    groupes liés, cinquante plus gros engagements. Leur grille compte une
    centaine de lignes pour le nombre d'entrées que l'établissement a
    réellement ; le balayage à zéro les remplissait toutes, et le formulaire
    partait avec des dizaines de contreparties sans nom déclarant zéro. Une
    ligne à laquelle rien n'a été écrit n'est pas une contrepartie qui ne doit
    rien : c'est une ligne dont l'établissement n'a pas l'usage.

    Un zéro écrit par le remplissage compte comme une déclaration : c'est une
    valeur, pas une case oubliée.

    Le verdict se prend à partir de la colonne B, et non de la première colonne
    à compléter : sur plusieurs de ces états — participations, parties liées —
    c'est là que le nom est porté, et une ligne nommée dont aucune case n'est
    encore cochée reste une ligne à compléter. La colonne A est écartée, son
    code DISPRU étant imprimé sur toutes les lignes, servantes ou non.
    """

    for cellule in feuille[ligne]:
        if cellule.column >= premiere_colonne and cellule.value not in (None, ""):
            return True
    return False


def porte_une_valeur_saisie(feuille) -> bool:
    """L'état a-t-il reçu un montant non nul dans une case de saisie ?

    Seules les cases que la BCEAO a ouvertes comptent : le gabarit porte aussi
    des coefficients réglementaires — pondérations, facteurs de conversion —
    qui sont des nombres non nuls sans être des déclarations.

    Sert à distinguer, avant le balayage à zéro, l'état qu'aucune donnée n'a
    touché de celui qu'un module a renseigné. Après le balayage, tout est à
    zéro et les deux se ressemblent.
    """

    styles_de_saisie = styles_ouverts(feuille.parent)
    for cellule in tuple(feuille._cells.values()):
        if cellule.row < PREMIERE_LIGNE_UTILE or isinstance(cellule, MergedCell):
            continue
        valeur = cellule.value
        if not isinstance(valeur, (int, float)) or isinstance(valeur, bool) or not valeur:
            continue
        if styles_de_saisie is None:
            ouverte = cellule.protection is not None and not cellule.protection.locked
        else:
            style = cellule._style
            ouverte = style is not None and style.protectionId in styles_de_saisie
        if ouverte:
            return True
    return False


def completer_a_zero(
    feuille,
    lignes: dict[str, int],
    colonnes: range,
    *,
    seulement_lignes_entamees: bool = False,
) -> None:
    """Met à zéro les cases de saisie encore vides des lignes indiquées.

    Le FODEP n'admet pas de case à renseigner laissée vide : « toutes les
    cellules non verrouillées doivent être renseignées » (notice, § 3.3).

    `seulement_lignes_entamees` réserve ce complément aux lignes qui portent
    déjà quelque chose — voir `_ligne_entamee`.
    """

    styles_de_saisie = styles_ouverts(feuille.parent)
    for ligne in lignes.values():
        if seulement_lignes_entamees and not _ligne_entamee(feuille, ligne):
            continue
        for colonne in colonnes:
            cellule = feuille.cell(row=ligne, column=colonne)
            if _est_a_completer(cellule, styles_de_saisie):
                cellule.value = 0


def completer_etat_a_zero(
    feuille,
    *,
    premiere_colonne: int = 3,
    seulement_lignes_entamees: bool = False,
) -> None:
    """Met à zéro toutes les cases de saisie d'un état non alimenté.

    Les états que l'application ne sait pas encore renseigner — risque de
    contrepartie, approche standard du risque opérationnel, détail du risque
    de marché — doivent tout de même être déclarés à zéro plutôt que rendus
    vides. Les deux premières colonnes, qui portent les codes DISPRU et les
    intitulés, ne sont jamais touchées.

    `seulement_lignes_entamees` épargne les lignes vierges des états qui
    déclarent une liste — voir `_ligne_entamee`.
    """

    styles_de_saisie = styles_ouverts(feuille.parent)
    lignes_entamees: dict[int, bool] = {}

    # Ne pas passer par ``iter_rows`` sans borne haute : le modèle BCEAO porte
    # parfois une mise en forme résiduelle jusqu'à la colonne 1025. Openpyxl
    # matérialiserait alors chaque coordonnée de ce rectangle, soit plusieurs
    # millions de cellules vides pour l'ensemble du classeur. Une coordonnée
    # absente de ``_cells`` ne peut pas être une case de saisie explicitement
    # ouverte par le modèle ; seules les cellules déjà présentes sont utiles.
    # La copie protège aussi l'itération si openpyxl ajuste son index pendant
    # l'affectation des zéros.
    cellules = tuple(feuille._cells.values())
    for cellule in cellules:
        if not (
            cellule.row >= PREMIERE_LIGNE_UTILE
            and cellule.column >= premiere_colonne
            and _est_a_completer(cellule, styles_de_saisie)
        ):
            continue
        if seulement_lignes_entamees:
            # Un état porte jusqu'à une centaine de lignes : le verdict est
            # retenu une fois par ligne plutôt que recalculé à chaque case.
            entamee = lignes_entamees.get(cellule.row)
            if entamee is None:
                entamee = _ligne_entamee(feuille, cellule.row, premiere_colonne)
                lignes_entamees[cellule.row] = entamee
            if not entamee:
                continue
        cellule.value = 0
