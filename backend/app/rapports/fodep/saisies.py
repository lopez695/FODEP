"""Saisies manuelles des cellules du FODEP que l'application ne calcule pas.

Le formulaire porte des cases dont l'application n'a pas la source. Les etats
prudentiels concernes sont declares a zero, ce que la notice admet d'une
activite inexistante.

Reste l'attestation, que rien ne pourra jamais deduire : l'identite de
l'etablissement, ses deux responsables, ses signataires. Ce module en tient le
catalogue, conserve ce que le declarant y porte, et l'ecrit dans le classeur
avant le balayage final. L'ordre compte : une case saisie n'est jamais
recouverte par un zero automatique, `completer_etat_a_zero` ne touchant que
les cases restees vides.

Trois etats prudentiels s'y ajoutent : l'EP04, l'EP11 et l'EP28. Ils ne sont pas
la par oubli de cablage — l'application n'a aucune source pour eux, et n'en aura
pas tant qu'elle ne suivra ni derives, ni produits de base, ni instruments de
fonds propres en retrait progressif. Ils partaient donc a zero, et le formulaire
affirmait en silence que l'etablissement n'en detenait aucun.

Les autres etats non alimentes n'y figurent pas, et c'est delibere : leur source
existe ailleurs dans l'outil — coefficients beta, produit brut par ligne de
metier, incidents de pertes — et ils demandent d'etre cables, pas saisis. Un
ecran de saisie n'a pas a redemander ce que la base contient deja.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timezone
from functools import lru_cache
import re

from openpyxl import load_workbook
from openpyxl.cell.cell import MergedCell

from app.rapports.fodep.disposition import (
    CHEMIN_MODELE,
    MOTIF_CODE_DISPRU,
    PREMIERE_LIGNE_UTILE,
    styles_ouverts,
)
from database.connection import database_manager


@dataclass
class CaseASaisir:
    """Une case du formulaire que le declarant doit renseigner lui-meme."""

    etat: str
    cellule: str
    ligne: int
    code: str
    libelle: str
    colonne: str
    type_saisie: str = "nombre"
    # Valeurs proposees quand la case se choisit au lieu de se taper.
    choix: tuple[str, ...] = ()
    valeur: float | None = None
    texte: str | None = None
    commentaire: str | None = None


# ─── Attestation ADPE ────────────────────────────────────────────────────────

# L'attestation n'est pas une grille : toutes ses cellules sont deverrouillees
# parce que c'est une lettre posee sur un quadrillage. La regle generique des
# cases ouvertes y designerait des centaines de cellules sans objet. Ses champs
# sont donc releves un par un, chacun en face de son libelle.
#
# Aucun de ces champs ne vient de l'outil : ce sont l'identite de
# l'etablissement et celle des personnes qui engagent leur signature. Seule la
# date d'arrete est deja portee par l'export, dans le gabarit AAAA/MM/JJ.
#
# Le quatrieme terme dit ce que la case attend, et l'ecran s'y conforme. Il se
# lit dans le libelle du formulaire, nulle part ailleurs : une case intitulee
# « Établissement » attend un nom, pas un montant, et une case intitulee
# « Téléphone » n'accepte pas les memes caracteres qu'une adresse
# electronique. Aucun de ces types n'est un nombre : tous sont conserves en
# texte, un CIB commencant par un zero le perdrait autrement.
TYPES_ADPE: tuple[str, ...] = (
    "texte",
    "code",
    "telephone",
    "email",
    "date",
    "pays",
)

# L'État de la case C5 n'est pas un nom à taper : le FODEP est la déclaration
# prudentielle de l'UMOA, et un établissement qui la remplit relève de l'un
# des huit États membres. Les proposer evite la faute de frappe et
# l'orthographe approximative sur une case qui identifie la déclaration.
#
# L'ordre est celui de l'alphabet, comme la BCEAO les enumere.
PAYS_UEMOA: tuple[str, ...] = (
    "Bénin",
    "Burkina Faso",
    "Côte d'Ivoire",
    "Guinée-Bissau",
    "Mali",
    "Niger",
    "Sénégal",
    "Togo",
)

# Valeurs proposees par les cases dont le contenu se choisit dans une liste.
CHOIX_PAR_TYPE: dict[str, tuple[str, ...]] = {"pays": PAYS_UEMOA}

CHAMPS_ADPE: tuple[tuple[str, str, str, str], ...] = (
    ("C5", "État", "Identification", "pays"),
    ("T5", "Établissement", "Identification", "texte"),
    ("N7", "CIB — code identifiant bancaire (5 caractères)", "Identification", "code"),
    ("T7", "Lettre clé (1 caractère)", "Identification", "code"),
    ("N16", "Prénoms et nom", "Responsable du renseignement", "texte"),
    ("N18", "Fonction", "Responsable du renseignement", "texte"),
    ("N20", "Téléphone", "Responsable du renseignement", "telephone"),
    # Le « poste » est le numero interne au standard : des chiffres, jamais un
    # montant, et son zero de tete compte autant que celui d'un numero.
    ("AB20", "Poste", "Responsable du renseignement", "telephone"),
    ("N22", "E-mail", "Responsable du renseignement", "email"),
    ("N26", "Prénoms et nom", "Responsable de la transmission", "texte"),
    ("N28", "Fonction", "Responsable de la transmission", "texte"),
    ("N30", "Téléphone", "Responsable de la transmission", "telephone"),
    ("AB30", "Poste", "Responsable de la transmission", "telephone"),
    ("N32", "E-mail", "Responsable de la transmission", "email"),
    ("C37", "Premier signataire", "Certification", "texte"),
    ("T37", "Second signataire", "Certification", "texte"),
    # Le formulaire n'ouvre aucune case en face de « Code Signature » : cette
    # ligne attend une signature, pas une valeur a taper. Elle ne figure donc
    # pas ici, et l'ecran ne la propose pas.
    ("G45", "Fonction", "Premier signataire", "texte"),
    ("X45", "Date (AAAA-MM-JJ)", "Premier signataire", "date"),
    ("G51", "Fonction", "Second signataire", "texte"),
    ("X51", "Date (AAAA-MM-JJ)", "Second signataire", "date"),
)


# Champs que le formulaire presente en grille de petites cases, un caractere
# par case, et non en ligne de saisie continue. Le declarant tape une valeur,
# l'export la repartit. La date d'arrete suit deja ce principe, ecrite par
# `_remplir_attestation` ; le CIB obeit a la meme presentation.
#
# La cle est la premiere case de la grille : c'est elle qui identifie le champ.
CHAMPS_ECLATES: dict[tuple[str, str], tuple[str, ...]] = {
    ("ADPE", "N7"): ("N7", "O7", "P7", "Q7", "R7"),
}


def _ecrire_champ_eclate(feuille, cases: tuple[str, ...], valeur: str) -> None:
    """Repartit une valeur caractere par caractere sur une grille de cases.

    Une valeur plus courte que la grille laisse les cases restantes vides
    plutot que de decaler : le formulaire attend un caractere par case, pas un
    texte cadre. Une valeur plus longue est tronquee — il n'y a pas de case ou
    mettre le surplus, et le silence vaut mieux qu'un debordement invisible.
    """

    for index, case in enumerate(cases):
        feuille[case] = valeur[index] if index < len(valeur) else None


def catalogue_adpe() -> list[CaseASaisir]:
    """Champs de l'attestation, dans l'ordre du formulaire."""

    return [
        CaseASaisir(
            etat="ADPE",
            cellule=cellule,
            # L'attestation n'a pas de code DISPRU : le groupe tient ce role,
            # c'est lui qui dit de quel bloc du formulaire la case releve.
            ligne=index,
            code=groupe,
            libelle=libelle,
            colonne="",
            type_saisie=type_champ,
            choix=CHOIX_PAR_TYPE.get(type_champ, ()),
        )
        for index, (cellule, libelle, groupe, type_champ) in enumerate(
            CHAMPS_ADPE
        )
    ]


# ─── Etats prudentiels sans source dans l'application ────────────────────────

# Ce que le declarant renseigne lui-meme, faute que l'outil sache le produire.
# L'intitule est celui du formulaire, abrege ; il dit ce que l'etat affirme
# quand il part a zero.
# L'unite de declaration vaut pour tout le formulaire : « tous les montants
# doivent etre declares en millions de franc CFA » (notice, § 2.3). Ce qui est
# saisi ici est ecrit tel quel dans le classeur, sans conversion — contrairement
# aux montants que l'application calcule, qu'elle ramene au million elle-meme.
# Le rappeler sur l'ecran evite l'erreur d'un facteur un million.
UNITE_DE_DECLARATION = (
    "Montants en millions de FCFA, comme tout le formulaire (notice, § 2.3). "
    "Ce qui est laissé vide part à zéro."
)

ETATS_A_SAISIR: tuple[tuple[str, str, str], ...] = (
    (
        "EP04",
        "Dispositions transitoires : reclassement et retrait progressif des "
        "éléments de fonds propres non admissibles",
        UNITE_DE_DECLARATION,
    ),
    (
        "EP11",
        "Expositions au risque de contrepartie : engagements sur instruments "
        "de taux, de change, de propriété et produits de base",
        UNITE_DE_DECLARATION
        + " Le montant notionnel pondéré (d = b × c) et l'exposition "
        "(e = a + d) ne se saisissent pas : l'export les calcule à partir du "
        "coût de remplacement, du montant notionnel et de la pondération "
        "imprimée sur le formulaire. La ligne de total non plus — elle somme "
        "les lignes ci-dessus, colonne par colonne.",
    ),
    (
        "EP28",
        "Risque de marché : exigences de fonds propres au titre du risque de "
        "position sur produits de base",
        UNITE_DE_DECLARATION,
    ),
)


# « A. », « B) » — la numerotation des blocs du formulaire.
MARQUEUR_DE_SECTION = re.compile(r"^[A-Z]\s*[.)]\s*")

# Colonnes que l'export calcule lui-meme, etat par etat. Le formulaire imprime
# leur formule en tete de colonne — l'EP11 annonce « d=b x c » et « e= a + d » —
# mais il ne porte aucune formule vivante hors de l'EP01 (notice, § 3.3) : la
# case attend un resultat, pas un calcul. Les proposer a la saisie reviendrait a
# demander trente-deux multiplications a la main, et a accepter qu'elles soient
# fausses sans que rien ne le dise.
COLONNES_CALCULEES: dict[str, frozenset[str]] = {"EP11": frozenset({"F", "G"})}

# Ligne de total de l'etat, sommee par l'export sur les lignes qui la precedent.
LIGNES_DE_TOTAL: dict[str, str] = {"EP11": "RC064"}


def _est_calculee(etat: str, code: str, colonne_lettre: str) -> bool:
    """La case est-elle produite par l'export plutot que saisie ?"""

    return (
        colonne_lettre in COLONNES_CALCULEES.get(etat, frozenset())
        or code == LIGNES_DE_TOTAL.get(etat)
    )


