"""Registre des instruments derives, et son agregation pour l'EP11.

Ce module tient les contrats et les range dans les quinze lignes de l'etat. Il
ne connait pas le formulaire : les ponderations que la BCEAO imprime dans la
colonne (c) sont relues dans le modele par l'export, qui seul a besoin de les
appliquer. Les coder ici en ferait une seconde source, et une nouvelle version
du formulaire les ferait diverger.

Chaque contrat designe une contrepartie du portefeuille. Sa colonne sur l'EP11
se deduit de la categorie prudentielle de la fiche, par la fonction meme qu'emploie
le moteur de calcul : un derive et un pret sur le meme tiers ne peuvent pas etre
ranges dans deux categories differentes.

Il peut aussi designer ce qu'il couvre : un credit, une obligation, une action.
Les obligations et les actions sont lues par le module VaR, celui meme des
ecrans de marche -- une seconde lecture des memes positions finirait par en
montrer d'autres.
"""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field
from datetime import date, datetime, timezone

from fastapi import HTTPException, status

from app.core.calculations import convert_currency_amount
from app.derives.models import (
    ActionDetenue,
    ContrepartieDerive,
    CreditCouvrable,
    DeriveCreate,
    DeriveUpdate,
    DeriveView,
    LIBELLES_NATURES,
    LIBELLES_SOUS_JACENTS,
    NATURE_IMPOSEE,
    ObligationDetenue,
    SousJacents,
    TRANCHES_DUREE,
    tranche_de_duree,
)
from database.connection import database_manager
from database.services.rwa_calculation_service import resolve_category

DEVISE_DECLARATION = "XOF"

#: Les categories qui ont une colonne sur l'EP11 : souverains, organismes
#: publics, banques multilaterales, institutions financieres, entreprises.
COLONNES_EP11 = frozenset({"a", "b", "c", "d", "e"})

#: Ou se range un derive sur un tiers dont la categorie n'a pas de colonne.
#: « Entreprises » est la categorie de repli du FODEP lui-meme : c'est la que
#: l'agregation du risque de credit reclasse deja les creances en souffrance.
CATEGORIE_DE_REPLI = "e"

SELECTION = """
    SELECT d.id, d.contrepartie_id,
           d.contrepartie AS nom_recopie,
           d.categorie_contrepartie AS categorie_recopiee,
           c.nom AS nom_fiche, c.categorie_prudentielle, c.notation,
           d.sous_jacent_type, d.sous_jacent_ref, d.sous_jacent_libelle,
           d.nature, d.type_contrat, d.devise, d.montant_notionnel,
           d.cout_remplacement, d.date_conclusion, d.date_echeance,
           d.commentaire, d.cree_le, d.modifie_le
    FROM derives d
    LEFT JOIN contreparties c ON c.id = d.contrepartie_id
"""


def categorie_ep11(categorie_prudentielle: str | None) -> tuple[str, bool]:
    """Colonne de l'EP11 d'un tiers, et si elle est un repli.

    La categorie prudentielle est lue par `resolve_category`, celle du moteur
    de calcul. Les cinq premieres ont leur colonne ; les autres -- clientele de
    detail, immobilier, creances en souffrance, autres actifs -- n'en ont pas,
    et une categorie absente non plus. Le derive se range alors sous
    « Entreprises », et le second terme le dit pour que l'ecran et l'export le
    signalent.
    """

    libelle = (categorie_prudentielle or "").strip()
    if not libelle:
        return CATEGORIE_DE_REPLI, True
    code = resolve_category(libelle)["code"]
    if code in COLONNES_EP11:
        return code, False
    return CATEGORIE_DE_REPLI, True


def _horodatage() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _date(valeur) -> date | None:
    if isinstance(valeur, date):
        return valeur
    texte = str(valeur or "").strip()
    if not texte:
        return None
    try:
        return date.fromisoformat(texte[:10])
    except ValueError:
        return None


def _refus(code: str, message: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail={"code": code, "message": message},
    )


