"""Fonctions de calcul partagees par les modules metier."""

from __future__ import annotations

import math
from collections.abc import Iterable, Mapping

from app.core.config import settings

# ============================================================================
# CONSTANTES REGLEMENTAIRES UMOA / BALE III
# ============================================================================

# Ratios minimaux réglementaires UMOA (Dispositif prudentiel, §91)
MIN_CET1_RATIO = 0.05  # 5% - fonds propres de base durs (CET1)
MIN_TIER1_RATIO = 0.06  # 6% - fonds propres de base (T1)
MIN_SOLVENCY_RATIO = 0.09  # 9% - fonds propres effectifs (FPE), SANS coussin
MIN_LEVERAGE_RATIO = 0.03  # 3% - Ratio de levier

# Coussin de conservation (§92) : 2,5 % des RWA en CET1, au-delà des minima.
CONSERVATION_BUFFER = 0.025
# Exigence globale de solvabilité, coussin de conservation inclus : 11,5 %.
GLOBAL_SOLVENCY_REQUIREMENT = MIN_SOLVENCY_RATIO + CONSERVATION_BUFFER

# Ratio de capital minimum réglementaire UMOA par défaut (9 %, exigence
# minimale de fonds propres §91c, sans coussin). Paramétrable via
# settings.capital_ratio. L'exigence globale avec coussin de conservation
# (2,5 %) est de 11,5 % — GLOBAL_SOLVENCY_REQUIREMENT.
DEFAULT_CAPITAL_RATIO = settings.capital_ratio

# Seuils de concentration (HHI - Herfindahl-Hirschman Index)
HHI_LOW_CONCENTRATION = 0.15  # Concentration faible
HHI_MODERATE_CONCENTRATION = 0.25  # Concentration modérée
# Au-dessus de 0.25 = concentration élevée

# Mapping PD (Probability of Default) par notation externe
# Source: Tables de correspondance Bâle II/III
PD_BY_RATING = {
    "AAA": 0.0003,  # 0.03%
    "AA+": 0.0004,
    "AA": 0.0005,  # 0.05%
    "AA-": 0.0006,
    "A+": 0.0008,
    "A": 0.0010,  # 0.10%
    "A-": 0.0012,
    "BBB+": 0.0020,
    "BBB": 0.0030,  # 0.30%
    "BBB-": 0.0050,
    "BB+": 0.0100,  # 1.00%
    "BB": 0.0150,
    "BB-": 0.0200,
    "B+": 0.0300,
    "B": 0.0500,  # 5.00%
    "B-": 0.0800,
    "CCC+": 0.1500,
    "CCC": 0.2000,  # 20.00%
    "CCC-": 0.2500,
    "CC": 0.3500,
    "C": 0.5000,
    "D": 1.0000,  # 100% - défaut
}

# LGD standard (Loss Given Default) Bâle
LGD_SENIOR_SECURED = 0.40  # 40% - créances garanties senior
LGD_SENIOR_UNSECURED = 0.45  # 45% - créances non garanties senior
LGD_SUBORDINATED = 0.75  # 75% - créances subordonnées

# Z-scores pour calcul VaR (distribution normale)
VAR_Z_SCORES = {
    0.90: 1.282,  # 90% de confiance
    0.95: 1.645,  # 95% de confiance
    0.99: 2.326,  # 99% de confiance
    0.999: 3.090,  # 99.9% de confiance
}


_CURRENCY_RATES_IN_XAF = {
    "XOF": 1.0,
    "EUR": 655.957,
    "USD": 600.0,
}


def _normalize_currency_code(currency: str) -> str:
    normalized = (currency or "XOF").strip().upper()
    if normalized in {"XAF", "FCFA"}:
        return "XOF"
    return normalized or "XOF"


# Libelles des echelons de notation du dispositif prudentiel. Les cles
# ("AAA/AA", "BB/B"...) sont internes au moteur et servent d'index dans les
# grilles de ponderation : elles n'ont jamais vocation a etre lues par un
# utilisateur, qui attend l'echelon reglementaire complet.
PRUDENTIAL_RATING_LABELS: dict[str, str] = {
    "AAA/AA": "AAA à AA-",
    "A": "A+ à A-",
    "BBB": "BBB+ à BBB-",
    "BB/B": "BB+ à B-",
    "< B-": "Inférieur à B-",
    "Non noté": "Non noté",
}

