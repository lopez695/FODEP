"""Endpoints REST du module Value at Risk (VaR).

Toutes les valeurs monétaires des réponses JSON sont exprimées en
milliards de FCFA (Md FCFA), nombres bruts avec point décimal ; le
formatage français est fait uniquement côté client.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, HTTPException, Query, status

from app.var_marche import (
    courbe_umoa,
    portefeuille_data,
    var_historique,
    var_montecarlo,
    var_parametrique,
)
from app.var_marche.portefeuille_data import DonneesAbsentesError, ErreurDonneesVar

logger = logging.getLogger(__name__)

# Prefixe SANS « /api », comme tous les autres routeurs. PrefixeApiMiddleware
# retire « /api » avant le routage : un routeur declare sur « /api/var »
# recevait donc « /var/... » et ne repondait jamais, ni sur « /api/var/... »
# (prefixe retire avant comparaison) ni sur « /var/... » (route inconnue).
router = APIRouter(prefix="/var", tags=["Value at Risk"])

_MILLIARD_FCFA = 1e9

_TYPES_PORTEFEUILLE = ("obligations", "actions")
_NIVEAUX_CONFIANCE = (0.95, 0.975, 0.99)
_HORIZONS_JOURS = (1, 3, 10, 21)
_FENETRES_JOURS = (250, 500, 1000)
_NB_SIMULATIONS = (1_000, 10_000, 50_000)

# Écart relatif entre méthodes au-delà duquel un avertissement de
# calibrage est journalisé (vérification de cohérence de la Partie 6).
_SEUIL_ALERTE_CALIBRAGE = 0.30


def _erreur_422(message: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail={"code": "VAR_PARAMETRE_INVALIDE", "message": message},
    )


def _valider_parametres(
    type_portefeuille: str,
    niveau_confiance: float,
    horizon_jours: int,
    fenetre_jours: int,
) -> None:
    if type_portefeuille not in _TYPES_PORTEFEUILLE:
        raise _erreur_422(
            f"Type de portefeuille invalide : '{type_portefeuille}'. "
            "Valeurs acceptées : obligations, actions."
        )
    if round(niveau_confiance, 4) not in _NIVEAUX_CONFIANCE:
        raise _erreur_422(
            f"Niveau de confiance invalide : {niveau_confiance}. "
            "Valeurs acceptées : 0.95, 0.975, 0.99."
        )
    if horizon_jours not in _HORIZONS_JOURS:
        raise _erreur_422(
            f"Horizon invalide : {horizon_jours}. "
            "Valeurs acceptées : 1, 3, 10, 21 jours."
        )
    if fenetre_jours not in _FENETRES_JOURS:
        raise _erreur_422(
            f"Fenêtre historique invalide : {fenetre_jours}. "
            "Valeurs acceptées : 250, 500, 1000 jours."
        )


def _serie_ou_422(
    type_portefeuille: str, fenetre_jours: int, horizon_jours: int
) -> portefeuille_data.SeriePnl:
    try:
        return portefeuille_data.get_serie_pnl(
            type_portefeuille, fenetre_jours, horizon_jours
        )
    except DonneesAbsentesError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "VAR_DONNEES_ABSENTES", "message": str(exc)},
        ) from exc
    except ErreurDonneesVar as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "VAR_DONNEES_INVALIDES", "message": str(exc)},
        ) from exc


def _en_milliards(serie_pnl: portefeuille_data.SeriePnl) -> dict[str, Any]:
    return {
        "valeur_portefeuille": serie_pnl.valeur_portefeuille / _MILLIARD_FCFA,
        "pertes": serie_pnl.pertes / _MILLIARD_FCFA,
        "pertes_quotidiennes": serie_pnl.pertes_quotidiennes / _MILLIARD_FCFA,
    }


def _reponse_commune(
    methode: str,
    parametres: dict[str, Any],
    serie_pnl: portefeuille_data.SeriePnl,
    resultat: dict[str, Any],
) -> dict[str, Any]:
    val_portefeuille = parametres.get("valeur_portefeuille")
    if val_portefeuille is None:
        val_portefeuille = serie_pnl.valeur_portefeuille / _MILLIARD_FCFA
        
    return {
        "methode": methode,
        "parametres": parametres,
        "source_donnees": serie_pnl.source_donnees,
        "valeur_portefeuille": val_portefeuille,
        # Duration modifiée calculée par le backend sur le portefeuille
        # (pondérée par l'exposition) : valeur de référence du curseur client.
        "duration_modifiee_portefeuille": serie_pnl.duration_modifiee,
        "unite": "Md FCFA",
        "avertissements": serie_pnl.avertissements,
        **resultat,
    }


def _verifier_coherence_methodes(
    pertes_md, niveau_confiance: float, contexte: str
) -> None:
    """Journalise un avertissement si VaR historique et paramétrique divergent."""
    if len(pertes_md) == 0:
        return
    var_hist = var_historique.calculer(pertes_md, niveau_confiance)["var"]
    var_param = var_parametrique.calculer(pertes_md, niveau_confiance)["var"]
    reference = max(abs(var_hist), abs(var_param))
    if reference <= 0:
        return
    ecart = abs(var_hist - var_param) / reference
    if ecart > _SEUIL_ALERTE_CALIBRAGE:
        logger.warning(
            "Avertissement de calibrage (%s) : écart de %.0f %% entre la VaR "
            "historique (%.2f Md) et la VaR paramétrique (%.2f Md).",
            contexte,
            ecart * 100,
            var_hist,
            var_param,
        )


@router.get("/historique")
def var_historique_endpoint(
    type_portefeuille: str = Query("obligations"),
    niveau_confiance: float = Query(0.99),
    horizon_jours: int = Query(1),
    fenetre_jours: int = Query(500),
) -> dict[str, Any]:
    """VaR historique : quantile empirique de la série des pertes."""

    _valider_parametres(type_portefeuille, niveau_confiance, horizon_jours, fenetre_jours)
    serie_pnl = _serie_ou_422(type_portefeuille, fenetre_jours, horizon_jours)
    donnees = _en_milliards(serie_pnl)
    
    if len(donnees["pertes"]) == 0:
        raise _erreur_422(
            "La méthode de la VaR Historique nécessite obligatoirement l'importation "
            "d'un historique de prix dans le fichier Excel. Aucun historique trouvé."
        )
        
    resultat = var_historique.calculer(donnees["pertes"], niveau_confiance)
    _verifier_coherence_methodes(
        donnees["pertes"], niveau_confiance, f"historique {type_portefeuille}"
    )
    return _reponse_commune(
        "historique",
        {
            "type_portefeuille": type_portefeuille,
            "niveau_confiance": niveau_confiance,
            "horizon_jours": horizon_jours,
            "fenetre_jours": fenetre_jours,
        },
        serie_pnl,
        resultat,
    )


@router.get("/parametrique")
def var_parametrique_endpoint(
    type_portefeuille: str = Query("obligations"),
    niveau_confiance: float = Query(0.99),
    horizon_jours: int = Query(1),
    fenetre_jours: int = Query(500),
    volatilite: float = Query(0.03),
    duration_modifiee: float | None = Query(None),
    valeur_portefeuille: float | None = Query(None),
    beta: float = Query(1.0, ge=0.0),
) -> dict[str, Any]:
    """VaR paramétrique (variance-covariance, hypothèse normale)."""

    _valider_parametres(type_portefeuille, niveau_confiance, horizon_jours, fenetre_jours)
    serie_pnl = _serie_ou_422(type_portefeuille, fenetre_jours, horizon_jours)
    donnees = _en_milliards(serie_pnl)
    resultat = var_parametrique.calculer(
        donnees["pertes"], 
        niveau_confiance,
        type_portefeuille=type_portefeuille,
        valeur_portefeuille=valeur_portefeuille if valeur_portefeuille is not None else donnees.get("valeur_portefeuille"),
        duration_modifiee=duration_modifiee if duration_modifiee is not None else serie_pnl.duration_modifiee,
        horizon_jours=horizon_jours,
        volatilite_reglementaire=volatilite,
        beta=beta,
    )
    _verifier_coherence_methodes(
        donnees["pertes"], niveau_confiance, f"parametrique {type_portefeuille}"
    )
    return _reponse_commune(
        "parametrique",
        {
            "type_portefeuille": type_portefeuille,
            "niveau_confiance": niveau_confiance,
            "horizon_jours": horizon_jours,
            "fenetre_jours": fenetre_jours,
            "volatilite": volatilite,
            "duration_modifiee": duration_modifiee if duration_modifiee is not None else serie_pnl.duration_modifiee,
            "valeur_portefeuille": valeur_portefeuille,
            "beta": beta,
        },
        serie_pnl,
        resultat,
    )


@router.get("/montecarlo")
def var_montecarlo_endpoint(
    type_portefeuille: str = Query("obligations"),
    niveau_confiance: float = Query(0.99),
    horizon_jours: int = Query(1),
    fenetre_jours: int = Query(500),
    nb_simulations: int = Query(var_montecarlo.NB_SIMULATIONS_DEFAUT),
    graine: int = Query(var_montecarlo.GRAINE_DEFAUT),
    volatilite: float = Query(0.03),
    duration_modifiee: float | None = Query(None),
    valeur_portefeuille: float | None = Query(None),
    beta: float = Query(1.0, ge=0.0),
) -> dict[str, Any]:
    """VaR Monte-Carlo : quantile empirique des pertes simulées."""

    _valider_parametres(type_portefeuille, niveau_confiance, horizon_jours, fenetre_jours)
    if nb_simulations not in _NB_SIMULATIONS:
        raise _erreur_422(
            f"Nombre de simulations invalide : {nb_simulations}. "
            "Valeurs acceptées : 1000, 10000, 50000."
        )
    serie_pnl = _serie_ou_422(type_portefeuille, fenetre_jours, horizon_jours)
    donnees = _en_milliards(serie_pnl)
    variations_taux = serie_pnl.variations_taux
    resultat = var_montecarlo.calculer(
        type_portefeuille=type_portefeuille,
        valeur_portefeuille=valeur_portefeuille
        if valeur_portefeuille is not None
        else donnees["valeur_portefeuille"],
        pertes_quotidiennes=donnees["pertes_quotidiennes"],
        niveau_confiance=niveau_confiance,
        horizon_jours=horizon_jours,
        nb_simulations=nb_simulations,
        graine=graine,
        duration_modifiee=duration_modifiee if duration_modifiee is not None else serie_pnl.duration_modifiee,
        variations_taux=variations_taux,
        volatilite_reglementaire=volatilite,
        beta=beta,
    )
    _verifier_coherence_methodes(
        donnees["pertes"], niveau_confiance, f"montecarlo {type_portefeuille}"
    )
    return _reponse_commune(
        "montecarlo",
        {
            "type_portefeuille": type_portefeuille,
            "niveau_confiance": niveau_confiance,
            "horizon_jours": horizon_jours,
            "fenetre_jours": fenetre_jours,
            "nb_simulations": nb_simulations,
            "graine": graine,
            "volatilite": volatilite,
            "duration_modifiee": duration_modifiee if duration_modifiee is not None else serie_pnl.duration_modifiee,
            "valeur_portefeuille": valeur_portefeuille,
            "beta": beta,
        },
        serie_pnl,
        resultat,
    )


@router.get("/courbe/pays")
def pays_courbe_disponibles() -> dict[str, Any]:
    """Liste des pays UEMOA dont la courbe de taux est actualisable en ligne."""

    return {"pays": list(courbe_umoa.PAYS_UEMOA), "source": "UMOA-Titres"}


def _ecrire_historique_taux(points: list[dict[str, Any]], jour: str) -> None:
    """ACCUMULE la courbe du jour dans historique_taux (CSV lu par la couche
    VaR + table SQLite de transparence), au lieu d'écraser l'existant.

    Chaque actualisation ajoute une date à l'historique (une réactualisation
    du même jour remplace uniquement les points de ce jour) : l'historique de
    courbes se construit donc au fil des actualisations, et la VaR historique
    se débloque automatiquement une fois la profondeur requise atteinte.
    L'ancien comportement (DROP TABLE + réécriture du CSV avec un seul jour)
    remettait la profondeur à 1 à chaque clic sur « Actualiser »."""

    import sqlite3

    racine = portefeuille_data.repertoire_data()
    racine.mkdir(parents=True, exist_ok=True)

    # Fusion avec l'historique CSV existant : conserve toutes les autres
    # dates, remplace les points du jour actualisé (idempotent).
    chemin_csv = racine / "historique_taux.csv"
    lignes_conservees: list[str] = []
    if chemin_csv.exists():
        for ligne in chemin_csv.read_text(encoding="utf-8-sig").splitlines():
            ligne = ligne.strip()
            if not ligne or ligne.lower().startswith("date;"):
                continue
            if not ligne.startswith(f"{jour};"):
                lignes_conservees.append(ligne)

    lignes_du_jour = [
        f"{jour};{point['maturite_annees']};{point['taux_pct']}" for point in points
    ]
    toutes = sorted(lignes_conservees + lignes_du_jour)
    chemin_csv.write_text(
        "date;maturite_annees;taux_pct\n" + "\n".join(toutes) + "\n",
        encoding="utf-8",
    )

    # Table SQLite miroir (transparence/inspection) : reconstruite depuis le
    # CSV complet — le CSV reste la source lue par portefeuille_data.
    chemin_db = racine / "rwa_data.db"
    with sqlite3.connect(chemin_db) as connexion:
        connexion.execute(
            "CREATE TABLE IF NOT EXISTS historique_taux "
            "(date TEXT, maturite_annees TEXT, taux_pct TEXT)"
        )
        connexion.execute("DELETE FROM historique_taux")
        connexion.executemany(
            "INSERT INTO historique_taux(date, maturite_annees, taux_pct) "
            "VALUES (?, ?, ?)",
            [tuple(ligne.split(";", 2)) for ligne in toutes],
        )


@router.post("/actualiser-courbe")
def actualiser_courbe(pays: str = Query("Côte d'Ivoire")) -> dict[str, Any]:
    """Récupère en ligne la courbe de taux UEMOA la plus récente pour le pays
    demandé (UMOA-Titres) et l'installe comme courbe active du calcul VaR."""

    try:
        courbe = courbe_umoa.recuperer_courbe(pays)
    except courbe_umoa.ErreurCourbeUmoa as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={"code": "VAR_COURBE_INDISPONIBLE", "message": str(exc)},
        ) from exc

    _ecrire_historique_taux(courbe["points"], courbe["date"])
    portefeuille_data.invalider_cache_series()

    return {
        "status": "ok",
        "pays": courbe["pays"],
        "date": courbe["date"],
        "nombre_points": len(courbe["points"]),
        "source": "UMOA-Titres",
        "source_url": courbe["source_url"],
        "points": courbe["points"],
    }