def _vers_vue(ligne, reference: date) -> DeriveView:
    donnees = dict(ligne)

    # Tant que la fiche existe, c'est elle qui fait foi : une contrepartie
    # reclassee change la colonne de ses derives comme celle de ses prets. La
    # recopie sur le contrat ne sert que si la fiche a disparu.
    if donnees.get("nom_fiche") is not None:
        nom = donnees["nom_fiche"]
        categorie, hors = categorie_ep11(donnees.get("categorie_prudentielle"))
    else:
        nom = donnees.get("nom_recopie") or ""
        recopiee = donnees.get("categorie_recopiee")
        categorie = recopiee if recopiee in COLONNES_EP11 else CATEGORIE_DE_REPLI
        hors = False

    echeance = _date(donnees.get("date_echeance"))
    return DeriveView(
        id=donnees["id"],
        contrepartie_id=donnees.get("contrepartie_id"),
        contrepartie=nom,
        categorie_contrepartie=categorie,
        categorie_prudentielle=donnees.get("categorie_prudentielle"),
        notation=donnees.get("notation"),
        hors_ep11=hors,
        sous_jacent_type=donnees.get("sous_jacent_type") or "autre",
        sous_jacent_ref=donnees.get("sous_jacent_ref"),
        sous_jacent_libelle=donnees.get("sous_jacent_libelle"),
        nature=donnees["nature"],
        type_contrat=donnees.get("type_contrat"),
        devise=donnees.get("devise") or DEVISE_DECLARATION,
        montant_notionnel=float(donnees.get("montant_notionnel") or 0.0),
        cout_remplacement=float(donnees.get("cout_remplacement") or 0.0),
        date_conclusion=_date(donnees.get("date_conclusion")),
        date_echeance=echeance,
        commentaire=donnees.get("commentaire"),
        cree_le=donnees.get("cree_le") or "",
        modifie_le=donnees.get("modifie_le") or "",
        tranche=tranche_de_duree(echeance, reference) if echeance else "moins_1_an",
    )


def _resoudre_contrepartie(identifiant: str) -> tuple[str, str]:
    """Le nom et la colonne EP11 d'une contrepartie du portefeuille.

    Un identifiant inconnu est refuse plutot qu'enregistre : un derive sur un
    tiers que l'application ne connait pas ne se relie a rien, et c'est
    precisement ce que le rattachement doit empecher.
    """

    with database_manager.read_connection() as connexion:
        ligne = connexion.execute(
            "SELECT nom, categorie_prudentielle FROM contreparties WHERE id = ?",
            (identifiant,),
        ).fetchone()
    if ligne is None:
        raise _refus(
            "CONTREPARTIE_INCONNUE",
            f"Aucune contrepartie du portefeuille ne porte l'identifiant "
            f"{identifiant}. Un derive se rattache a une contrepartie "
            "existante : creez-la ou importez-la d'abord.",
        )
    categorie, _ = categorie_ep11(ligne["categorie_prudentielle"])
    return ligne["nom"] or identifiant, categorie


# ─── Les sous-jacents ────────────────────────────────────────────────────────


def _obligations_detenues() -> tuple[list[ObligationDetenue], str | None]:
    """Les obligations du portefeuille de marche, lues par le module VaR.

    Le chargeur peut lever sur une ligne illisible : l'erreur devient une
    alerte, et le reste du selecteur -- les credits, les actions -- reste
    utilisable.
    """

    from app.var_marche.portefeuille_data import (
        ErreurDonneesVar,
        charger_positions_obligations,
    )

    try:
        positions = charger_positions_obligations()
    except ErreurDonneesVar as erreur:
        return [], f"Portefeuille obligataire illisible : {erreur}"
    return [
        ObligationDetenue(
            isin=position.isin,
            emetteur=position.emetteur,
            devise=position.devise,
            date_echeance=position.date_echeance,
            valeur_nominale=position.valeur_nominale,
            quantite=position.quantite,
            taux_coupon_pct=position.taux_coupon_pct,
        )
        for position in positions
    ], None


def _actions_detenues() -> tuple[list[ActionDetenue], str | None]:
    """Les actions du portefeuille de marche, lues par le module VaR."""

    from app.var_marche.portefeuille_data import (
        ErreurDonneesVar,
        charger_positions_actions,
    )

    try:
        positions = charger_positions_actions()
    except ErreurDonneesVar as erreur:
        return [], f"Portefeuille d'actions illisible : {erreur}"
    return [
        ActionDetenue(
            ticker=position.ticker,
            libelle=position.libelle,
            secteur=position.secteur,
            quantite=position.quantite,
        )
        for position in positions
    ], None