# Chemin inverse : un libelle d'echelon deja affiche doit retrouver son bucket.
_RATING_LABEL_TO_BUCKET: dict[str, str] = {
    label.upper(): bucket for bucket, label in PRUDENTIAL_RATING_LABELS.items()
}


def bucketize_rating(rating: str) -> str:
    """Mappe une notation vers un bucket prudentiel simple.

    Entree:
        rating: notation libre recue dans les donnees, ou libelle d'echelon.
    Sortie:
        Le bucket de notation exploitable par les referentiels.
    """

    # La notation libre est normalisee avant d'etre comparee aux buckets internes.
    normalized = rating.strip().upper()
    if normalized in _RATING_LABEL_TO_BUCKET:
        return _RATING_LABEL_TO_BUCKET[normalized]
    if normalized == "AAA/AA":
        return "AAA/AA"
    if normalized == "BB/B":
        return "BB/B"
    if normalized in {"AAA", "AA+", "AA", "AA-"}:
        return "AAA/AA"
    if normalized in {"A+", "A", "A-"}:
        return "A"
    if normalized in {"BBB+", "BBB", "BBB-"}:
        return "BBB"
    if normalized in {"BB+", "BB", "BB-", "B+", "B", "B-"}:
        return "BB/B"
    if normalized == "< B-":
        return "< B-"
    return "Non noté"


def prudential_rating_label(rating: str) -> str:
    """Libelle d'echelon a afficher pour une notation quelconque."""

    bucket = bucketize_rating(rating)
    return PRUDENTIAL_RATING_LABELS.get(bucket, bucket)


def calculate_ead(nominal_amount: float, ccf: float = 1.0) -> float:
    """Calcule l'exposition au defaut a partir du nominal.

    Entrees:
        nominal_amount: montant brut ou nominal.
        ccf: facteur de conversion du credit.
    Sortie:
        Le montant EAD.
    """

    return round(nominal_amount * ccf, 2)


def calculate_rwa(ead: float, risk_weight: float) -> float:
    """Calcule le RWA a partir de l'EAD et de la ponderation.

    Entrees:
        ead: exposition au defaut.
        risk_weight: ponderation prudentielle.
    Sortie:
        Le RWA.
    """

    return round(ead * risk_weight, 2)


def calculate_capital(rwa: float, capital_ratio: float = settings.capital_ratio) -> float:
    """Calcule le capital reglementaire minimum.

    Entrees:
        rwa: actifs ponderes par les risques.
        capital_ratio: ratio reglementaire cible.
    Sortie:
        Le capital minimum.
    """

    return round(rwa * capital_ratio, 2)


def convert_currency_amount(
    amount: float,
    *,
    from_currency: str,
    to_currency: str = "XOF",
) -> float:
    """Convertit un montant entre devises avec le barème partagé frontend/backend."""

    normalized_from = _normalize_currency_code(from_currency)
    normalized_to = _normalize_currency_code(to_currency)
    from_rate = _CURRENCY_RATES_IN_XAF.get(normalized_from, 1.0)
    to_rate = _CURRENCY_RATES_IN_XAF.get(normalized_to, 1.0)
    return (amount * from_rate) / to_rate


def safe_ratio(numerator: float, denominator: float) -> float:
    """Retourne un ratio simple en evitant une division par zero.

    Entrees:
        numerator: valeur au numerateur.
        denominator: valeur au denominateur.
    Sortie:
        Le ratio calcule ou 0 si le denominateur est nul.
    """

    if denominator == 0:
        return 0.0
    # Certaines categories peuvent representer une part tres faible du total.
    # On garde plus de precision pour eviter de les ecraser a zero dans les graphiques.
    return round(numerator / denominator, 8)


