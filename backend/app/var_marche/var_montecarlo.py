"""Moteur de calcul de la VaR Monte-Carlo.

Convention de signe : perte positive, gain négatif.

Calibrage :
- Obligations : si la duration modifiée du portefeuille et l'historique des
  variations de taux sont disponibles (valorisation par courbe), les chocs de
  taux sont tirés dans une loi normale calibrée sur ces variations et
  perte simulée = Duration modifiée x V x dTaux simulé (une hausse de taux
  produit une perte positive). Sinon, repli sur le calibrage des P&L
  historiques.
- Actions : rendements simulés en loi de Student calibrée sur l'historique
  (moyenne, écart-type, degrés de liberté estimés par la méthode des
  moments), repli en loi normale si les queues ne sont pas épaisses ;
  perte simulée = -V x rendement simulé x racine(horizon).
- Sans aucun historique (mode réglementaire) : chocs quotidiens tirés en loi
  normale N(0, volatilité réglementaire / racine(252)), sensibilité = duration
  modifiée pour les obligations, delta = 1 pour les actions.
"""

from __future__ import annotations

import math
import numpy as np

from app.var_marche.var_historique import construire_histogramme

# Quantiles pour les intervalles de confiance du bootstrap.
_NIVEAU_CONFIANCE_BORNE_INF = 0.025
_NIVEAU_CONFIANCE_BORNE_SUP = 0.975
_NB_REECHANTILLONNAGES_BOOTSTRAP = 200

# Cap du nombre de degrés de liberté de la loi de Student. Au-delà, la loi
# est considérée indiscernable d'une loi normale (kurtosis = 3.0).
_DDL_MAXIMUM = 30.0

NB_SIMULATIONS_DEFAUT = 10_000
GRAINE_DEFAUT = 42

_DDL_MINIMUM = 3.0


def _degres_liberte_student(rendements: np.ndarray) -> float:
    rendements_propres = rendements[~np.isnan(rendements)]
    if len(rendements_propres) < 4:
        return _DDL_MAXIMUM
    variance = float(np.var(rendements_propres, ddof=1))
    if variance == 0:
        return _DDL_MAXIMUM
    kurtosis_exces = float(np.mean((rendements_propres - np.mean(rendements_propres)) ** 4)) / (variance**2) - 3.0
    if kurtosis_exces <= 0.1:
        return _DDL_MAXIMUM
    ddl = 6.0 / kurtosis_exces + 4.0
    return min(ddl, _DDL_MAXIMUM)


def _simuler_pertes_obligations(
    generateur: np.random.Generator,
    nb_simulations: int,
    valeur_portefeuille: float,
    duration_modifiee: float,
    variations_taux: np.ndarray,
    horizon_jours: int,
    volatilite_reglementaire: float,
) -> np.ndarray:
    if len(variations_taux) == 0:
        moyenne = 0.0
        ecart_type = volatilite_reglementaire / math.sqrt(252.0)
    else:
        moyenne = float(variations_taux.mean())
        ecart_type = float(variations_taux.std(ddof=1))
        
    chocs_taux = generateur.normal(moyenne, ecart_type, nb_simulations)
    # Perte positive quand le taux monte : perte = DM x V x dTaux.
    pertes_quotidiennes = duration_modifiee * valeur_portefeuille * chocs_taux
    return pertes_quotidiennes * np.sqrt(horizon_jours)


def _simuler_pertes_par_calibrage_pnl(
    generateur: np.random.Generator,
    nb_simulations: int,
    pertes_quotidiennes: np.ndarray,
    horizon_jours: int,
) -> np.ndarray:
    moyenne = float(pertes_quotidiennes.mean())
    ecart_type = float(pertes_quotidiennes.std(ddof=1))
    tirages = generateur.normal(moyenne, ecart_type, nb_simulations)
    return tirages * np.sqrt(horizon_jours)


def _simuler_pertes_reglementaire(
    generateur: np.random.Generator,
    nb_simulations: int,
    valeur_portefeuille: float,
    horizon_jours: int,
    volatilite_reglementaire: float,
    sensibilite: float = 1.0,
) -> np.ndarray:
    """Simulation Delta-Normal réglementaire, sans historique.

    Chocs quotidiens N(0, vol_annuelle / racine(252)) ; perte simulée =
    sensibilité x V x choc x racine(horizon). La sensibilité vaut 1 pour les
    actions (delta) et la duration modifiée pour les obligations.
    """

    ecart_type = volatilite_reglementaire / math.sqrt(252.0)
    chocs = generateur.normal(0.0, ecart_type, nb_simulations)
    return sensibilite * valeur_portefeuille * chocs * np.sqrt(horizon_jours)


def _simuler_pertes_actions(
    generateur: np.random.Generator,
    nb_simulations: int,
    valeur_portefeuille: float,
    pertes_quotidiennes: np.ndarray,
    horizon_jours: int,
) -> tuple[np.ndarray, float]:
    # Rendements quotidiens en convention gain : r = -perte / V.
    rendements = -pertes_quotidiennes / valeur_portefeuille
    moyenne = float(rendements.mean())
    ecart_type = float(rendements.std(ddof=1))
    ddl = _degres_liberte_student(rendements)

    if ddl >= _DDL_MAXIMUM:
        rendements_simules = generateur.normal(moyenne, ecart_type, nb_simulations)
    else:
        tirages = generateur.standard_t(ddl, nb_simulations)
        facteur_normalisation = np.sqrt(ddl / (ddl - 2.0))
        rendements_simules = moyenne + ecart_type * tirages / facteur_normalisation

    pertes = -valeur_portefeuille * rendements_simules * np.sqrt(horizon_jours)
    return pertes, ddl


