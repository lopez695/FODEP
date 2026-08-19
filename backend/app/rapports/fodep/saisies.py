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

Les etats prudentiels n'y figurent plus. Ceux que l'application n'alimente pas
encore ont leur source ailleurs dans l'outil — coefficients beta, produit brut
par ligne de metier, incidents de pertes — et demandent d'etre cables, pas
saisis. Un ecran de saisie n'a pas a redemander ce que la base contient deja.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timezone

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