def aggregate_portfolio(items: Iterable[Mapping[str, float]]) -> dict[str, float]:
    """Agrege un portefeuille de lignes de calcul.

    Entree:
        items: lignes contenant au moins gross_amount, ead, rwa et capital.
    Sortie:
        Un dictionnaire de totaux de portefeuille.
    """

    total_gross = 0.0
    total_ead = 0.0
    total_rwa = 0.0
    total_capital = 0.0

    for item in items:
        # Chaque ligne contribue aux quatre agregats standards du portefeuille.
        total_gross += float(item.get("gross_amount", 0.0))
        total_ead += float(item.get("ead", 0.0))
        total_rwa += float(item.get("rwa", 0.0))
        total_capital += float(item.get("capital", 0.0))

    return {
        "gross_amount": round(total_gross, 2),
        "ead": round(total_ead, 2),
        "rwa": round(total_rwa, 2),
        "capital": round(total_capital, 2),
    }


# ============================================================================
# RATIOS PRUDENTIELS (BALE III / UMOA)
# ============================================================================


def calculate_cet1_ratio(cet1_capital: float, rwa: float) -> float:
    """Calcule le ratio CET1 (Common Equity Tier 1).

    Le CET1 représente les fonds propres de la plus haute qualité (capital social,
    réserves, résultats non distribués).

    Formule:
        CET1 Ratio = CET1 Capital / RWA

    Seuil réglementaire UMOA:
        Minimum 5% (MIN_CET1_RATIO)

    Entrees:
        cet1_capital: montant du capital CET1 (fonds propres de base durs).
        rwa: total des actifs pondérés par les risques.

    Sortie:
        Le ratio CET1 exprimé en décimal (ex: 0.09 pour 9%).
        Retourne 0.0 si RWA est nul.

    Exemple:
        >>> calculate_cet1_ratio(cet1_capital=500_000, rwa=10_000_000)
        0.05  # 5%
    """
    return safe_ratio(cet1_capital, rwa)


def calculate_tier1_ratio(tier1_capital: float, rwa: float) -> float:
    """Calcule le ratio Tier 1 (Fonds propres de catégorie 1).

    Le Tier 1 inclut le CET1 plus les instruments de capital hybrides
    perpétuels (ex: actions de préférence).

    Formule:
        Tier 1 Ratio = Tier 1 Capital / RWA

    Seuil réglementaire UMOA:
        Minimum 6% (MIN_TIER1_RATIO)

    Entrees:
        tier1_capital: montant total du capital Tier 1.
        rwa: total des actifs pondérés par les risques.

    Sortie:
        Le ratio Tier 1 exprimé en décimal.
        Retourne 0.0 si RWA est nul.

    Exemple:
        >>> calculate_tier1_ratio(tier1_capital=600_000, rwa=10_000_000)
        0.06  # 6%
    """
    return safe_ratio(tier1_capital, rwa)


def calculate_solvency_ratio(total_capital: float, rwa: float) -> float:
    """Calcule le ratio de solvabilité global (CAR - Capital Adequacy Ratio).

    Le ratio de solvabilité mesure la capacité de la banque à absorber les pertes.
    Il inclut Tier 1 + Tier 2 (dettes subordonnées, provisions).

    Formule:
        Solvency Ratio = Total Capital / RWA

    Seuil réglementaire UMOA:
        Minimum 9% (MIN_SOLVENCY_RATIO)

    Entrees:
        total_capital: montant total des fonds propres réglementaires (Tier 1 + Tier 2).
        rwa: total des actifs pondérés par les risques.

    Sortie:
        Le ratio de solvabilité exprimé en décimal.
        Retourne 0.0 si RWA est nul.

    Exemple:
        >>> calculate_solvency_ratio(total_capital=1_000_000, rwa=10_000_000)
        0.10  # 10%
    """
    return safe_ratio(total_capital, rwa)


def calculate_leverage_ratio(tier1_capital: float, total_exposures: float) -> float:
    """Calcule le ratio de levier (Leverage Ratio).

    Le ratio de levier est une mesure non pondérée par les risques qui limite
    l'effet de levier excessif. Il compare les fonds propres Tier 1 au total
    des exposures (bilan + hors-bilan).

    Formule:
        Leverage Ratio = Tier 1 Capital / Total Exposures

    Seuil réglementaire UMOA:
        Minimum 3% (MIN_LEVERAGE_RATIO)

    Entrees:
        tier1_capital: montant du capital Tier 1.
        total_exposures: somme de toutes les expositions au bilan et hors-bilan
                         (non pondérées par le risque).

    Sortie:
        Le ratio de levier exprimé en décimal.
        Retourne 0.0 si total_exposures est nul.

    Exemple:
        >>> calculate_leverage_ratio(tier1_capital=600_000, total_exposures=25_000_000)
        0.024  # 2.4% (sous le minimum de 3%)
    """
    return safe_ratio(tier1_capital, total_exposures)


