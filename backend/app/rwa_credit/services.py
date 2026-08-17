"""Service d'agrégation de l'analyse RWA Crédit.

Toute la logique de calcul de cet écran est centralisée ici (côté Python) :
le frontend se contente d'afficher, trier et formater le résultat.
"""

from __future__ import annotations

from app.core.bceao_calculations import calculate_fonds_propres
from app.core.calculations import convert_currency_amount
from app.market.services import resolve_market_capital
from app.core.config import RWA_EXPECTED_WEIGHT_RANGES, settings
from app.expositions.services import list_expositions
from app.risque_operationnel.services import calcul_aib as _calcul_aib_uemoa
from app.rwa_credit.models import (
    RwaCreditAgentRow,
    RwaCreditAnalysis,
    RwaCreditComparisonPeriod,
    RwaCreditCounterparty,
    RwaCreditTotals,
    RwaCreditTranche,
)
from database.connection import database_manager
from database.services.rwa_calculation_service import resolve_category

# Libellés complets des agents économiques (aucune troncature à l'écran).
FULL_AGENT_LABELS: dict[str, str] = {
    "a": "Souverains",
    "b": "Organismes publics hors Administration centrale",
    "c": "Banques multilatérales de développement",
    "d": "Institutions financières",
    "e": "Entreprises",
    "f": "Clientèle de détail",
    "g": "Prêts garantis par l'immobilier résidentiel",
    "h": "Prêts garantis par l'immobilier commercial",
    "i": "Créances en souffrance",
    "j": "Créances à risque élevé",
    "k": "Autres actifs",
}

# Périodes de comparaison proposées (sans historique disponible pour l'instant).
_COMPARISON_PERIODS: tuple[tuple[str, str], ...] = (
    ("previous_month", "Mois précédent"),
    ("previous_quarter", "Trimestre précédent"),
    ("previous_year", "Année précédente"),
)


class _AgentAccumulator:
    """Agrège les montants d'un agent économique en devise de référence (XOF)."""

    __slots__ = ("code", "gross_exposure", "ead", "rwa", "tranches", "counterparties")

    def __init__(self, code: str) -> None:
        self.code = code
        self.gross_exposure = 0.0
        self.ead = 0.0
        self.rwa = 0.0
        # Ventilation par taux de pondération appliqué : rw -> [ead, rwa].
        self.tranches: dict[float, list[float]] = {}
        # Ventilation par contrepartie : nom -> [gross, ead, rwa].
        self.counterparties: dict[str, list[float]] = {}

    def add_tranche(self, risk_weight: float, ead: float, rwa: float) -> None:
        bucket = self.tranches.setdefault(round(risk_weight, 4), [0.0, 0.0])
        bucket[0] += ead
        bucket[1] += rwa

    def add_counterparty(
        self, name: str, gross: float, ead: float, rwa: float
    ) -> None:
        bucket = self.counterparties.setdefault(name, [0.0, 0.0, 0.0])
        bucket[0] += gross
        bucket[1] += ead
        bucket[2] += rwa

    def build_tranches(self) -> list[RwaCreditTranche]:
        return [
            RwaCreditTranche(
                risk_weight=risk_weight,
                exposure=round(values[0], 2),
                rwa=round(values[1], 2),
            )
            for risk_weight, values in sorted(self.tranches.items())
            if values[0] > 0 or values[1] > 0
        ]

    def build_counterparties(self, ratio: float) -> list[RwaCreditCounterparty]:
        """Classe les contreparties de l'agent par RWA décroissant.

        La part (%) est la contribution au RWA de l'agent ; si l'agent n'a
        aucun RWA (ex. pondération 0 %), on retombe sur la part d'EAD.
        """

        rwa_based = self.rwa > 0
        share_basis = self.rwa if rwa_based else self.ead
        ordered = sorted(
            self.counterparties.items(),
            key=lambda item: (-item[1][2], -item[1][1], item[0]),
        )
        rows: list[RwaCreditCounterparty] = []
        for name, (gross, ead, rwa) in ordered:
            share_value = rwa if rwa_based else ead
            rows.append(
                RwaCreditCounterparty(
                    name=name,
                    gross_exposure=round(gross, 2),
                    exposure=round(ead, 2),
                    rwa=round(rwa, 2),
                    capital_required=round(rwa * ratio, 2),
                    share=(share_value / share_basis) if share_basis > 0 else 0.0,
                )
            )
        return rows


