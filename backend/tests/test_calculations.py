"""Tests unitaires pour les fonctions de calcul prudentiel."""

from __future__ import annotations

import pytest

from app.core.calculations import (
    MIN_CET1_RATIO,
    MIN_LEVERAGE_RATIO,
    MIN_SOLVENCY_RATIO,
    MIN_TIER1_RATIO,
    calculate_cet1_ratio,
    calculate_crm_coverage_ratio,
    calculate_expected_loss,
    calculate_hhi,
    calculate_leverage_ratio,
    calculate_portfolio_var,
    calculate_rwa_density,
    calculate_solvency_ratio,
    calculate_tier1_ratio,
    calculate_unexpected_loss,
    estimate_pd_from_rating,
)


# ============================================================================
# TESTS: RATIOS PRUDENTIELS
# ============================================================================


class TestPrudentialRatios:
    """Tests des ratios prudentiels Bâle III / UMOA."""

    def test_calculate_cet1_ratio_normal(self):
        """Test du calcul CET1 ratio dans des conditions normales."""
        result = calculate_cet1_ratio(cet1_capital=500_000, rwa=10_000_000)
        assert result == 0.05  # 5%
        assert result >= MIN_CET1_RATIO  # Conforme au minimum UMOA

    def test_calculate_cet1_ratio_above_minimum(self):
        """Test CET1 ratio au-dessus du minimum réglementaire."""
        result = calculate_cet1_ratio(cet1_capital=800_000, rwa=10_000_000)
        assert result == 0.08  # 8%
        assert result > MIN_CET1_RATIO

    def test_calculate_cet1_ratio_zero_rwa(self):
        """Test CET1 ratio avec RWA nul (évite division par zéro)."""
        result = calculate_cet1_ratio(cet1_capital=500_000, rwa=0)
        assert result == 0.0

    def test_calculate_tier1_ratio_normal(self):
        """Test du calcul Tier 1 ratio."""
        result = calculate_tier1_ratio(tier1_capital=750_000, rwa=10_000_000)
        assert result == 0.075  # 7,5%
        assert result >= MIN_TIER1_RATIO

    def test_calculate_tier1_ratio_with_hybrid_instruments(self):
        """Test Tier 1 incluant instruments hybrides."""
        # CET1 = 500k, instruments hybrides = 200k -> Tier 1 = 700k
        result = calculate_tier1_ratio(tier1_capital=700_000, rwa=10_000_000)
        assert result == 0.07  # 7%

    def test_calculate_solvency_ratio_normal(self):
        """Test du ratio de solvabilité global."""
        result = calculate_solvency_ratio(total_capital=1_000_000, rwa=10_000_000)
        assert result == 0.1  # 10%
        assert result >= MIN_SOLVENCY_RATIO

    def test_calculate_solvency_ratio_minimum_umoa(self):
        """Test ratio de solvabilité au minimum UMOA."""
        result = calculate_solvency_ratio(total_capital=900_000, rwa=10_000_000)
        assert result == 0.09  # 9%
        assert result == MIN_SOLVENCY_RATIO

    def test_calculate_leverage_ratio_normal(self):
        """Test du ratio de levier."""
        result = calculate_leverage_ratio(tier1_capital=600_000, total_exposures=25_000_000)
        assert result == 0.024  # 2.4%
        # Note: sous le minimum de 3% -> non conforme

    def test_calculate_leverage_ratio_compliant(self):
        """Test ratio de levier conforme."""
        result = calculate_leverage_ratio(tier1_capital=900_000, total_exposures=25_000_000)
        assert result == 0.036  # 3.6%
        assert result >= MIN_LEVERAGE_RATIO

    def test_calculate_leverage_ratio_zero_exposure(self):
        """Test ratio de levier avec exposition nulle."""
        result = calculate_leverage_ratio(tier1_capital=600_000, total_exposures=0)
        assert result == 0.0


# ============================================================================
# TESTS: DENSITE RWA ET COUVERTURE CRM
# ============================================================================


