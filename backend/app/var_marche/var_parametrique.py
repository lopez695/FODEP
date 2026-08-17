"""Moteur de calcul de la VaR paramétrique (variance-covariance).

Hypothèse : les P&L suivent une loi normale. Entrée : série des pertes
(convention perte positive), déjà mise à l'échelle de l'horizon par la
couche de données ; mu et sigma sont donc estimés directement sur cette
série, sans nouvelle multiplication par racine(horizon).
"""

from __future__ import annotations

import math

import numpy as np

from app.var_marche.var_historique import construire_histogramme

# Quantiles de la loi normale standard imposés par la spécification.
Z_ALPHA = {0.95: 1.6449, 0.975: 1.9600, 0.99: 2.3263}

# Horizons de la carte multi-horizon réglementaire (1 j, 3 j, 10 j, 1 mois).
HORIZONS_MULTI_JOURS = (1, 3, 10, 21)

_NOMBRE_POINTS_COURBE = 100
_NOMBRE_CLASSES = 40


def densite_normale(x: float) -> float:
    """Densité de la loi normale standard."""

    return math.exp(-0.5 * x * x) / math.sqrt(2.0 * math.pi)


def var_depuis_moments(mu: float, sigma: float, z_alpha: float) -> float:
    """VaR = -(mu - z_alpha x sigma), mu en convention gain positif."""

    return -(mu - z_alpha * sigma)


def es_depuis_moments(mu: float, sigma: float, z_alpha: float, alpha: float) -> float:
    """ES = sigma x phi(z_alpha) / (1 - alpha) - mu, mu en convention gain."""

    return sigma * densite_normale(z_alpha) / (1.0 - alpha) - mu