def _load_capital_position(rwa_credit: float) -> dict[str, float | bool | None]:
    """Lit les fonds propres et les RWA marché/opérationnel pour la Carte 5.

    Retourne les fonds propres effectifs, le RWA total (crédit + marché +
    opérationnel) et le ratio de solvabilité officiel. Les données de fonds
    propres proviennent du même paramétrage que le tableau de bord.
    """

    with database_manager.read_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM fonds_propres ORDER BY date_analyse DESC LIMIT 1"
        )
        fp_row = cursor.fetchone()
        cursor.execute(
            "SELECT * FROM risque_marche ORDER BY date_analyse DESC LIMIT 1"
        )
        rm_row = cursor.fetchone()

    fp_data = dict(fp_row) if fp_row else {}
    rm_data = dict(rm_row) if rm_row else {}

    fp_calc = calculate_fonds_propres(fp_data)
    # RWA Opérationnel = APR de l'Approche Indicateur de Base (AIB, art. 301
    # BCEAO) — même source que le tableau de bord (voir dashboard/services.py).
    rwa_operationnel = _calcul_aib_uemoa().apr_aib
    rm_calc = resolve_market_capital(rm_data)

    own_funds = float(fp_calc["total_capital"])
    own_funds_available = bool(fp_row) and own_funds > 0
    rwa_total = rwa_credit + rwa_operationnel + float(
        rm_calc["rwa_marche"]
    )
    solvency_ratio = (own_funds / rwa_total) if rwa_total > 0 else None

    return {
        "own_funds": own_funds if own_funds_available else None,
        "own_funds_available": own_funds_available,
        "rwa_total": round(rwa_total, 2),
        "solvency_ratio": solvency_ratio if own_funds_available else None,
    }


def _build_agent_row(
    item: _AgentAccumulator, *, ratio: float, total_rwa: float
) -> RwaCreditAgentRow:
    """Construit une ligne d'agent enrichie (pondération, plage, tranches)."""

    average_weight = (item.rwa / item.ead) if item.ead > 0 else 0.0
    expected = RWA_EXPECTED_WEIGHT_RANGES.get(item.code)
    expected_min = expected[0] if expected else None
    expected_max = expected[1] if expected else None
    out_of_range = False
    if expected is not None and item.ead > 0:
        # Petite tolérance pour absorber les arrondis.
        out_of_range = (
            average_weight < expected_min - 1e-6
            or average_weight > expected_max + 1e-6
        )

    return RwaCreditAgentRow(
        code=item.code,
        label=FULL_AGENT_LABELS.get(item.code, "Autres expositions"),
        gross_exposure=round(item.gross_exposure, 2),
        ead=round(item.ead, 2),
        exposure_total=round(item.ead, 2),
        rwa=round(item.rwa, 2),
        capital_required=round(item.rwa * ratio, 2),
        contribution=(item.rwa / total_rwa) if total_rwa > 0 else 0.0,
        average_weight=average_weight,
        expected_weight_min=expected_min,
        expected_weight_max=expected_max,
        weight_out_of_range=out_of_range,
        rwa_variation=None,
        tranches=item.build_tranches(),
        counterparties=item.build_counterparties(ratio),
    )