class TestRWADensityAndCoverage:
    """Tests de la densité RWA et du ratio de couverture CRM."""

    def test_calculate_rwa_density_low_risk(self):
        """Test densité RWA pour portefeuille peu risqué."""
        # Ex: portefeuille souverain notés AAA (RW=0%)
        result = calculate_rwa_density(rwa=0, gross_exposure=20_000_000)
        assert result == 0.0

    def test_calculate_rwa_density_moderate_risk(self):
        """Test densité RWA pour portefeuille risque modéré."""
        # Ex: corporate investment grade (RW moyen ~25%)
        result = calculate_rwa_density(rwa=5_000_000, gross_exposure=20_000_000)
        assert result == 0.25

    def test_calculate_rwa_density_standard_risk(self):
        """Test densité RWA pour portefeuille risque standard."""
        # RW = 100%
        result = calculate_rwa_density(rwa=20_000_000, gross_exposure=20_000_000)
        assert result == 1.0

    def test_calculate_rwa_density_high_risk(self):
        """Test densité RWA pour portefeuille très risqué."""
        # Ex: actions (RW=150%)
        result = calculate_rwa_density(rwa=30_000_000, gross_exposure=20_000_000)
        assert result == 1.5

    def test_calculate_crm_coverage_ratio_no_coverage(self):
        """Test ratio de couverture CRM sans couverture."""
        result = calculate_crm_coverage_ratio(covered_ead=0, total_ead=10_000_000)
        assert result == 0.0

    def test_calculate_crm_coverage_ratio_partial(self):
        """Test ratio de couverture CRM partielle."""
        result = calculate_crm_coverage_ratio(covered_ead=3_000_000, total_ead=10_000_000)
        assert result == 0.3  # 30% de couverture

    def test_calculate_crm_coverage_ratio_full(self):
        """Test ratio de couverture CRM complète."""
        result = calculate_crm_coverage_ratio(covered_ead=10_000_000, total_ead=10_000_000)
        assert result == 1.0  # 100% de couverture


# ============================================================================
# TESTS: VAR (VALUE AT RISK)
# ============================================================================


class TestValueAtRisk:
    """Tests du calcul de VaR simplifiée."""

    def test_calculate_portfolio_var_single_exposure(self):
        """Test VaR sur une exposition unique."""
        # Exposition 1M, volatilité 2%, 99% confiance, 10 jours
        # VaR = 1M × 0.02 × sqrt(10) × 2.326 ≈ 147,000
        result = calculate_portfolio_var(
            exposures=[1_000_000],
            volatilities=[0.02],
            confidence_level=0.99,
            time_horizon_days=10,
        )
        assert 145_000 <= result <= 150_000

    def test_calculate_portfolio_var_multiple_exposures(self):
        """Test VaR sur portefeuille multi-expositions."""
        result = calculate_portfolio_var(
            exposures=[1_000_000, 2_000_000, 500_000],
            volatilities=[0.01, 0.02, 0.03],
            confidence_level=0.99,
            time_horizon_days=10,
        )
        # VaR additive (sans corrélations)
        assert result > 0

    def test_calculate_portfolio_var_default_volatility(self):
        """Test VaR avec volatilité par défaut."""
        result = calculate_portfolio_var(
            exposures=[1_000_000],
            volatilities=None,  # Utilise 2% par défaut
            confidence_level=0.99,
            time_horizon_days=10,
        )
        assert result > 0

    def test_calculate_portfolio_var_95_confidence(self):
        """Test VaR avec niveau de confiance 95%."""
        result = calculate_portfolio_var(
            exposures=[1_000_000],
            volatilities=[0.02],
            confidence_level=0.95,
            time_horizon_days=10,
        )
        # VaR à 95% doit être inférieure à VaR à 99%
        assert result > 0
        assert result < 150_000

    def test_calculate_portfolio_var_one_day_horizon(self):
        """Test VaR sur horizon 1 jour."""
        result = calculate_portfolio_var(
            exposures=[1_000_000],
            volatilities=[0.02],
            confidence_level=0.99,
            time_horizon_days=1,
        )
        # VaR 1 jour = 1M × 0.02 × 1 × 2.326 ≈ 46,520
        assert 45_000 <= result <= 48_000

    def test_calculate_portfolio_var_empty_portfolio(self):
        """Test VaR sur portefeuille vide."""
        result = calculate_portfolio_var(exposures=[], confidence_level=0.99)
        assert result == 0.0

    def test_calculate_portfolio_var_invalid_confidence(self):
        """Test VaR avec niveau de confiance invalide."""
        with pytest.raises(ValueError, match="non supporté"):
            calculate_portfolio_var(
                exposures=[1_000_000],
                confidence_level=0.85,  # Non supporté
            )

    def test_calculate_portfolio_var_mismatched_lengths(self):
        """Test VaR avec nombres d'expositions et volatilités différents."""
        with pytest.raises(ValueError, match="doit correspondre"):
            calculate_portfolio_var(
                exposures=[1_000_000, 2_000_000],
                volatilities=[0.02],  # Seulement 1 volatilité pour 2 expositions
            )