def calculer(
    pertes: np.ndarray,
    niveau_confiance: float,
    type_portefeuille: str = "actions",
    valeur_portefeuille: float | None = None,
    duration_modifiee: float | None = None,
    horizon_jours: int = 1,
    volatilite_reglementaire: float = 0.03,
    beta: float = 1.0,
) -> dict:
    pertes = np.asarray(pertes, dtype=float)
    nombre_observations = len(pertes)
    z_alpha = Z_ALPHA[round(niveau_confiance, 4)]

    # Calcul des moments empiriques de la série des pertes pour le reporting/histogramme
    if nombre_observations > 0:
        mu_pertes = float(pertes.mean())
        sigma_empirique = float(pertes.std(ddof=1) if nombre_observations > 1 else 0.0)
    else:
        mu_pertes = 0.0
        sigma_empirique = 0.0
    
    # Sigma réglementaire annualisé (Delta-Normal) : vol x sensibilité x PV.
    # Appliqué UNIQUEMENT sans historique (nombre_observations == 0) ; dès
    # qu'un historique est importé, les trois méthodes utilisent la volatilité
    # empirique de la série. Obligations : sensibilité = duration modifiée ;
    # actions : sensibilité = |bêta|.
    sigma_annuel_reglementaire = None
    if (
        type_portefeuille == "obligations"
        and valeur_portefeuille is not None
        and duration_modifiee is not None
        and nombre_observations == 0
    ):
        sigma_annuel_reglementaire = (
            volatilite_reglementaire * duration_modifiee * valeur_portefeuille
        )
    elif type_portefeuille == "actions" and valeur_portefeuille and nombre_observations == 0:
        # Sans historique de cours, repli Delta-Normal réglementaire :
        # la sensibilité au marché est |bêta| (l'amplitude de la VaR ne dépend
        # pas du signe du bêta ; un bêta négatif expose autant au marché).
        sigma_annuel_reglementaire = (
            volatilite_reglementaire * abs(beta) * valeur_portefeuille
        )

    if sigma_annuel_reglementaire is not None:
        # Étalonnage réglementaire UEMOA/CEMAC : volatilité de 3 % / an
        # La VaR est Z_99 * sigma * (Dmod) * PV * sqrt(T/252)
        # On en déduit le sigma "réglementaire" à l'horizon T
        sigma = sigma_annuel_reglementaire * math.sqrt(horizon_jours / 252.0)
        mu = 0.0  # Hypothèse d'espérance nulle en VaR réglementaire
        mode_calcul = "reglementaire"
    else:
        # mu est rapporté en convention gain positif (P&L comptable) ; la série
        # reçue est en convention perte positive, d'où le changement de signe.
        sigma = sigma_empirique
        mu = -mu_pertes
        mode_calcul = "empirique"

    var = var_depuis_moments(mu, sigma, z_alpha)
    expected_shortfall = es_depuis_moments(mu, sigma, z_alpha, niveau_confiance)
    p95 = var_depuis_moments(mu, sigma, Z_ALPHA[0.95])
    p975 = var_depuis_moments(mu, sigma, Z_ALPHA[0.975])
    p99 = var_depuis_moments(mu, sigma, Z_ALPHA[0.99])

    # Carte multi-horizon réglementaire : VaR et ES à 1, 3, 10 et 21 jours
    # via la racine du temps, déclinées aux trois niveaux de confiance
    # (Z95, Z97.5, Z99), sans aucun calcul côté client. Les champs var /
    # expected_shortfall restent ceux du niveau demandé.
    var_multi_horizon = None
    if sigma_annuel_reglementaire is not None:
        var_multi_horizon = []
        for horizon in HORIZONS_MULTI_JOURS:
            sigma_horizon = sigma_annuel_reglementaire * math.sqrt(horizon / 252.0)
            var_multi_horizon.append(
                {
                    "horizon_jours": horizon,
                    "var": var_depuis_moments(0.0, sigma_horizon, z_alpha),
                    "expected_shortfall": es_depuis_moments(
                        0.0, sigma_horizon, z_alpha, niveau_confiance
                    ),
                    "par_niveau": [
                        {
                            "niveau_confiance": niveau,
                            "z_alpha": z_niveau,
                            "var": var_depuis_moments(0.0, sigma_horizon, z_niveau),
                            "expected_shortfall": es_depuis_moments(
                                0.0, sigma_horizon, z_niveau, niveau
                            ),
                        }
                        for niveau, z_niveau in sorted(Z_ALPHA.items())
                    ],
                }
            )
    
    if nombre_observations > 0:
        pire_perte = float(pertes.max())
        depassements = int((pertes > var).sum())
        taux_depassement_pct = depassements / nombre_observations * 100.0
        ecarts = pertes - mu_pertes
        sigma_population = float(pertes.std(ddof=0))
        histogramme = construire_histogramme(pertes, _NOMBRE_CLASSES)
    else:
        pire_perte = 0.0
        depassements = 0
        taux_depassement_pct = 0.0
        ecarts = np.array([])
        sigma_population = 0.0
        histogramme = []

    if sigma_population > 0:
        skewness = float((ecarts**3).mean() / sigma_population**3)
        kurtosis_exces = float((ecarts**4).mean() / sigma_population**4 - 3.0)
    else:
        skewness = 0.0
        kurtosis_exces = 0.0
    hypothese_normale_douteuse = kurtosis_exces > 1.0 or abs(skewness) > 0.5

    # Courbe de densité normale théorique sur l'axe des pertes, échantillonnée
    # entre mu - 4 sigma et mu + 4 sigma. Avec des observations, l'ordonnée
    # est exprimée en effectif théorique par classe (densité x nombre
    # d'observations x largeur de classe) pour une superposition directe sur
    # l'histogramme ; sans observation (mode réglementaire), en densité
    # relative base 100 (pic = 100) pour tracer la cloche théorique seule.
    # Dans les deux cas, aucun calcul côté client.
    largeur_classe = (
        (float(pertes.max()) - float(pertes.min())) / _NOMBRE_CLASSES
        if len(pertes) > 1
        else 1.0
    )
    courbe_normale = []
    if sigma > 0:
        abscisses = np.linspace(
            mu_pertes - 4.0 * sigma, mu_pertes + 4.0 * sigma, _NOMBRE_POINTS_COURBE
        )
        for x in abscisses:
            z = (x - mu_pertes) / sigma
            if nombre_observations > 0:
                densite = densite_normale(float(z)) / sigma
                ordonnee = densite * nombre_observations * largeur_classe
            else:
                ordonnee = 100.0 * densite_normale(float(z)) / densite_normale(0.0)
            courbe_normale.append({"x": float(x), "y": ordonnee})

    return {
        "var": var,
        "expected_shortfall": expected_shortfall,
        "mode_calcul": mode_calcul,
        "var_multi_horizon": var_multi_horizon,
        "pire_perte": pire_perte,
        "p95": p95,
        "p975": p975,
        "p99": p99,
        "taux_depassement_pct": taux_depassement_pct,
        "nombre_observations": nombre_observations,
        "mu": mu,
        "sigma": sigma,
        "z_alpha": z_alpha,
        "skewness": skewness,
        "kurtosis_exces": kurtosis_exces,
        "hypothese_normale_douteuse": hypothese_normale_douteuse,
        "courbe_normale": courbe_normale,
        "histogramme": histogramme,
    }