# ============================================================================
# DENSITE RWA ET COUVERTURE CRM
# ============================================================================


def calculate_rwa_density(rwa: float, gross_exposure: float) -> float:
    """Calcule la densité RWA d'un portefeuille.

    La densité RWA mesure le risque moyen du portefeuille en rapportant
    les RWA à l'exposition brute totale. Une densité élevée indique un
    portefeuille plus risqué.

    Formule:
        Densité RWA = RWA / Exposition Brute

    Interpretation:
        - Proche de 0: portefeuille peu risqué (ex: souverains notés AAA)
        - 0.20-0.50: risque modéré (ex: corporate investment grade)
        - 1.00: risque standard (ex: corporate non noté, RW=100%)
        - >1.50: risque élevé (ex: actions, immobilier)

    Entrees:
        rwa: total des actifs pondérés par les risques.
        gross_exposure: exposition brute totale avant pondération.

    Sortie:
        La densité RWA (ratio sans unité).
        Retourne 0.0 si gross_exposure est nul.

    Exemple:
        >>> calculate_rwa_density(rwa=5_000_000, gross_exposure=20_000_000)
        0.25  # Densité de 25%
    """
    return safe_ratio(rwa, gross_exposure)


def calculate_crm_coverage_ratio(covered_ead: float, total_ead: float) -> float:
    """Calcule le ratio de couverture CRM (Credit Risk Mitigation).

    Ce ratio mesure la part de l'exposition couverte par des techniques
    d'atténuation du risque de crédit (garanties, dérivés de crédit,
    collatéral, netting).

    Formule:
        Coverage Ratio = EAD Couverte / EAD Totale

    Interpretation:
        - 0.00: aucune couverture
        - 0.50: 50% du portefeuille est couvert
        - 1.00: couverture complète

    Entrees:
        covered_ead: montant d'EAD bénéficiant d'une CRM.
        total_ead: exposition totale au défaut.

    Sortie:
        Le ratio de couverture CRM exprimé en décimal (0 à 1).
        Retourne 0.0 si total_ead est nul.

    Exemple:
        >>> calculate_crm_coverage_ratio(covered_ead=3_000_000, total_ead=10_000_000)
        0.3  # 30% de couverture
    """
    return safe_ratio(covered_ead, total_ead)


# ============================================================================
# VAR (VALUE AT RISK) SIMPLIFIE
# ============================================================================