# ============================================================================
# TESTS: CONCENTRATION (HHI)
# ============================================================================


class TestConcentration:
    """Tests de l'indice de concentration HHI."""

    def test_calculate_hhi_perfect_diversification(self):
        """Test HHI avec diversification parfaite (4 parts égales)."""
        result = calculate_hhi([0.25, 0.25, 0.25, 0.25])
        assert result == 0.25  # 4 × (0.25)² = 0.25

    def test_calculate_hhi_moderate_concentration(self):
        """Test HHI avec concentration modérée."""
        result = calculate_hhi([0.40, 0.30, 0.20, 0.10])
        assert 0.25 <= result <= 0.35

    def test_calculate_hhi_high_concentration(self):
        """Test HHI avec forte concentration."""
        result = calculate_hhi([0.70, 0.15, 0.10, 0.05])
        assert result >= 0.52  # Forte concentration
        assert result > 0.25  # Au-dessus du seuil modéré

    def test_calculate_hhi_monopoly(self):
        """Test HHI avec concentration maximale (monopole)."""
        result = calculate_hhi([1.0])
        assert result == 1.0  # Concentration maximale

    def test_calculate_hhi_with_absolute_amounts(self):
        """Test HHI avec montants absolus (normalisation auto)."""
        # 70%, 15%, 10%, 5%
        result = calculate_hhi([7_000_000, 1_500_000, 1_000_000, 500_000])
        assert result >= 0.52  # Même résultat que parts normalisées

    def test_calculate_hhi_empty_distribution(self):
        """Test HHI avec distribution vide."""
        result = calculate_hhi([])
        assert result == 0.0

    def test_calculate_hhi_zero_total(self):
        """Test HHI avec total nul."""
        result = calculate_hhi([0, 0, 0])
        assert result == 0.0


# ============================================================================
# TESTS: PD / LGD / EL
# ============================================================================


class TestCreditRiskParameters:
    """Tests des paramètres de risque de crédit."""

    def test_estimate_pd_from_rating_aaa(self):
        """Test estimation PD pour notation AAA."""
        result = estimate_pd_from_rating("AAA")
        assert result == 0.0003  # 0.03%

    def test_estimate_pd_from_rating_bbb(self):
        """Test estimation PD pour notation BBB."""
        result = estimate_pd_from_rating("BBB")
        assert result == 0.0030  # 0.30%

    def test_estimate_pd_from_rating_b(self):
        """Test estimation PD pour notation B."""
        result = estimate_pd_from_rating("B")
        assert result == 0.0500  # 5.00%

    def test_estimate_pd_from_rating_default(self):
        """Test estimation PD pour notation D (défaut)."""
        result = estimate_pd_from_rating("D")
        assert result == 1.0  # 100%

    def test_estimate_pd_from_rating_case_insensitive(self):
        """Test estimation PD insensible à la casse."""
        result = estimate_pd_from_rating("aaa")
        assert result == 0.0003

    def test_estimate_pd_from_rating_unknown(self):
        """Test estimation PD pour notation inconnue."""
        result = estimate_pd_from_rating("XXX")
        assert result == 0.05  # 5% par défaut

    def test_calculate_expected_loss_normal(self):
        """Test calcul de la perte attendue."""
        # PD=3%, LGD=45%, EAD=1M -> EL = 13,500
        result = calculate_expected_loss(pd=0.03, lgd=0.45, ead=1_000_000)
        assert result == 13_500.00

    def test_calculate_expected_loss_high_pd(self):
        """Test EL avec PD élevée."""
        # PD=20%, LGD=45%, EAD=1M -> EL = 90,000
        result = calculate_expected_loss(pd=0.20, lgd=0.45, ead=1_000_000)
        assert result == 90_000.00

    def test_calculate_expected_loss_zero_pd(self):
        """Test EL avec PD nulle."""
        result = calculate_expected_loss(pd=0.0, lgd=0.45, ead=1_000_000)
        assert result == 0.0

    def test_calculate_expected_loss_full_lgd(self):
        """Test EL avec LGD de 100% (perte totale)."""
        result = calculate_expected_loss(pd=0.05, lgd=1.0, ead=1_000_000)
        assert result == 50_000.00  # 5% × 100% × 1M

    def test_calculate_unexpected_loss_normal(self):
        """Test calcul de la perte inattendue."""
        result = calculate_unexpected_loss(pd=0.03, lgd=0.45, ead=1_000_000)
        assert result > 0
        # UL devrait être significativement supérieure à EL pour couvrir volatilité

    def test_calculate_unexpected_loss_zero_pd(self):
        """Test UL avec PD nulle."""
        result = calculate_unexpected_loss(pd=0.0, lgd=0.45, ead=1_000_000)
        assert result == 0.0

    def test_calculate_unexpected_loss_pd_one(self):
        """Test UL avec PD = 1 (défaut certain)."""
        result = calculate_unexpected_loss(pd=1.0, lgd=0.45, ead=1_000_000)
        assert result == 0.0  # Pas de volatilité si défaut certain