def _texte(feuille, ligne: int, colonne: int) -> str:
    """Texte d'une cellule, en atteignant l'ancre des cellules fusionnees.

    Les en-tetes du formulaire chevauchent plusieurs colonnes : « Toutes les
    positions » couvre C et D, et seule C porte la valeur. Lire D directement
    rendrait une colonne nommee « Courtes » sans dire courtes de quoi.
    """

    cellule = feuille.cell(row=ligne, column=colonne)
    if isinstance(cellule, MergedCell):
        for plage in feuille.merged_cells.ranges:
            if (ligne, colonne) in plage.cells:
                cellule = feuille.cell(row=plage.min_row, column=plage.min_col)
                break
    valeur = cellule.value
    if not isinstance(valeur, str):
        return ""
    return " ".join(valeur.split())


def _ouvre_un_tableau(feuille, ligne: int) -> bool:
    """La ligne est-elle l'en-tete « Code DISPRU » d'un bloc ?

    Le test porte sur la valeur brute, pas sur l'ancre d'une fusion : l'EP28
    fusionne A9:A11, et resoudre la fusion ferait passer les rangs 10 et 11 pour
    des en-tetes de bloc — la remontee s'arreterait avant d'avoir ramasse
    « Positions » et « Toutes les positions ».
    """

    valeur = feuille.cell(row=ligne, column=1).value
    return isinstance(valeur, str) and valeur.strip().lower().startswith("code dispru")