def lister_sous_jacents() -> SousJacents:
    """Ce a quoi un derive peut se rattacher, par onglet du formulaire."""

    with database_manager.read_connection() as connexion:
        lignes = connexion.execute(
            """
            SELECT e.id, e.contrepartie_id, c.nom, c.categorie_prudentielle,
                   c.notation, e.montant_brut, e.devise, e.date_echeance,
                   e.statut
            FROM expositions e
            JOIN contreparties c ON c.id = e.contrepartie_id
            ORDER BY c.nom, e.id
            """
        ).fetchall()

    credits: list[CreditCouvrable] = []
    for ligne in lignes:
        categorie, hors = categorie_ep11(ligne["categorie_prudentielle"])
        credits.append(CreditCouvrable(
            id=ligne["id"],
            contrepartie_id=ligne["contrepartie_id"],
            contrepartie=ligne["nom"] or ligne["contrepartie_id"],
            categorie_prudentielle=ligne["categorie_prudentielle"],
            categorie_ep11=categorie,
            hors_ep11=hors,
            notation=ligne["notation"],
            montant_brut=float(ligne["montant_brut"] or 0.0),
            devise=ligne["devise"] or DEVISE_DECLARATION,
            date_echeance=_date(ligne["date_echeance"]),
            statut=ligne["statut"],
        ))

    alertes: list[str] = []
    obligations, alerte = _obligations_detenues()
    if alerte:
        alertes.append(alerte)
    actions, alerte = _actions_detenues()
    if alerte:
        alertes.append(alerte)
    return SousJacents(
        credits=credits, obligations=obligations, actions=actions, alertes=alertes
    )


def _resoudre_sous_jacent(
    type_sous_jacent: str | None,
    reference: str | None,
    nature: str,
    contrepartie_id: str | None,
) -> tuple[str | None, str | None]:
    """La reference et le libelle d'un sous-jacent, apres controle.

    Trois regles, que l'ecran applique deja mais qui doivent tenir pour un
    appel direct a l'API :

    * un credit se couvre avec son propre client -- le contrat doit etre signe
      par la contrepartie du credit ;
    * un derive sur une obligation porte sur les taux, un derive sur une action
      sur les titres de propriete ;
    * la position designee doit exister dans le portefeuille.
    """

    if type_sous_jacent in (None, "autre"):
        return None, None

    libelle_type = LIBELLES_SOUS_JACENTS.get(type_sous_jacent, type_sous_jacent)
    reference = (reference or "").strip()
    if not reference:
        raise _refus(
            "SOUS_JACENT_MANQUANT",
            f"Un contrat rattache a {libelle_type} doit designer laquelle.",
        )

    imposee = NATURE_IMPOSEE.get(type_sous_jacent)
    if imposee and nature != imposee:
        raise _refus(
            "NATURE_INCOMPATIBLE",
            f"Un derive sur {libelle_type} porte sur « "
            f"{LIBELLES_NATURES[imposee]} » : il ne peut pas etre declare sur "
            f"« {LIBELLES_NATURES.get(nature, nature)} ».",
        )

    if type_sous_jacent == "credit":
        with database_manager.read_connection() as connexion:
            ligne = connexion.execute(
                """
                SELECT e.id, e.contrepartie_id, c.nom
                FROM expositions e
                LEFT JOIN contreparties c ON c.id = e.contrepartie_id
                WHERE e.id = ?
                """,
                (reference,),
            ).fetchone()
        if ligne is None:
            raise _refus(
                "SOUS_JACENT_INCONNU",
                f"Aucun credit du portefeuille ne porte l'identifiant {reference}.",
            )
        if ligne["contrepartie_id"] != contrepartie_id:
            raise _refus(
                "CONTREPARTIE_INCOHERENTE",
                f"Un credit se couvre avec son propre client : le contrat doit "
                f"etre signe avec {ligne['nom']} ({ligne['contrepartie_id']}).",
            )
        return reference, f"Credit {reference} — {ligne['nom']}"

    if type_sous_jacent == "obligation":
        obligations, alerte = _obligations_detenues()
        for obligation in obligations:
            if obligation.isin == reference:
                return reference, f"{obligation.isin} — {obligation.emetteur}"
        raise _refus(
            "SOUS_JACENT_INCONNU",
            alerte or f"Aucune obligation du portefeuille ne porte l'ISIN {reference}.",
        )

    actions, alerte = _actions_detenues()
    for action in actions:
        if action.ticker == reference:
            return reference, action.libelle
    raise _refus(
        "SOUS_JACENT_INCONNU",
        alerte or f"Aucune action du portefeuille ne porte le code {reference}.",
    )


# ─── Le registre ─────────────────────────────────────────────────────────────