def calculate_portfolio_var(
    exposures: list[float],
    volatilities: list[float] | None = None,
    confidence_level: float = 0.99,
    time_horizon_days: int = 10,
) -> float:
    """Calcule la VaR paramétrique simplifiée d'un portefeuille.

    La VaR (Value at Risk) estime la perte maximale potentielle sur un horizon
    temporel donné avec un niveau de confiance spécifié. Cette implémentation
    utilise une approche paramétrique simplifiée basée sur la volatilité.

    Formule simplifiée (sans corrélations):
        VaR = Valeur Portfolio × Volatilité × sqrt(Horizon) × Z-score

    Hypothèses:
        - Distribution normale des rendements
        - Volatilité historique représentative du futur
        - Pas de corrélations entre expositions (approximation conservative)
        - Volatilité par défaut de 2% par jour si non fournie

    Entrees:
        exposures: liste des valeurs d'exposition (montants nominaux ou EAD).
        volatilities: liste optionnelle des volatilités journalières par exposition
                      (ex: 0.02 pour 2%). Si None, utilise 2% par défaut.
        confidence_level: niveau de confiance (0.90, 0.95, 0.99, ou 0.999).
                          Par défaut 0.99 (99%).
        time_horizon_days: horizon temporel en jours. Par défaut 10 jours.

    Sortie:
        La VaR estimée (perte maximale potentielle au niveau de confiance donné).
        Retourne 0.0 si le portefeuille est vide.

    Exemple:
        >>> calculate_portfolio_var(
        ...     exposures=[1_000_000, 2_000_000, 500_000],
        ...     volatilities=[0.01, 0.02, 0.03],
        ...     confidence_level=0.99,
        ...     time_horizon_days=10
        ... )
        162857.14  # VaR à 99% sur 10 jours

    Note:
        Pour une VaR plus précise, il faudrait:
        - Intégrer les corrélations (matrice de covariance)
        - Utiliser des méthodes historiques ou Monte Carlo
        - Considérer les queues de distribution (fat tails)
    """
    if not exposures or len(exposures) == 0:
        return 0.0

    # Volatilité par défaut de 2% par jour (assumption prudente)
    DEFAULT_VOLATILITY = 0.02

    # Si volatilités non fournies, utiliser la volatilité par défaut
    if volatilities is None:
        volatilities = [DEFAULT_VOLATILITY] * len(exposures)

    # Validation des entrées
    if len(exposures) != len(volatilities):
        raise ValueError(
            f"Le nombre d'expositions ({len(exposures)}) doit correspondre "
            f"au nombre de volatilités ({len(volatilities)})"
        )

    # Récupération du Z-score pour le niveau de confiance
    z_score = VAR_Z_SCORES.get(confidence_level)
    if z_score is None:
        raise ValueError(
            f"Niveau de confiance {confidence_level} non supporté. "
            f"Valeurs acceptées: {list(VAR_Z_SCORES.keys())}"
        )

    # Facteur d'échelle temporel (racine carrée de l'horizon)
    time_factor = math.sqrt(time_horizon_days)

    # Calcul de la VaR pour chaque exposition (approche additive simplifiée)
    # Note: ignore les corrélations (approximation conservative)
    total_var = 0.0
    for exposure, volatility in zip(exposures, volatilities):
        # VaR individuelle = exposition × volatilité × sqrt(horizon) × z-score
        individual_var = abs(exposure) * volatility * time_factor * z_score
        total_var += individual_var

    return round(total_var, 2)


# ============================================================================
# CONCENTRATION (HHI - HERFINDAHL-HIRSCHMAN INDEX)
# ============================================================================


def calculate_hhi(distribution: list[float]) -> float:
    """Calcule l'indice de concentration HHI (Herfindahl-Hirschman Index).

    Le HHI mesure la concentration d'un portefeuille en sommant les carrés
    des parts de marché/exposition. Plus l'indice est élevé, plus le portefeuille
    est concentré sur quelques contreparties/secteurs.

    Formule:
        HHI = Σ(part_i)²

    où part_i est la fraction de chaque exposition dans le total (entre 0 et 1).

    Interpretation (seuils réglementaires):
        - 0.00 - 0.15: concentration faible (HHI_LOW_CONCENTRATION)
        - 0.15 - 0.25: concentration modérée (HHI_MODERATE_CONCENTRATION)
        - 0.25 - 1.00: concentration élevée (risque de concentration)

    Entrees:
        distribution: liste des parts d'exposition (déjà normalisées entre 0 et 1)
                      OU liste de montants absolus (la fonction normalise automatiquement).

    Sortie:
        L'indice HHI entre 0 (diversification maximale) et 1 (concentration totale).
        Retourne 0.0 si la distribution est vide.

    Exemple:
        >>> # Portefeuille équilibré (4 expositions égales)
        >>> calculate_hhi([0.25, 0.25, 0.25, 0.25])
        0.25

        >>> # Portefeuille concentré (un acteur dominant)
        >>> calculate_hhi([0.70, 0.15, 0.10, 0.05])
        0.5250  # Concentration élevée

        >>> # Avec montants absolus (normalisation automatique)
        >>> calculate_hhi([7_000_000, 1_500_000, 1_000_000, 500_000])
        0.5250  # Même résultat
    """
    if not distribution or len(distribution) == 0:
        return 0.0

    # Vérifier si les valeurs sont déjà normalisées (somme ≈ 1)
    total = sum(distribution)
    if total == 0:
        return 0.0

    # Normaliser si nécessaire (si somme != 1, on assume des montants absolus)
    if abs(total - 1.0) > 0.01:  # Tolérance de 1% pour arrondi
        shares = [value / total for value in distribution]
    else:
        shares = distribution

    # Calcul du HHI: somme des carrés des parts
    hhi = sum(share**2 for share in shares)

    return round(hhi, 4)