def _entete_de_colonne(feuille, ligne: int, colonne: int) -> str:
    """En-tete de la colonne, reconstitue en remontant depuis la case.

    Le formulaire empile ses en-tetes sur deux ou trois rangs — « Positions /
    Toutes les positions / Longues ». Les remonter jusqu'a la ligne qui porte
    « Code DISPRU » les rassemble dans l'ordre de lecture : sans ce contexte,
    l'ecran proposerait trois colonnes nommees « Longues » sans dire
    lesquelles. Cette ligne-la est incluse : c'est elle qui nomme la colonne
    quand le formulaire n'empile rien au-dessus.

    La remontee n'est pas bornee a quelques rangs : l'EP11 aligne vingt-huit
    lignes de saisie sous un unique en-tete, et l'EP04 autant. C'est la ligne
    d'en-tete qui ferme la recherche, pas une distance.
    """

    fragments: list[str] = []
    for rang in range(ligne - 1, 0, -1):
        texte = _texte(feuille, rang, colonne)
        # Une fusion verticale rend le meme texte sur chacun de ses rangs :
        # « Montant — Montant — Montant » ne nomme pas mieux la colonne.
        if texte and texte not in fragments:
            fragments.append(texte)
        if _ouvre_un_tableau(feuille, rang):
            break
    return " — ".join(reversed(fragments))


