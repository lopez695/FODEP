"""Le tableau de bord distingue les fonds propres détenus de l'exigence.

La tuile « Ratio de solvabilité » lisait la même métrique pour les deux, ce qui
présentait les fonds propres comme une exigence réglementaire et affichait un
excédent systématiquement nul.
"""

from __future__ import annotations

import pytest

from app.core.config import settings
from app.dashboard.services import get_dashboard_snapshot


@pytest.fixture(scope="module")
def metrics() -> dict[str, float]:
    snapshot = get_dashboard_snapshot()
    return {metric.key: metric.value for metric in snapshot.metrics}


def test_exigence_de_fonds_propres_exposee(metrics):
    assert "capital_requis" in metrics, (
        "Le tableau de bord doit exposer l'exigence de fonds propres : sans "
        "elle, l'écran retombe sur les fonds propres détenus."
    )


def test_exigence_vaut_le_rwa_total_pondere_par_le_ratio(metrics):
    attendu = metrics["rwa"] * settings.capital_ratio
    assert metrics["capital_requis"] == pytest.approx(attendu, rel=1e-9)


def test_exigence_porte_sur_le_rwa_total_pas_le_seul_credit(metrics):
    # RWA total = crédit + marché + opérationnel. Asseoir l'exigence sur le
    # seul risque de crédit la sous-évaluerait.
    hors_credit = metrics["rwa_market"] + metrics["rwa_op"]
    if hors_credit <= 0:
        pytest.skip("Aucun RWA marché ni opérationnel dans ce jeu de données.")
    credit_seul = metrics["rwa_credit"] * settings.capital_ratio
    assert metrics["capital_requis"] > credit_seul


def test_fonds_propres_et_exigence_sont_deux_grandeurs_distinctes(metrics):
    # Elles ne coïncident que par accident ; les confondre annulait l'excédent.
    assert metrics["capital"] != pytest.approx(metrics["capital_requis"])


def test_ratio_de_solvabilite_coherent_avec_l_excedent(metrics):
    if metrics["rwa"] <= 0:
        pytest.skip("Portefeuille vide.")
    excedent = metrics["capital"] - metrics["capital_requis"]
    au_dessus_du_minimum = metrics["solvabilite"] >= settings.capital_ratio
    assert (excedent >= 0) == au_dessus_du_minimum, (
        "Un excédent positif doit aller de pair avec un ratio au-dessus du "
        "minimum réglementaire."
    )
