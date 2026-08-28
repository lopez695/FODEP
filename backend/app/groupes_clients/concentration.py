"""Concentration des risques par groupe de clients lies.

Un groupe de clients lies existe pour une raison : additionner les risques
portes sur des contreparties qu'un meme controle ou une meme dependance
economique fait tomber ensemble. Cet ecran repond donc a deux questions —
quel groupe pese le plus, et au sein d'un groupe, qui pese le plus.

Les montants sont ceux que le FODEP declare aux etats EP29 a EP32 : exposition
de bilan et engagements hors bilan apres facteur de conversion, convertis en
francs. Deux ecrans qui montreraient des chiffres differents pour la meme
notion ne seraient credibles ni l'un ni l'autre.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from app.core.bceao_calculations import calculate_fonds_propres
from app.core.calculations import convert_currency_amount
from database.connection import database_manager
from database.repositories.exposure_repository import exposure_repository
from app.core.fonds_propres import REQUETE_FONDS_PROPRES_COURANTS

DEVISE_DECLARATION = "XOF"

# Seuil au-dela duquel un risque est un « grand risque » a declarer, exprime
# en part des fonds propres de base T1 (dispositif prudentiel, division des
# risques). C'est le meme seuil que celui de l'EP29.
SEUIL_GRAND_RISQUE = 0.25


@dataclass
class MembreConcentration:
    nom: str
    exposition: float
    part_du_groupe: float


@dataclass
class GroupeConcentration:
    id: int
    nom: str
    numero_centrale_risques: str | None
    exposition_totale: float
    part_fonds_propres: float
    depasse_le_seuil: bool
    part_du_plus_gros_membre: float
    herfindahl: float
    membres: list[MembreConcentration] = field(default_factory=list)


def _flottant(valeur: Any) -> float:
    try:
        return float(valeur or 0.0)
    except (TypeError, ValueError):
        return 0.0


def _expositions_par_contrepartie() -> dict[str, float]:
    """Exposition totale portee sur chaque contrepartie, en francs.

    Bilan et hors bilan apres facteur de conversion, comme les etats de la
    division des risques les additionnent.
    """

    totaux: dict[str, float] = {}
    for exposition in exposure_repository.list_exposures():
        nom = str(exposition.get("counterparty_name") or "").strip()
        if not nom:
            continue
        devise = str(exposition.get("currency") or DEVISE_DECLARATION)
        montant = _flottant(exposition.get("ead_bilan_amount")) + _flottant(
            exposition.get("ead_hb_ccf_amount")
        )
        if not montant:
            continue
        totaux[nom] = totaux.get(nom, 0.0) + convert_currency_amount(
            montant, from_currency=devise, to_currency=DEVISE_DECLARATION
        )
    return totaux


def _fonds_propres_t1() -> float:
    with database_manager.read_connection() as connexion:
        ligne = connexion.execute(
            REQUETE_FONDS_PROPRES_COURANTS
        ).fetchone()
    if ligne is None:
        return 0.0
    return _flottant(calculate_fonds_propres(dict(ligne)).get("t1"))


def calculer_concentration() -> dict[str, Any]:
    """Concentration de chaque groupe, du plus lourd au plus leger."""

    expositions = _expositions_par_contrepartie()
    fonds_propres = _fonds_propres_t1()

    with database_manager.read_connection() as connexion:
        lignes = connexion.execute(
            """
            SELECT g.id, g.nom, g.numero_centrale_risques, c.nom AS membre
            FROM groupes_clients g
            LEFT JOIN contreparties c ON c.groupe_id = g.id
            ORDER BY g.nom, c.nom
            """
        ).fetchall()

    par_groupe: dict[int, dict[str, Any]] = {}
    for ligne in lignes:
        groupe = par_groupe.setdefault(
            int(ligne["id"]),
            {
                "nom": str(ligne["nom"]),
                "numero": ligne["numero_centrale_risques"],
                "membres": [],
            },
        )
        if ligne["membre"]:
            groupe["membres"].append(str(ligne["membre"]))

    resultats: list[GroupeConcentration] = []
    for identifiant, donnees in par_groupe.items():
        montants = [
            MembreConcentration(
                nom=membre,
                exposition=expositions.get(membre, 0.0),
                part_du_groupe=0.0,
            )
            for membre in donnees["membres"]
        ]
        total = sum(membre.exposition for membre in montants)
        for membre in montants:
            membre.part_du_groupe = membre.exposition / total if total > 0 else 0.0
        montants.sort(key=lambda membre: membre.exposition, reverse=True)

        # Indice de Herfindahl : somme des carres des parts. Il vaut 1 quand un
        # seul membre porte tout le groupe, et tend vers 1/n quand le risque
        # est egalement reparti. C'est la mesure de concentration usuelle,
        # moins trompeuse que la seule part du plus gros.
        herfindahl = sum(membre.part_du_groupe**2 for membre in montants)

        resultats.append(
            GroupeConcentration(
                id=identifiant,
                nom=donnees["nom"],
                numero_centrale_risques=donnees["numero"],
                exposition_totale=total,
                part_fonds_propres=total / fonds_propres if fonds_propres > 0 else 0.0,
                depasse_le_seuil=(
                    fonds_propres > 0 and total / fonds_propres > SEUIL_GRAND_RISQUE
                ),
                part_du_plus_gros_membre=montants[0].part_du_groupe if montants else 0.0,
                herfindahl=herfindahl,
                membres=montants,
            )
        )

    resultats.sort(key=lambda groupe: groupe.exposition_totale, reverse=True)

    return {
        "fonds_propres_t1": fonds_propres,
        "seuil_grand_risque": SEUIL_GRAND_RISQUE,
        "exposition_portefeuille": sum(expositions.values()),
        "groupes": [
            {
                "id": groupe.id,
                "nom": groupe.nom,
                "numero_centrale_risques": groupe.numero_centrale_risques,
                "exposition_totale": round(groupe.exposition_totale, 2),
                "part_fonds_propres": round(groupe.part_fonds_propres, 4),
                "depasse_le_seuil": groupe.depasse_le_seuil,
                "part_du_plus_gros_membre": round(groupe.part_du_plus_gros_membre, 4),
                "herfindahl": round(groupe.herfindahl, 4),
                "membres": [
                    {
                        "nom": membre.nom,
                        "exposition": round(membre.exposition, 2),
                        "part_du_groupe": round(membre.part_du_groupe, 4),
                    }
                    for membre in groupe.membres
                ],
            }
            for groupe in resultats
        ],
    }