def _libelle_de_ligne(feuille, ligne: int) -> str:
    """Le poste, tel que la colonne B le nomme."""

    return _texte(feuille, ligne, 2).lstrip("- ").strip()


def _titre_de_bloc(feuille, ligne: int) -> str:
    """Titre du groupe de lignes auquel la ligne appartient, s'il en a un.

    Le formulaire le met a deux endroits : en colonne B au-dessus d'un groupe
    de lignes (EP04, EP11), ou en colonne A au-dessus de la ligne « Code
    DISPRU » quand l'etat compte plusieurs tableaux (EP28). Les lignes deja
    codees sont traversees : le titre vaut pour tout le bloc, pas seulement
    pour sa premiere ligne.

    La colonne A se lit brute, sans resoudre les fusions : l'EP28 fusionne
    A9:A11, et l'ancre resolue ferait passer « Code DISPRU » pour un titre.

    Le marqueur de section — « A. », « B. » — est retire : il numerote le bloc
    dans le formulaire, il ne dit rien de la case.
    """

    for rang in range(ligne - 1, 0, -1):
        if _ouvre_un_tableau(feuille, rang):
            continue  # l'en-tete du tableau : le titre de section est au-dessus
        brut = feuille.cell(row=rang, column=1).value
        premiere = " ".join(brut.split()) if isinstance(brut, str) else ""
        if premiere:
            if MOTIF_CODE_DISPRU.fullmatch(premiere):
                continue  # une ligne du meme bloc
            return MARQUEUR_DE_SECTION.sub("", premiere)
        titre = MARQUEUR_DE_SECTION.sub("", _texte(feuille, rang, 2))
        if titre and not titre.lower().startswith("poste"):
            return titre
    return ""