def _intervalle_confiance_var(
    generateur: np.random.Generator,
    pertes_simulees: np.ndarray,
    niveau_confiance: float,
) -> tuple[float, float]:
    """IC à 95 % de la VaR par bootstrap léger (200 rééchantillonnages)."""

    nombre = len(pertes_simulees)
    quantiles = np.empty(_NB_REECHANTILLONNAGES_BOOTSTRAP)
    for indice in range(_NB_REECHANTILLONNAGES_BOOTSTRAP):
        echantillon = pertes_simulees[
            generateur.integers(0, nombre, nombre)
        ]
        quantiles[indice] = np.quantile(echantillon, niveau_confiance)
    return float(np.quantile(quantiles, 0.025)), float(np.quantile(quantiles, 0.975))


def calculer(
    *,
    type_portefeuille: str,
    valeur_portefeuille: float,
    pertes_quotidiennes: np.ndarray,
    niveau_confiance: float,
    horizon_jours: int,
    nb_simulations: int = NB_SIMULATIONS_DEFAUT,
    graine: int = GRAINE_DEFAUT,
    duration_modifiee: float | None = None,
    variations_taux: np.ndarray | None = None,
    volatilite_reglementaire: float = 0.03,
    beta: float = 1.0,
) -> dict:
    pertes_quotidiennes = np.asarray(pertes_quotidiennes, dtype=float)
    generateur = np.random.default_rng(graine)
    modele = "normale calibrée sur les P&L"
    degres_liberte = None

    if type_portefeuille == "obligations":
        variations = (
            np.asarray(variations_taux, dtype=float)
            if variations_taux is not None
            else np.array([])
        )
        if duration_modifiee is not None and duration_modifiee > 0 and len(variations) >= 2:
            # 1. Courbe de taux disponible : chocs calibrés sur ses variations.
            pertes_simulees = _simuler_pertes_obligations(
                generateur,
                nb_simulations,
                valeur_portefeuille,
                duration_modifiee,
                variations,
                horizon_jours,
                volatilite_reglementaire,
            )
            modele = "chocs de taux normaux x duration modifiée"
        elif len(pertes_quotidiennes) >= 2:
            # 2. Historique de prix importé : calibrage sur les P&L observés.
            pertes_simulees = _simuler_pertes_par_calibrage_pnl(
                generateur, nb_simulations, pertes_quotidiennes, horizon_jours
            )
            modele = "P&L historiques simulés"
        elif duration_modifiee is not None and duration_modifiee > 0:
            # 3. Sans historique : chocs de taux réglementaires x duration.
            pertes_simulees = _simuler_pertes_obligations(
                generateur,
                nb_simulations,
                valeur_portefeuille,
                duration_modifiee,
                variations,
                horizon_jours,
                volatilite_reglementaire,
            )
            modele = "chocs de taux réglementaires x duration modifiée"
        else:
            # 4. Ni duration ni historique : repli Delta-Normal réglementaire.
            pertes_simulees = _simuler_pertes_reglementaire(
                generateur,
                nb_simulations,
                valeur_portefeuille,
                horizon_jours,
                volatilite_reglementaire,
            )
            modele = "chocs réglementaires normaux"
    elif len(pertes_quotidiennes) >= 2:
        pertes_simulees, degres_liberte = _simuler_pertes_actions(
            generateur,
            nb_simulations,
            valeur_portefeuille,
            pertes_quotidiennes,
            horizon_jours,
        )
        modele = (
            "rendements Student"
            if degres_liberte < _DDL_MAXIMUM
            else "rendements normaux"
        )
    else:
        # Actions sans historique : rendements N(0, sigma réglementaire),
        # sensibilité au marché = |bêta| (indépendant du signe du bêta).
        pertes_simulees = _simuler_pertes_reglementaire(
            generateur,
            nb_simulations,
            valeur_portefeuille,
            horizon_jours,
            volatilite_reglementaire,
            sensibilite=abs(beta),
        )
        modele = "rendements normaux réglementaires x bêta"

    var = float(np.quantile(pertes_simulees, niveau_confiance))
    pertes_extremes = pertes_simulees[pertes_simulees >= var]
    expected_shortfall = (
        float(pertes_extremes.mean()) if len(pertes_extremes) else var
    )
    pire_perte = float(pertes_simulees.max())
    p95 = float(np.quantile(pertes_simulees, 0.95))
    p975 = float(np.quantile(pertes_simulees, 0.975))
    p99 = float(np.quantile(pertes_simulees, 0.99))
    depassements = int((pertes_simulees > var).sum())
    taux_depassement_pct = depassements / nb_simulations * 100.0

    borne_basse, borne_haute = _intervalle_confiance_var(
        generateur, pertes_simulees, niveau_confiance
    )

    return {
        "var": var,
        "expected_shortfall": expected_shortfall,
        "pire_perte": pire_perte,
        "p95": p95,
        "p975": p975,
        "p99": p99,
        "taux_depassement_pct": taux_depassement_pct,
        "nombre_observations": nb_simulations,
        "nb_simulations": nb_simulations,
        "graine": graine,
        "modele_simulation": modele,
        "degres_liberte": degres_liberte,
        "ic_var_95": {"borne_basse": borne_basse, "borne_haute": borne_haute},
        "histogramme": construire_histogramme(pertes_simulees),
    }