# ============================================================================
# TESTS D'INTEGRATION
# ============================================================================


class TestIntegrationScenarios:
    """Tests d'intégration sur scénarios réalistes."""

    def test_complete_prudential_analysis(self):
        """Test analyse prudentielle complète d'une banque."""
        # Données fictives d'une banque
        cet1 = 5_000_000
        tier1 = 7_500_000
        total_capital = 10_000_000
        rwa = 100_000_000
        total_exposures = 150_000_000

        # Calcul des ratios
        cet1_ratio = calculate_cet1_ratio(cet1, rwa)
        tier1_ratio = calculate_tier1_ratio(tier1, rwa)
        solvency_ratio = calculate_solvency_ratio(total_capital, rwa)
        leverage_ratio = calculate_leverage_ratio(tier1, total_exposures)

        # Vérifications de cohérence
        assert cet1_ratio < tier1_ratio  # CET1 ⊂ Tier 1
        assert tier1_ratio < solvency_ratio  # Tier 1 ⊂ Total Capital

        # Vérification conformité UMOA
        assert cet1_ratio >= MIN_CET1_RATIO
        assert tier1_ratio >= MIN_TIER1_RATIO
        assert solvency_ratio >= MIN_SOLVENCY_RATIO
        assert leverage_ratio >= MIN_LEVERAGE_RATIO

    def test_portfolio_risk_analysis(self):
        """Test analyse de risque complète d'un portefeuille."""
        # Portefeuille de 3 contreparties
        exposures = [10_000_000, 5_000_000, 3_000_000]
        risk_weights = [0.50, 0.75, 1.00]

        # Calcul RWA et densité
        rwas = [exp * rw for exp, rw in zip(exposures, risk_weights)]
        total_rwa = sum(rwas)
        total_exposure = sum(exposures)
        density = calculate_rwa_density(total_rwa, total_exposure)

        # Calcul concentration
        hhi = calculate_hhi(exposures)

        # Vérifications
        assert 0 < density < 1  # Portefeuille mixte
        assert hhi > 0.25  # Concentration élevée (dominance 10M)

    def test_credit_risk_provisioning(self):
        """Test calcul de provisions pour pertes de crédit."""
        # Exposition corporate BBB
        rating = "BBB"
        ead = 5_000_000
        lgd = 0.45

        # Estimation PD et calcul EL
        pd = estimate_pd_from_rating(rating)
        expected_loss = calculate_expected_loss(pd, lgd, ead)

        # Vérifications
        assert pd == 0.0030  # 0.30% pour BBB
        assert expected_loss == 6_750.00  # Provision IFRS 9 Stage 1