@lru_cache(maxsize=1)
def _catalogue_prudentiel() -> tuple[CaseASaisir, ...]:
    """Cases ouvertes des etats sans source, relues dans le formulaire.

    Elles ne sont pas enumerees ici : c'est le verrouillage pose par la BCEAO
    qui les designe, comme pour le reste de l'export. Une case ajoutee par une
    nouvelle version du formulaire apparait donc a l'ecran sans toucher au
    code.

    Le resultat est mis en cache : le modele est un fichier fige de 600 Ko, et
    l'ecran de saisie le redemande a chaque ouverture.
    """

    classeur = load_workbook(CHEMIN_MODELE)
    try:
        styles = styles_ouverts(classeur)
        cases: list[CaseASaisir] = []
        for etat, _, _note in ETATS_A_SAISIR:
            if etat not in classeur.sheetnames:
                continue
            feuille = classeur[etat]
            ouvertes = sorted(
                (cellule.row, cellule.column)
                for cellule in tuple(feuille._cells.values())
                if cellule.row >= PREMIERE_LIGNE_UTILE
                and not isinstance(cellule, MergedCell)
                and (
                    cellule._style is not None
                    and styles is not None
                    and cellule._style.protectionId in styles
                )
            )
            # Le titre de bloc ne prefixe que les libelles qui se repetent :
            # l'EP11 nomme cinq fois « Durée > 5 ans », sous cinq natures
            # d'engagement qui seules les distinguent. Ailleurs, le prefixer
            # noierait le poste sous un titre identique d'une ligne a l'autre.
            rangs_par_libelle: dict[str, set[int]] = {}
            for ligne, _ in ouvertes:
                rangs_par_libelle.setdefault(
                    _libelle_de_ligne(feuille, ligne), set()
                ).add(ligne)
            ambigus = {
                libelle
                for libelle, rangs in rangs_par_libelle.items()
                if libelle and len(rangs) > 1
            }
            for ligne, colonne in ouvertes:
                code = _texte(feuille, ligne, 1)
                if not MOTIF_CODE_DISPRU.fullmatch(code):
                    # Une case ouverte hors d'une ligne codee n'a pas d'adresse
                    # dans la nomenclature : la plate-forme ne saurait pas la
                    # lire, et le declarant pas la nommer.
                    continue
                case = feuille.cell(row=ligne, column=colonne)
                if _est_calculee(etat, code, case.column_letter):
                    continue
                libelle = _libelle_de_ligne(feuille, ligne)
                if libelle in ambigus:
                    titre = _titre_de_bloc(feuille, ligne)
                    if titre:
                        libelle = f"{titre} — {libelle}"
                cases.append(
                    CaseASaisir(
                        etat=etat,
                        cellule=case.coordinate,
                        ligne=ligne,
                        code=code,
                        libelle=libelle,
                        colonne=_entete_de_colonne(feuille, ligne, colonne),
                    )
                )
        return tuple(cases)
    finally:
        classeur.close()


def catalogue_etat(nom_etat: str) -> list[CaseASaisir]:
    """Cases a saisir d'un etat prudentiel, dans l'ordre du formulaire."""

    return [case for case in _catalogue_prudentiel() if case.etat == nom_etat]


def _horodatage() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


# ─── Conservation des saisies ────────────────────────────────────────────────


@dataclass
class SaisieEnregistree:
    """Ce qu'une case porte : un nombre, un texte, et sa justification."""

    valeur: float | None = None
    texte: str | None = None
    commentaire: str | None = None

    @property
    def renseignee(self) -> bool:
        return self.valeur is not None or bool(self.texte)

    @property
    def contenu(self):
        """Ce qui sera ecrit dans la cellule, texte prioritaire."""

        return self.texte if self.texte else self.valeur


# ─── Date d'arrete ───────────────────────────────────────────────────────────

# La date d'arrete est saisie sur le meme ecran que le reste de l'attestation,
# et elle n'etait retenue que le temps de la session : choisie puis la page
# rechargee, elle repartait de la date de fin du reporting. C'est une donnee du
# declarant comme les autres — elle se conserve.
#
# Elle ne vit pas dans « saisies_fodep » : cette table est indexee par une
# cellule du classeur, or la date n'occupe pas une cellule mais une grille de
# huit cases que l'export remplit lui-meme.
CLE_DATE_ARRETE = "fodep_date_arrete"


def lire_date_arrete() -> date | None:
    """Date d'arrete retenue par le declarant, si elle a ete choisie."""

    with database_manager.read_connection() as connexion:
        ligne = connexion.execute(
            "SELECT valeur FROM metadonnees_app WHERE cle = ?",
            (CLE_DATE_ARRETE,),
        ).fetchone()
    if ligne is None:
        return None
    try:
        return date.fromisoformat(str(ligne["valeur"]))
    except ValueError:
        # Une valeur illisible vaut absence : l'export retombe sur la date
        # deduite du portefeuille plutot que d'echouer.
        return None