# ============================================================================
# PD / LGD / EL (EXPECTED LOSS)
# ============================================================================


def estimate_pd_from_rating(rating: str) -> float:
    """Estime la PD (Probability of Default) à partir d'une notation externe.

    Cette fonction utilise le mapping standard Bâle II/III entre notations
    externes et probabilités de défaut historiques observées.

    Entrees:
        rating: notation externe (ex: "AAA", "BBB+", "B-").
                Non sensible à la casse.

    Sortie:
        La PD estimée en décimal (ex: 0.0030 pour 0.30%).
        Retourne 0.05 (5%) par défaut si la notation est inconnue.

    Exemple:
        >>> estimate_pd_from_rating("AAA")
        0.0003  # 0.03%

        >>> estimate_pd_from_rating("BBB")
        0.0030  # 0.30%

        >>> estimate_pd_from_rating("B")
        0.0500  # 5.00%

    Note:
        Pour les notations internes (IRB), utiliser les modèles PD internes
        de la banque plutôt que ce mapping externe.
    """
    normalized_rating = rating.strip().upper()
    default_pd = 0.05  # 5% par défaut pour notation inconnue

    return PD_BY_RATING.get(normalized_rating, default_pd)


def calculate_expected_loss(pd: float, lgd: float, ead: float) -> float:
    """Calcule la perte attendue (EL - Expected Loss).

    La perte attendue représente la perte moyenne statistiquement anticipée
    sur une exposition de crédit, en intégrant la probabilité de défaut,
    la sévérité de la perte en cas de défaut, et le montant exposé.

    Formule:
        EL = PD × LGD × EAD

    où:
        - PD: Probability of Default (probabilité de défaut)
        - LGD: Loss Given Default (perte en cas de défaut)
        - EAD: Exposure at Default (exposition au moment du défaut)

    Entrees:
        pd: probabilité de défaut sur 1 an (ex: 0.03 pour 3%).
        lgd: perte en cas de défaut en % (ex: 0.45 pour 45%).
        ead: exposition au défaut (montant).

    Sortie:
        La perte attendue (montant).

    Exemple:
        >>> calculate_expected_loss(pd=0.03, lgd=0.45, ead=1_000_000)
        13500.00  # EL = 3% × 45% × 1M = 13,500

    Note:
        L'EL est utilisée pour:
        - Provisioning (réserves pour pertes attendues)
        - Pricing (tarification du risque de crédit)
        - RAROC (Risk-Adjusted Return on Capital)
    """
    el = pd * lgd * ead
    return round(el, 2)


def calculate_unexpected_loss(
    pd: float,
    lgd: float,
    ead: float,
    confidence_level: float = 0.999,
) -> float:
    """Calcule la perte inattendue (UL - Unexpected Loss) simplifiée.

    La perte inattendue représente la volatilité des pertes autour de la perte
    attendue. Elle sert de base au calcul des fonds propres économiques.

    Formule simplifiée (modèle Vasicek):
        UL ≈ EAD × LGD × sqrt(PD × (1 - PD)) × K

    où K est un facteur dépendant du niveau de confiance (Z-score).

    Entrees:
        pd: probabilité de défaut.
        lgd: perte en cas de défaut.
        ead: exposition au défaut.
        confidence_level: niveau de confiance (0.99 ou 0.999). Par défaut 0.999 (99.9%).

    Sortie:
        La perte inattendue estimée.

    Exemple:
        >>> calculate_unexpected_loss(pd=0.03, lgd=0.45, ead=1_000_000)
        117000.00  # UL pour couvrir 99.9% des scénarios

    Note:
        Formule simplifiée à usage pédagogique. Pour un calcul précis,
        utiliser un modèle de portefeuille complet (CreditMetrics, etc.).
    """
    if pd <= 0 or pd >= 1:
        return 0.0

    # Récupération du Z-score
    z_score = VAR_Z_SCORES.get(confidence_level, 2.326)  # Défaut: 99%

    # Volatilité de la distribution de Bernoulli: sqrt(PD × (1-PD))
    pd_volatility = math.sqrt(pd * (1 - pd))

    # UL = EAD × LGD × volatilité_PD × Z-score
    ul = ead * lgd * pd_volatility * z_score

    return round(ul, 2)
