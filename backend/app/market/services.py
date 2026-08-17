"""Resolution du capital reglementaire risque de marche pour le Dashboard.

Le module Risque de Marche (VaR, taux, actions, change) calcule et persiste
son propre resultat (`MARKET_CAPITAL_REQUIREMENT_KEY`). Ce module fournit un
point d'acces unique pour les consommateurs (dashboard, RWA credit) qui
retombent sur l'ancien stub `risque_marche` (position nette de change
simplifiee) tant que rien n'a encore ete calcule/enregistre.
"""

from __future__ import annotations

import json
from typing import Any

from database.connection import database_manager

from app.core.bceao_calculations import calculate_risque_marche

MARKET_CAPITAL_REQUIREMENT_KEY = "market_capital_requirement_v1"

# Les quatre natures de risque de marche distinguees par le dispositif
# prudentiel, et par le FODEP : l'EP08 leur reserve une ligne chacune (RM044,
# RM057, RM067, RM123) et les etats EP25 a EP28 les detaillent. Le module
# Risque de Marche les calcule separement avant d'en additionner les
# exigences : les transmettre evite d'avoir a les recalculer ici.
NATURES_RISQUE_MARCHE: tuple[str, ...] = ("taux", "actions", "change", "produits_de_base")


def _ventilation(payload: dict[str, Any]) -> dict[str, float]:
    """Extrait les exigences par nature, ou un dictionnaire vide si absentes.

    Les enregistrements anterieurs a la transmission du detail ne portent que
    les deux totaux : leur absence n'est pas une erreur, elle signifie que la
    ventilation n'est pas connue et que les lignes de detail resteront a zero.
    """

    detail = payload.get("ventilation")
    if not isinstance(detail, dict):
        return {}
    try:
        exigences = {nature: float(detail[nature]) for nature in NATURES_RISQUE_MARCHE}
    except (KeyError, TypeError, ValueError):
        return {}
    return exigences if any(exigences.values()) else {}


def resolve_market_capital(rm_data: dict[str, Any]) -> dict[str, Any]:
    """Retourne l'exigence de fonds propres et le RWA du risque de marche.

    Priorise le resultat persiste par le module Risque de Marche ; retombe
    sur `calculate_risque_marche` (stub `position_nette_change`) si rien n'a
    encore ete enregistre.

    Quand le module a transmis le detail par nature, il est repercute sous la
    cle `ventilation`, en exigence de fonds propres. Les consommateurs qui
    n'en ont pas besoin peuvent l'ignorer ; le FODEP s'en sert pour renseigner
    les lignes de detail de l'EP08.
    """

    with database_manager.read_connection() as connection:
        row = connection.execute(
            "SELECT valeur FROM metadonnees_app WHERE cle = ?",
            (MARKET_CAPITAL_REQUIREMENT_KEY,),
        ).fetchone()

    if row is not None and str(row["valeur"] or "").strip():
        try:
            payload = json.loads(str(row["valeur"]))
            resultat = {
                "exigence_fonds_propres": round(float(payload["capital_requis"]), 2),
                "rwa_marche": round(float(payload["rwa_marche"]), 2),
            }
        except (json.JSONDecodeError, KeyError, TypeError, ValueError):
            pass
        else:
            ventilation = _ventilation(payload)
            if ventilation:
                resultat["ventilation"] = ventilation
            positions = payload.get("positions")
            if isinstance(positions, dict) and positions:
                resultat["positions"] = positions
            return resultat

    return calculate_risque_marche(rm_data)