def enregistrer_date_arrete(valeur: date | None) -> None:
    """Retient la date d'arrete. Une valeur absente ne l'efface pas.

    Rien dans l'ecran ne retire une date deja choisie : on la remplace. Traiter
    l'absence comme un effacement ferait donc perdre la date au premier
    enregistrement d'une autre case.
    """

    if valeur is None:
        return
    with database_manager.transaction() as connexion:
        connexion.execute(
            """
            INSERT INTO metadonnees_app(cle, valeur) VALUES(?, ?)
            ON CONFLICT(cle) DO UPDATE SET valeur = excluded.valeur
            """,
            (CLE_DATE_ARRETE, valeur.isoformat()),
        )


def lire_saisies() -> dict[tuple[str, str], SaisieEnregistree]:
    """Saisies enregistrees, indexees par (etat, cellule)."""

    with database_manager.read_connection() as connexion:
        lignes = connexion.execute(
            "SELECT etat, cellule, valeur, texte, commentaire FROM saisies_fodep"
        ).fetchall()
    return {
        (str(ligne["etat"]), str(ligne["cellule"])): SaisieEnregistree(
            valeur=ligne["valeur"],
            texte=ligne["texte"],
            commentaire=ligne["commentaire"],
        )
        for ligne in lignes
    }


def enregistrer_saisies(saisies: list[dict]) -> int:
    """Enregistre ou efface des saisies. Retourne le nombre de cases touchees.

    Une case videe est effacee plutot qu'enregistree a zero : le declarant qui
    efface revient a l'etat « non renseigne », que le balayage final traitera
    comme avant. Enregistrer un zero dirait le contraire — qu'il a constate
    l'absence.
    """

    horodatage = _horodatage()
    touchees = 0
    with database_manager.transaction() as connexion:
        for saisie in saisies:
            etat = str(saisie.get("etat") or "").strip()
            cellule = str(saisie.get("cellule") or "").strip().upper()
            if not etat or not cellule:
                continue
            valeur = saisie.get("valeur")
            texte = saisie.get("texte")
            texte = texte.strip() if isinstance(texte, str) else None
            commentaire = saisie.get("commentaire")
            if valeur is None and not texte:
                connexion.execute(
                    "DELETE FROM saisies_fodep WHERE etat = ? AND cellule = ?",
                    (etat, cellule),
                )
            else:
                connexion.execute(
                    """
                    INSERT INTO saisies_fodep(
                        etat, cellule, valeur, texte, commentaire, modifie_le
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    ON CONFLICT(etat, cellule) DO UPDATE SET
                        valeur = excluded.valeur,
                        texte = excluded.texte,
                        commentaire = excluded.commentaire,
                        modifie_le = excluded.modifie_le
                    """,
                    (
                        etat,
                        cellule,
                        float(valeur) if valeur is not None else None,
                        texte,
                        commentaire,
                        horodatage,
                    ),
                )
            touchees += 1
    return touchees


def appliquer_saisies(classeur) -> int:
    """Ecrit les saisies dans le classeur. Retourne le nombre de cases ecrites.

    Les cases dont l'etat n'existe pas dans le modele sont ignorees en silence :
    une declaration ne doit pas echouer parce qu'une saisie ancienne vise un
    onglet disparu.
    """

    ecrites = 0
    for (etat, cellule), saisie in lire_saisies().items():
        if etat not in classeur.sheetnames or not saisie.renseignee:
            continue
        try:
            cases = CHAMPS_ECLATES.get((etat, cellule))
            if cases:
                _ecrire_champ_eclate(
                    classeur[etat], cases, str(saisie.contenu).strip()
                )
            else:
                classeur[etat][cellule] = saisie.contenu
        except (ValueError, KeyError, AttributeError):
            # Une cellule fusionnee refuse l'ecriture ailleurs que sur sa
            # premiere case : la saisie est ignoree plutot que de faire
            # echouer toute la declaration.
            continue
        ecrites += 1
    return ecrites
