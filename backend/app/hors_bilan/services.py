"""Services metier du module hors bilan."""

from __future__ import annotations

from app.core.calculations import aggregate_portfolio, calculate_capital, calculate_ead, calculate_rwa
from app.hors_bilan.models import OffBalanceCommitmentCreate, OffBalanceCommitmentView, OffBalanceSummary
from app.referentiels import services as referentiels_service
from database.repositories.exposure_repository import exposure_repository
from database.repositories.off_balance_repository import off_balance_repository


def _to_view(record: dict) -> OffBalanceCommitmentView:
    return OffBalanceCommitmentView(
        id=record["id"],
        analysis_date=record["analysis_date"],
        counterparty_id=record["counterparty_id"],
        counterparty_name=record["counterparty_name"],
        category=record["category"],
        rating=record["rating"],
        engagement_type=record["engagement_type"],
        nominal_amount=record["nominal_amount"],
        ccf=record["ccf"],
        ead=record["ead"],
        risk_weight=record["risk_weight"],
        rwa=record["rwa"],
        capital=record["capital"],
        comment=record.get("comment"),
    )


def _next_commitment_id() -> str:
    return off_balance_repository.next_commitment_id()


def list_commitments(search: str | None = None, engagement_type: str | None = None) -> list[OffBalanceCommitmentView]:
    """Liste les engagements hors bilan avec filtres simples."""

    return [
        _to_view(item)
        for item in off_balance_repository.list_commitments(
            search=search,
            engagement_type=engagement_type,
        )
    ]


def create_commitment(payload: OffBalanceCommitmentCreate) -> OffBalanceCommitmentView:
    """Cree un nouvel engagement hors bilan et le persiste dans SQLite."""

    exposure = exposure_repository.get_exposure(payload.counterparty_id)
    if exposure is None:
        raise ValueError(f"Counterparty {payload.counterparty_id} not found")

    category = str(exposure.get("category_standard", "Entreprises"))
    rating = str(exposure.get("rating", "Non noté"))
    counterparty_name = str(exposure.get("counterparty_name", payload.counterparty_id))

    ccf = referentiels_service.get_ccf(payload.engagement_type)
    risk_weight = referentiels_service.get_risk_weight(category, rating)
    ead = calculate_ead(payload.nominal_amount, ccf)
    rwa = calculate_rwa(ead, risk_weight)
    capital = calculate_capital(rwa)

    record = {
        "id": payload.id or _next_commitment_id(),
        "analysis_date": payload.analysis_date,
        "counterparty_id": payload.counterparty_id,
        "engagement_type": payload.engagement_type,
        "nominal_amount": payload.nominal_amount,
        "ccf": ccf,
        "ead": ead,
        "risk_weight": risk_weight,
        "rwa": rwa,
        "capital": capital,
        "comment": payload.comment,
    }
    off_balance_repository.upsert_commitment(record)
    return _to_view(
        {
            **record,
            "counterparty_name": counterparty_name,
            "category": category,
            "rating": rating,
        }
    )


def get_commitment_summary() -> OffBalanceSummary:
    """Agrege les totaux du portefeuille hors bilan."""

    rows = list_commitments()
    totals = aggregate_portfolio(
        {
            "gross_amount": row.nominal_amount,
            "ead": row.ead,
            "rwa": row.rwa,
            "capital": row.capital,
        }
        for row in rows
    )
    return OffBalanceSummary(
        total_engagements=totals["gross_amount"],
        total_ead=totals["ead"],
        total_rwa=totals["rwa"],
        total_capital=totals["capital"],
    )
