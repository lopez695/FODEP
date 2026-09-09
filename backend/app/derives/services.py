"""Registre des instruments derives, et son agregation pour l'EP11.

Ce module tient les contrats et les range dans les quinze lignes de l'etat. Il
ne connait pas le formulaire : les ponderations que la BCEAO imprime dans la
colonne (c) sont relues dans le modele par l'export, qui seul a besoin de les
appliquer. Les coder ici en ferait une seconde source, et une nouvelle version
du formulaire les ferait diverger.
"""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field
from datetime import date, datetime, timezone

from fastapi import HTTPException, status

from app.core.calculations import convert_currency_amount
from app.derives.models import (
    DeriveCreate,
    DeriveUpdate,
    DeriveView,
    LIBELLES_NATURES,
    TRANCHES_DUREE,
    tranche_de_duree,
)
from database.connection import database_manager

DEVISE_DECLARATION = "XOF"

CHAMPS = (
    "id, contrepartie, categorie_contrepartie, nature, type_contrat, devise, "
    "montant_notionnel, cout_remplacement, date_conclusion, date_echeance, "
    "commentaire, cree_le, modifie_le"
)


def _horodatage() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _vers_vue(ligne, reference: date) -> DeriveView:
    donnees = dict(ligne)
    echeance = _date(donnees.get("date_echeance"))
    return DeriveView(
        **donnees,
        tranche=tranche_de_duree(echeance, reference) if echeance else "moins_1_an",
    )


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


def lister_derives(reference: date | None = None) -> list[DeriveView]:
    """Les contrats du registre, du plus proche echeance au plus lointain.

    `reference` est la date a laquelle se lit la duree residuelle : celle de
    l'arrete quand l'export appelle, celle du jour quand c'est l'ecran.
    """

    reference = reference or date.today()
    with database_manager.read_connection() as connexion:
        lignes = connexion.execute(
            f"SELECT {CHAMPS} FROM derives ORDER BY nature, date_echeance, contrepartie"
        ).fetchall()
    return [_vers_vue(ligne, reference) for ligne in lignes]


def creer_derive(payload: DeriveCreate) -> DeriveView:
    horodatage = _horodatage()
    with database_manager.transaction() as connexion:
        curseur = connexion.execute(
            """
            INSERT INTO derives(
                contrepartie, categorie_contrepartie, nature, type_contrat,
                devise, montant_notionnel, cout_remplacement, date_conclusion,
                date_echeance, commentaire, cree_le, modifie_le
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                payload.contrepartie.strip(),
                payload.categorie_contrepartie,
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
    if not champs:
        return _lire_ou_404(identifiant)

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
            f"SELECT {CHAMPS} FROM derives WHERE id = ?", (identifiant,)
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