def get_rwa_credit_analysis() -> RwaCreditAnalysis:
    """Construit l'analyse RWA Crédit à la dernière date d'arrêté disponible."""

    ratio = settings.capital_ratio
    scope_label = settings.rwa_analysis_scope_label
    threshold = settings.rwa_reconciliation_threshold
    comparison_periods = [
        # Aucun historique multi-dates disponible : variations non calculables.
        RwaCreditComparisonPeriod(key=key, label=label, available=False)
        for key, label in _COMPARISON_PERIODS
    ]

    rows = list_expositions()
    if not rows:
        return RwaCreditAnalysis(
            reference_date=None,
            scope_label=scope_label,
            minimum_capital_ratio=ratio,
            reconciliation_threshold=threshold,
            comparison_periods=comparison_periods,
            totals=RwaCreditTotals(
                gross_exposure=0.0,
                ead=0.0,
                exposure_total=0.0,
                rwa=0.0,
                capital_required=0.0,
            ),
            agents=[],
        )

    reference_date = max(row.analysis_date for row in rows)
    current_rows = [row for row in rows if row.analysis_date == reference_date]

    accumulators: dict[str, _AgentAccumulator] = {}
    for row in current_rows:
        code = resolve_category(row.counterparty.category)["code"]
        accumulator = accumulators.setdefault(code, _AgentAccumulator(code))
        gross_source = (
            row.loan_total_amount
            if row.loan_total_amount is not None
            else row.gross_amount
        )
        ead_source = float(row.ead or 0.0)
        rwa_source = float(row.rwa or 0.0)
        applied_rw = float(row.final_rw or 0.0)
        if applied_rw <= 0:
            applied_rw = float(row.original_rw or 0.0)
        if ead_source <= 0 and rwa_source > 0 and applied_rw > 0:
            # EAD non persistée (import Excel sans colonnes EAD) : reconstituée
            # via l'identité réglementaire RWA = EAD × pondération.
            ead_source = rwa_source / applied_rw
        ead_xof = convert_currency_amount(
            ead_source, from_currency=row.currency, to_currency="XOF"
        )
        rwa_xof = convert_currency_amount(
            rwa_source, from_currency=row.currency, to_currency="XOF"
        )
        gross_xof = convert_currency_amount(
            gross_source, from_currency=row.currency, to_currency="XOF"
        )
        accumulator.gross_exposure += gross_xof
        accumulator.ead += ead_xof
        accumulator.rwa += rwa_xof
        tranche_rw = float(row.final_rw or 0.0)
        if tranche_rw <= 0 and ead_xof > 0 and rwa_xof > 0:
            tranche_rw = rwa_xof / ead_xof
        accumulator.add_tranche(tranche_rw, ead_xof, rwa_xof)
        counterparty_name = str(row.counterparty.name or "").strip()
        accumulator.add_counterparty(
            counterparty_name or "Contrepartie non renseignée",
            gross_xof,
            ead_xof,
            rwa_xof,
        )

    total_gross = sum(item.gross_exposure for item in accumulators.values())
    total_ead = sum(item.ead for item in accumulators.values())
    total_rwa = sum(item.rwa for item in accumulators.values())

    agents = [
        _build_agent_row(item, ratio=ratio, total_rwa=total_rwa)
        for item in accumulators.values()
    ]
    agents.sort(key=lambda agent: agent.rwa, reverse=True)

    capital_required = round(total_rwa * ratio, 2)
    totals = RwaCreditTotals(
        gross_exposure=round(total_gross, 2),
        ead=round(total_ead, 2),
        exposure_total=round(total_ead, 2),
        rwa=round(total_rwa, 2),
        capital_required=capital_required,
    )

    density_rwa = (total_rwa / total_ead) if total_ead > 0 else 0.0

    capital_position = _load_capital_position(total_rwa)
    own_funds = capital_position["own_funds"]
    capital_margin = (
        round(float(own_funds) - capital_required, 2)
        if own_funds is not None
        else None
    )

    return RwaCreditAnalysis(
        reference_date=reference_date,
        scope_label=scope_label,
        minimum_capital_ratio=ratio,
        reconciliation_threshold=threshold,
        comparison_periods=comparison_periods,
        totals=totals,
        agents=agents,
        density_rwa=density_rwa,
        density_trend=[],
        own_funds=own_funds,
        own_funds_available=bool(capital_position["own_funds_available"]),
        capital_margin=capital_margin,
        solvency_ratio=capital_position["solvency_ratio"],
        rwa_total=capital_position["rwa_total"],
        exposure_variation=None,
        rwa_variation=None,
    )