def lister_derives(reference: date | None = None) -> list[DeriveView]:
    """Les contrats du registre, par nature puis par echeance.

    `reference` est la date a laquelle se lit la duree residuelle : celle de
    l'arrete quand l'export appelle, celle du jour quand c'est l'ecran.
    """

    reference = reference or date.today()
    with database_manager.read_connection() as connexion:
        lignes = connexion.execute(
            SELECTION
            + " ORDER BY d.nature, d.date_echeance, COALESCE(c.nom, d.contrepartie)"
        ).fetchall()
    return [_vers_vue(ligne, reference) for ligne in lignes]


def lister_contreparties_derives() -> list[ContrepartieDerive]:
    """Les contreparties du portefeuille, pour le selecteur du formulaire.

    Chacune avec son identifiant, sa categorie prudentielle, la colonne EP11
    qu'en tirerait un derive, et sa notation : de quoi choisir la bonne sans
    ouvrir sa fiche.
    """

    with database_manager.read_connection() as connexion:
        lignes = connexion.execute(
            """
            SELECT id, nom, pays, categorie_prudentielle, notation
            FROM contreparties
            ORDER BY nom, id
            """
        ).fetchall()

    contreparties: list[ContrepartieDerive] = []
    for ligne in lignes:
        categorie, hors = categorie_ep11(ligne["categorie_prudentielle"])
        contreparties.append(ContrepartieDerive(
            id=ligne["id"],
            nom=ligne["nom"] or ligne["id"],
            pays=ligne["pays"],
            categorie_prudentielle=ligne["categorie_prudentielle"],
            categorie_ep11=categorie,
            hors_ep11=hors,
            notation=ligne["notation"],
        ))
    return contreparties


