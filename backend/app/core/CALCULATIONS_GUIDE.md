# Guide des Calculs Prudentiels - FODEP

Ce document décrit l'ensemble des fonctions de calcul disponibles dans `calculations.py` pour l'analyse prudentielle et le risque de crédit.

---

## Table des matières

1. [Constantes Réglementaires](#constantes-réglementaires)
2. [Ratios Prudentiels](#ratios-prudentiels)
3. [Calculs RWA et Capital](#calculs-rwa-et-capital)
4. [Risque de Crédit (PD/LGD/EL)](#risque-de-crédit)
5. [Value at Risk (VaR)](#value-at-risk)
6. [Concentration (HHI)](#concentration-hhi)
7. [Exemples d'utilisation](#exemples-dutilisation)

---

## Constantes Réglementaires

### Ratios minimaux UMOA (Bâle III adapté)

```python
MIN_CET1_RATIO = 0.05        # 5% - Common Equity Tier 1
MIN_TIER1_RATIO = 0.06       # 6% - Tier 1 Capital
MIN_SOLVENCY_RATIO = 0.09     # 9% - Ratio de solvabilité total minimum, sans coussin (CAR)
MIN_LEVERAGE_RATIO = 0.03    # 3% - Ratio de levier
```

### Seuils de concentration (HHI)

```python
HHI_LOW_CONCENTRATION = 0.15      # Concentration faible
HHI_MODERATE_CONCENTRATION = 0.25 # Concentration modérée
# > 0.25 = Concentration élevée (risque)
```

### LGD standard (Loss Given Default)

```python
LGD_SENIOR_SECURED = 0.40    # 40% - créances garanties senior
LGD_SENIOR_UNSECURED = 0.45  # 45% - créances non garanties senior
LGD_SUBORDINATED = 0.75      # 75% - créances subordonnées
```

---

## Ratios Prudentiels

### 1. CET1 Ratio (Common Equity Tier 1)

**Fonction:** `calculate_cet1_ratio(cet1_capital: float, rwa: float) -> float`

**Formule:** CET1 Ratio = CET1 Capital / RWA

**Minimum réglementaire:** 5% (UMOA)

**Exemple:**
```python
from app.core.calculations import calculate_cet1_ratio

cet1_ratio = calculate_cet1_ratio(cet1_capital=5_000_000, rwa=100_000_000)
# Résultat: 0.05 (5%)

if cet1_ratio >= MIN_CET1_RATIO:
    print("✓ Conforme au ratio CET1 minimum")
```

---

### 2. Tier 1 Ratio

**Fonction:** `calculate_tier1_ratio(tier1_capital: float, rwa: float) -> float`

**Formule:** Tier 1 Ratio = Tier 1 Capital / RWA

**Minimum réglementaire:** 6% (UMOA)

**Composition Tier 1:**
- CET1 (capital social, réserves, résultats non distribués)
- Instruments hybrides perpétuels (actions de préférence)

**Exemple:**
```python
tier1_ratio = calculate_tier1_ratio(tier1_capital=6_000_000, rwa=100_000_000)
# Résultat: 0.06 (6%)
```

---

### 3. Ratio de Solvabilité (CAR)

**Fonction:** `calculate_solvency_ratio(total_capital: float, rwa: float) -> float`

**Formule:** Solvency Ratio = Total Capital / RWA

**Minimum réglementaire:** 9% (UMOA)

**Composition Total Capital:**
- Tier 1 (CET1 + instruments hybrides)
- Tier 2 (dettes subordonnées, provisions)

**Exemple:**
```python
solvency_ratio = calculate_solvency_ratio(total_capital=10_000_000, rwa=100_000_000)
# Résultat: 0.10 (10%)
```

---

### 4. Ratio de Levier (Leverage Ratio)

**Fonction:** `calculate_leverage_ratio(tier1_capital: float, total_exposures: float) -> float`

**Formule:** Leverage Ratio = Tier 1 Capital / Total Exposures

**Minimum réglementaire:** 3% (UMOA)

**Particularité:** Mesure non pondérée par les risques (backstop ratio)

**Exemple:**
```python
leverage_ratio = calculate_leverage_ratio(
    tier1_capital=6_000_000, 
    total_exposures=250_000_000
)
# Résultat: 0.024 (2.4% - non conforme)
```

---

## Calculs RWA et Capital

### 5. Densité RWA

**Fonction:** `calculate_rwa_density(rwa: float, gross_exposure: float) -> float`

**Formule:** Densité RWA = RWA / Exposition Brute

**Interprétation:**
- **0.00 - 0.20:** Portefeuille peu risqué (ex: souverains AAA)
- **0.20 - 0.50:** Risque modéré (ex: corporate investment grade)
- **1.00:** Risque standard (RW moyen = 100%)
- **> 1.50:** Risque élevé (ex: actions, immobilier)

**Exemple:**
```python
density = calculate_rwa_density(rwa=25_000_000, gross_exposure=100_000_000)
# Résultat: 0.25 (densité de 25% - risque modéré)
```

---

### 6. Ratio de Couverture CRM

**Fonction:** `calculate_crm_coverage_ratio(covered_ead: float, total_ead: float) -> float`

**Formule:** Coverage Ratio = EAD Couverte / EAD Totale

**CRM inclut:** Garanties, collatéral, dérivés de crédit, netting

**Exemple:**
```python
coverage = calculate_crm_coverage_ratio(covered_ead=30_000_000, total_ead=100_000_000)
# Résultat: 0.30 (30% du portefeuille est couvert)
```

---

## Risque de Crédit

### 7. Estimation PD par notation

**Fonction:** `estimate_pd_from_rating(rating: str) -> float`

**Mapping Bâle II/III:**

| Notation | PD (%) | Notation | PD (%) |
|----------|--------|----------|--------|
| AAA      | 0.03%  | BBB      | 0.30%  |
| AA       | 0.05%  | BB       | 1.50%  |
| A        | 0.10%  | B        | 5.00%  |
| BBB-     | 0.50%  | CCC      | 20.00% |

**Exemple:**
```python
pd_aaa = estimate_pd_from_rating("AAA")  # 0.0003 (0.03%)
pd_bbb = estimate_pd_from_rating("BBB")  # 0.0030 (0.30%)
pd_b = estimate_pd_from_rating("B")      # 0.0500 (5.00%)
```

---

### 8. Perte Attendue (Expected Loss)

**Fonction:** `calculate_expected_loss(pd: float, lgd: float, ead: float) -> float`

**Formule:** EL = PD × LGD × EAD

**Usage:**
- Provisioning IFRS 9 (Stage 1: 12-month EL)
- Pricing du risque de crédit
- Calcul RAROC

**Exemple:**
```python
# Corporate BBB, créance non garantie
pd = estimate_pd_from_rating("BBB")  # 0.30%
lgd = 0.45  # 45% (senior unsecured)
ead = 10_000_000

el = calculate_expected_loss(pd, lgd, ead)
# Résultat: 13,500 (provision à constituer)
```

---

### 9. Perte Inattendue (Unexpected Loss)

**Fonction:** `calculate_unexpected_loss(pd: float, lgd: float, ead: float, confidence_level: float = 0.999) -> float`

**Formule (Vasicek simplifié):** UL ≈ EAD × LGD × sqrt(PD × (1-PD)) × Z-score

**Usage:**
- Calcul des fonds propres économiques
- Allocation de capital RAROC
- Stress testing

**Exemple:**
```python
ul = calculate_unexpected_loss(
    pd=0.03,
    lgd=0.45,
    ead=10_000_000,
    confidence_level=0.999  # 99.9%
)
# Résultat: ~390,000 (capital économique à allouer)
```

---

## Value at Risk

### 10. VaR Paramétrique Simplifiée

**Fonction:** `calculate_portfolio_var(exposures: list[float], volatilities: list[float] | None = None, confidence_level: float = 0.99, time_horizon_days: int = 10) -> float`

**Formule:** VaR = Valeur × Volatilité × sqrt(Horizon) × Z-score

**Niveaux de confiance supportés:**
- 90% (Z = 1.282)
- 95% (Z = 1.645)
- 99% (Z = 2.326)
- 99.9% (Z = 3.090)

**Exemple:**
```python
# Portefeuille multi-actifs
exposures = [10_000_000, 5_000_000, 3_000_000]
volatilities = [0.015, 0.025, 0.030]  # Volatilité journalière

var_99 = calculate_portfolio_var(
    exposures=exposures,
    volatilities=volatilities,
    confidence_level=0.99,
    time_horizon_days=10
)
# Résultat: perte maximale à 99% sur 10 jours
```

**Limitations:**
- Pas de corrélations (approximation conservative)
- Hypothèse de distribution normale
- Pour VaR précise: utiliser Monte Carlo ou méthodes historiques

---

## Concentration (HHI)

### 11. Indice Herfindahl-Hirschman

**Fonction:** `calculate_hhi(distribution: list[float]) -> float`

**Formule:** HHI = Σ(part_i)²

**Interprétation:**

| HHI | Niveau | Signification |
|-----|--------|---------------|
| 0.00 - 0.15 | Faible | Diversification excellente |
| 0.15 - 0.25 | Modérée | Diversification acceptable |
| 0.25 - 1.00 | Élevée | Risque de concentration |

**Exemple:**
```python
# Portefeuille équilibré (4 contreparties égales)
hhi_balanced = calculate_hhi([0.25, 0.25, 0.25, 0.25])
# Résultat: 0.25 (seuil modéré)

# Portefeuille concentré
hhi_concentrated = calculate_hhi([0.70, 0.15, 0.10, 0.05])
# Résultat: 0.525 (forte concentration - ALERTE)

# Avec montants absolus (normalisation automatique)
hhi_amounts = calculate_hhi([70_000_000, 15_000_000, 10_000_000, 5_000_000])
# Résultat: 0.525 (même résultat)
```

---

## Exemples d'utilisation

### Scénario 1: Analyse Prudentielle Complète

```python
from app.core.calculations import (
    calculate_cet1_ratio,
    calculate_tier1_ratio,
    calculate_solvency_ratio,
    calculate_leverage_ratio,
    MIN_CET1_RATIO,
    MIN_TIER1_RATIO,
    MIN_SOLVENCY_RATIO,
    MIN_LEVERAGE_RATIO,
)

# Données d'une banque
cet1_capital = 5_000_000
tier1_capital = 6_000_000  # CET1 + instruments hybrides
total_capital = 10_000_000  # Tier 1 + Tier 2
rwa = 100_000_000
total_exposures = 250_000_000

# Calcul des ratios
ratios = {
    "cet1": calculate_cet1_ratio(cet1_capital, rwa),
    "tier1": calculate_tier1_ratio(tier1_capital, rwa),
    "solvency": calculate_solvency_ratio(total_capital, rwa),
    "leverage": calculate_leverage_ratio(tier1_capital, total_exposures),
}

# Vérification conformité
compliance = {
    "cet1": ratios["cet1"] >= MIN_CET1_RATIO,
    "tier1": ratios["tier1"] >= MIN_TIER1_RATIO,
    "solvency": ratios["solvency"] >= MIN_SOLVENCY_RATIO,
    "leverage": ratios["leverage"] >= MIN_LEVERAGE_RATIO,
}

print(f"CET1: {ratios['cet1']:.2%} {'✓' if compliance['cet1'] else '✗'}")
print(f"Tier 1: {ratios['tier1']:.2%} {'✓' if compliance['tier1'] else '✗'}")
print(f"Solvabilité: {ratios['solvency']:.2%} {'✓' if compliance['solvency'] else '✗'}")
print(f"Levier: {ratios['leverage']:.2%} {'✓' if compliance['leverage'] else '✗'}")
```

---

### Scénario 2: Analyse de Portefeuille

```python
from app.core.calculations import (
    calculate_rwa_density,
    calculate_hhi,
    calculate_crm_coverage_ratio,
)

# Portefeuille de crédit
exposures = [50_000_000, 30_000_000, 15_000_000, 5_000_000]
risk_weights = [0.50, 0.75, 1.00, 1.50]

# Calcul RWA
rwas = [exp * rw for exp, rw in zip(exposures, risk_weights)]
total_exposure = sum(exposures)
total_rwa = sum(rwas)

# Densité RWA
density = calculate_rwa_density(total_rwa, total_exposure)
print(f"Densité RWA: {density:.2%}")

# Concentration
hhi = calculate_hhi(exposures)
print(f"HHI: {hhi:.4f}")
if hhi < 0.15:
    print("→ Concentration faible ✓")
elif hhi < 0.25:
    print("→ Concentration modérée")
else:
    print("→ Concentration élevée ⚠")

# Couverture CRM
covered_ead = 40_000_000
coverage = calculate_crm_coverage_ratio(covered_ead, total_exposure)
print(f"Couverture CRM: {coverage:.1%}")
```

---

### Scénario 3: Calcul de Provisions (IFRS 9)

```python
from app.core.calculations import (
    estimate_pd_from_rating,
    calculate_expected_loss,
    LGD_SENIOR_UNSECURED,
)

# Exposition corporate BBB
rating = "BBB"
ead = 50_000_000
lgd = LGD_SENIOR_UNSECURED  # 45%

# Stage 1: 12-month Expected Loss
pd_12m = estimate_pd_from_rating(rating)
provision_stage1 = calculate_expected_loss(pd_12m, lgd, ead)

print(f"Rating: {rating}")
print(f"PD 12-month: {pd_12m:.4%}")
print(f"LGD: {lgd:.1%}")
print(f"EAD: {ead:,.0f}")
print(f"Provision (Stage 1): {provision_stage1:,.2f}")

# Stage 2: Lifetime Expected Loss (exemple: PD lifetime = 3× PD 12m)
pd_lifetime = pd_12m * 3
provision_stage2 = calculate_expected_loss(pd_lifetime, lgd, ead)
print(f"Provision (Stage 2): {provision_stage2:,.2f}")
```

---

### Scénario 4: VaR de Trading Book

```python
from app.core.calculations import calculate_portfolio_var

# Portefeuille de trading (obligations)
positions = [20_000_000, 15_000_000, 10_000_000]
volatilities = [0.008, 0.012, 0.015]  # Volatilité journalière

# VaR 10 jours à 99%
var_10d_99 = calculate_portfolio_var(
    exposures=positions,
    volatilities=volatilities,
    confidence_level=0.99,
    time_horizon_days=10,
)

print(f"VaR 10j @ 99%: {var_10d_99:,.0f}")

# VaR 1 jour à 99% (regulatory VaR)
var_1d_99 = calculate_portfolio_var(
    exposures=positions,
    volatilities=volatilities,
    confidence_level=0.99,
    time_horizon_days=1,
)

print(f"VaR 1j @ 99%: {var_1d_99:,.0f}")

# Market Risk Capital (Bâle III: 3× VaR 10j)
market_risk_capital = 3 * var_10d_99
print(f"Capital de risque de marché: {market_risk_capital:,.0f}")
```

---

## Références Réglementaires

- **BCEAO/UMOA:** Dispositif prudentiel applicable aux banques et établissements financiers de l'UMOA
- **Bâle III:** "Basel III: A global regulatory framework for more resilient banks and banking systems" (BCBS 2010)
- **IFRS 9:** "Financial Instruments" - Expected Credit Loss Model
- **CRR/CRD IV:** Capital Requirements Regulation/Directive (Europe)

---

## Notes Techniques

### Précision des calculs
- Tous les montants sont arrondis à 2 décimales
- Les ratios utilisent `safe_ratio()` pour éviter la division par zéro
- Les ratios conservent 8 décimales de précision pour éviter l'écrasement des petites catégories

### Limitations
- **VaR:** Approche paramétrique simplifiée sans corrélations (conservative)
- **PD:** Mapping externe standard (utiliser modèles IRB internes si disponibles)
- **UL:** Formule Vasicek simplifiée (pour calcul précis: CreditMetrics, CreditRisk+)

### Extensions futures possibles
- Matrice de corrélations pour VaR de portefeuille
- Modèles IRB (Internal Ratings-Based) pour PD/LGD
- CCR (Counterparty Credit Risk) avec CVA/DVA
- Stress testing et scénarios adverses
- FRTB (Fundamental Review of Trading Book)

---

**Version:** 1.0  
**Date:** 2026-06-12  
**Auteur:** FODEP Team
