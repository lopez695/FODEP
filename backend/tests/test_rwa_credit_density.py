"""Tests unitaires pour l'analyse de densité RWA."""

from unittest.mock import patch, MagicMock
from datetime import date
import pytest

from app.rwa_credit.services import get_rwa_credit_analysis

@pytest.fixture
def mock_expositions():
    """Fournit des expositions factices pour tester les calculs."""
    expo1 = MagicMock()
    expo1.analysis_date = date(2023, 12, 31)
    expo1.counterparty.category = "Souverain"
    expo1.currency = "XOF"
    expo1.gross_amount = 100000.0
    expo1.loan_total_amount = 100000.0
    expo1.ead = 100000.0
    expo1.rwa = 20000.0
    expo1.final_rw = 0.20

    expo2 = MagicMock()
    expo2.analysis_date = date(2023, 12, 31)
    expo2.counterparty.category = "Entreprise"
    expo2.currency = "XOF"
    expo2.gross_amount = 50000.0
    expo2.loan_total_amount = 50000.0
    expo2.ead = 50000.0
    expo2.rwa = 50000.0
    expo2.final_rw = 1.00

    return [expo1, expo2]

@patch("app.rwa_credit.services.list_expositions")
@patch("app.rwa_credit.services._load_capital_position")
def test_density_rwa_calculation(mock_load_capital, mock_list_expos, mock_expositions):
    """Vérifie que la densité RWA globale est exactement le total RWA divisé par le total EAD."""
    # Mocks
    mock_list_expos.return_value = mock_expositions
    mock_load_capital.return_value = {
        "own_funds": 10000.0,
        "own_funds_available": True,
        "rwa_total": 70000.0,
        "solvency_ratio": 0.14,
    }

    # Calcul
    analysis = get_rwa_credit_analysis()

    # Assertions
    total_ead_expected = 150000.0
    total_rwa_expected = 70000.0
    density_expected = total_rwa_expected / total_ead_expected

    assert analysis.totals.exposure_total == total_ead_expected
    assert analysis.totals.rwa == total_rwa_expected
    assert analysis.density_rwa == density_expected
    assert round(analysis.density_rwa, 4) == round(70000.0 / 150000.0, 4)


@patch("app.rwa_credit.services.list_expositions")
@patch("app.rwa_credit.services._load_capital_position")
def test_counterparty_breakdown_and_ead_fallback(mock_load_capital, mock_list_expos):
    """Vérifie la ventilation par contrepartie et la reconstitution d'EAD.

    Une exposition importée sans EAD persistée (ead=0, final_rw=0) doit voir
    son EAD reconstituée via RWA / pondération initiale, et chaque agent doit
    exposer ses contreparties triées par RWA décroissant avec des parts
    sommant à 100 %.
    """

    def make_expo(name, category, ead, rwa, final_rw, original_rw):
        expo = MagicMock()
        expo.analysis_date = date(2023, 12, 31)
        expo.counterparty.category = category
        expo.counterparty.name = name
        expo.currency = "XOF"
        expo.gross_amount = 100000.0
        expo.loan_total_amount = 100000.0
        expo.ead = ead
        expo.rwa = rwa
        expo.final_rw = final_rw
        expo.original_rw = original_rw
        return expo

    mock_list_expos.return_value = [
        make_expo("Alpha", "Entreprise", 100000.0, 100000.0, 1.0, 1.0),
        make_expo("Beta", "Entreprise", 50000.0, 50000.0, 1.0, 1.0),
        # EAD non persistée : doit être reconstituée à 30000 / 1.5 = 20000.
        make_expo("Gamma", "Entreprise", 0.0, 30000.0, 0.0, 1.5),
    ]
    mock_load_capital.return_value = {
        "own_funds": 10000.0,
        "own_funds_available": True,
        "rwa_total": 180000.0,
        "solvency_ratio": 0.05,
    }

    analysis = get_rwa_credit_analysis()

    assert analysis.totals.ead == 170000.0  # 100000 + 50000 + 20000
    assert analysis.totals.rwa == 180000.0

    agent = analysis.agents[0]
    names = [cp.name for cp in agent.counterparties]
    assert names == ["Alpha", "Beta", "Gamma"]  # tri RWA décroissant

    gamma = agent.counterparties[2]
    assert gamma.exposure == 20000.0
    assert gamma.rwa == 30000.0
    assert gamma.share == pytest.approx(30000.0 / 180000.0)
    assert sum(cp.share for cp in agent.counterparties) == pytest.approx(1.0)