def creer_derive(payload: DeriveCreate) -> DeriveView:
    identifiant_contrepartie = payload.contrepartie_id.strip()
    nom, categorie = _resoudre_contrepartie(identifiant_contrepartie)
    reference, libelle = _resoudre_sous_jacent(
        payload.sous_jacent_type,
        payload.sous_jacent_ref,
        payload.nature,
        identifiant_contrepartie,
    )
    horodatage = _horodatage()
    with database_manager.transaction() as connexion:
        curseur = connexion.execute(
            """
            INSERT INTO derives(
                contrepartie_id, contrepartie, categorie_contrepartie,
                sous_jacent_type, sous_jacent_ref, sous_jacent_libelle,
                nature, type_contrat, devise, montant_notionnel,
                cout_remplacement, date_conclusion, date_echeance, commentaire,
                cree_le, modifie_le
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                identifiant_contrepartie,
                nom,
                categorie,
                payload.sous_jacent_type,
                reference,
                libelle,
                payload.nature,
                payload.type_contrat,
                payload.devise.upper(),
                payload.montant_notionnel,
                payload.cout_remplacement,
                payload.date_conclusion.isoformat() if payload.date_conclusion else None,
                payload.date_echeance.isoformat(),
                payload.commentaire,
                horodatage,
                horodatage,
            ),
        )
        identifiant = int(curseur.lastrowid or 0)
    return _lire_ou_404(identifiant)


def modifier_derive(identifiant: int, payload: DeriveUpdate) -> DeriveView:
    champs = payload.model_dump(exclude_unset=True)
    for cle in ("contrepartie_id", "sous_jacent_type"):
        if cle in champs and champs[cle] is None:
            champs.pop(cle)
    if not champs:
        return _lire_ou_404(identifiant)

    actuel = _lire_ou_404(identifiant)

    # Changer de contrepartie change aussi la recopie : sans cela, le contrat
    # garderait le nom et la colonne de l'ancien tiers si la fiche disparaissait.
    if "contrepartie_id" in champs:
        champs["contrepartie_id"] = champs["contrepartie_id"].strip()
        nom, categorie = _resoudre_contrepartie(champs["contrepartie_id"])
        champs["contrepartie"] = nom
        champs["categorie_contrepartie"] = categorie

    # Le sous-jacent se controle avec la nature et la contrepartie qu'aura le
    # contrat APRES la modification : changer l'une peut rendre l'autre
    # incoherent, meme sans toucher au sous-jacent lui-meme.
    if {"sous_jacent_type", "sous_jacent_ref", "nature", "contrepartie_id"} & champs.keys():
        type_actuel = actuel.sous_jacent_type or "autre"
        type_final = champs.get("sous_jacent_type", type_actuel)
        if "sous_jacent_ref" in champs:
            reference_finale = champs["sous_jacent_ref"]
        else:
            reference_finale = actuel.sous_jacent_ref if type_final == type_actuel else None
        reference, libelle = _resoudre_sous_jacent(
            type_final,
            reference_finale,
            champs.get("nature", actuel.nature),
            champs.get("contrepartie_id", actuel.contrepartie_id),
        )
        champs["sous_jacent_type"] = type_final
        champs["sous_jacent_ref"] = reference
        champs["sous_jacent_libelle"] = libelle

    for cle in ("date_conclusion", "date_echeance"):
        if isinstance(champs.get(cle), date):
            champs[cle] = champs[cle].isoformat()
    if isinstance(champs.get("devise"), str):
        champs["devise"] = champs["devise"].upper()

    affectations = ", ".join(f"{nom} = ?" for nom in champs)
    valeurs = list(champs.values()) + [_horodatage(), identifiant]
    with database_manager.transaction() as connexion:
        curseur = connexion.execute(
            f"UPDATE derives SET {affectations}, modifie_le = ? WHERE id = ?",
            valeurs,
        )
        if curseur.rowcount == 0:
            raise _introuvable(identifiant)
    return _lire_ou_404(identifiant)


def supprimer_derive(identifiant: int) -> None:
    with database_manager.transaction() as connexion:
        curseur = connexion.execute("DELETE FROM derives WHERE id = ?", (identifiant,))
        if curseur.rowcount == 0:
            raise _introuvable(identifiant)


def _introuvable(identifiant: int) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail={
            "code": "DERIVE_INTROUVABLE",
            "message": f"Aucun contrat derive ne porte l'identifiant {identifiant}.",
        },
    )


def _lire_ou_404(identifiant: int) -> DeriveView:
    with database_manager.read_connection() as connexion:
        ligne = connexion.execute(
            SELECTION + " WHERE d.id = ?", (identifiant,)
        ).fetchone()
    if ligne is None:
        raise _introuvable(identifiant)
    return _vers_vue(ligne, date.today())


# ─── Agregation pour l'EP11 ──────────────────────────────────────────────────


@dataclass
class AgregatEp11:
    """Ce que le registre apporte a une ligne de l'EP11.

    La ponderation et les colonnes calculees n'y figurent pas : elles sont
    l'affaire de l'export, qui les lit sur le formulaire.
    """

    nombre_contrats: int = 0
    cout_remplacement: float = 0.0
    montant_notionnel: float = 0.0
    #: Part de chaque categorie de contrepartie dans le cout de remplacement et
    #: dans le notionnel. La ventilation de l'EP11 porte sur l'EXPOSITION, que
    #: l'export calcule ; il la repartit au prorata de ces deux composantes,
    #: seule facon de ventiler un montant pondere apres coup.
    cout_par_categorie: dict[str, float] = field(default_factory=dict)
    notionnel_par_categorie: dict[str, float] = field(default_factory=dict)


def agreger_pour_ep11(
    reference: date, derives: list[DeriveView] | None = None
) -> dict[tuple[str, str], AgregatEp11]:
    """Range les contrats dans les quinze cases (nature x tranche) de l'EP11.

    Les montants sont ramenes au franc CFA : un swap libelle en euro se declare
    dans la devise du formulaire, comme le reste de l'export.
    """

    derives = lister_derives(reference) if derives is None else derives
    agregats: dict[tuple[str, str], AgregatEp11] = defaultdict(AgregatEp11)

    for contrat in derives:
        echeance = (
            contrat.date_echeance
            if isinstance(contrat.date_echeance, date)
            else _date(contrat.date_echeance)
        )
        if echeance is None:
            continue
        cle = (contrat.nature, tranche_de_duree(echeance, reference))
        agregat = agregats[cle]

        def en_xof(montant: float) -> float:
            return convert_currency_amount(
                montant,
                from_currency=contrat.devise,
                to_currency=DEVISE_DECLARATION,
            )

        cout = en_xof(contrat.cout_remplacement)
        notionnel = en_xof(contrat.montant_notionnel)
        categorie = contrat.categorie_contrepartie

        agregat.nombre_contrats += 1
        agregat.cout_remplacement += cout
        agregat.montant_notionnel += notionnel
        agregat.cout_par_categorie[categorie] = (
            agregat.cout_par_categorie.get(categorie, 0.0) + cout
        )
        agregat.notionnel_par_categorie[categorie] = (
            agregat.notionnel_par_categorie.get(categorie, 0.0) + notionnel
        )

    return dict(agregats)


def libelle_ligne(nature: str, tranche: str) -> str:
    """Intitule d'une ligne de l'EP11, comme le formulaire l'imprime."""

    libelle_tranche = next(
        (libelle for cle, libelle, _ in TRANCHES_DUREE if cle == tranche), tranche
    )
    return f"{LIBELLES_NATURES.get(nature, nature)} — {libelle_tranche}"
