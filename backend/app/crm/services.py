"""Services metier du module CRM."""

from __future__ import annotations

from datetime import date

from app.core.calculations import aggregate_portfolio, safe_ratio
from app.crm.models import CRMHighlight, CRMOverview, CRMSummary, GuaranteeCreate, GuaranteeView
from app.expositions.models import ExposureCreate, ExposureCrmDetails
from database.repositories.crm_repository import crm_repository
from database.repositories.exposure_repository import exposure_repository
from database.services.rwa_calculation_service import build_exposure_record


def _to_view(record: dict) -> GuaranteeView:
    return GuaranteeView(
        id=record["id"],
        exposure_id=record["exposure_id"],
        borrower_name=record["borrower_name"],
        borrower_category=record["borrower_category"],
        borrower_rating=record["borrower_rating"],
        gross_amount=record["gross_amount"],
        guarantor_name=record["guarantor_name"],
        guarantor_category=record["guarantor_category"],
        guarantor_rating=record["guarantor_rating"],
        guarantee_type=record["guarantee_type"],
        coverage_amount=record["coverage_amount"],
        coverage_ratio=record["coverage_ratio"],
        borrower_rw=record["borrower_rw"],
        guarantor_rw=record["guarantor_rw"],
        final_rw=record["final_rw"],
        ead=record["ead"],
        rwa_before=record["rwa_before"],
        rwa_after=record["rwa_after"],
        capital_before=record["capital_before"],
        capital_after=record["capital_after"],
        rwa_reduction=record["rwa_reduction"],
        capital_saving=record["capital_saving"],
    )


def _parse_analysis_date(value: object) -> date:
    if isinstance(value, date):
        return value
    return date.fromisoformat(str(value))


def list_guarantees(search: str | None = None, guarantee_type: str | None = None) -> list[GuaranteeView]:
    """Liste les scenarios CRM avec filtres simples."""

    return [
        _to_view(item)
        for item in crm_repository.list_guarantees(
            search=search,
            guarantee_type=guarantee_type,
        )
    ]


def create_guarantee(payload: GuaranteeCreate) -> GuaranteeView:
    """Cree une garantie CRM en mettant a jour l'exposition sous-jacente."""

    exposure = exposure_repository.get_exposure(payload.exposure_id)
    if exposure is None:
        raise ValueError(f"Exposure {payload.exposure_id} not found")

    gross_amount = float(exposure.get("gross_amount", 0.0) or 0.0)
    coverage_ratio = 0.0 if gross_amount == 0 else min(payload.coverage_amount / gross_amount, 1.0)

    update_payload = ExposureCreate(
        id=payload.exposure_id,
        analysis_date=_parse_analysis_date(exposure["analysis_date"]),
        counterparty_name=str(exposure["counterparty_name"]),
        country=str(exposure["country"]),
        country_rating=str(exposure.get("country_rating") or "Non noté"),
        category=str(exposure.get("category_raw") or exposure.get("category_standard") or "Entreprises"),
        rating=str(exposure["rating"]),
        gross_amount=gross_amount,
        currency=str(exposure.get("currency") or "XOF"),
        status=str(exposure.get("status") or "Active"),
        crm_type=payload.guarantee_type,
        crm_coverage_percent=coverage_ratio,
        crm_details=ExposureCrmDetails(
            mode="CRM non financee",
            label=payload.scenario_type or payload.guarantee_type,
            guarantor_name=payload.guarantor_name,
            guarantor_category=payload.guarantor_category,
            guarantor_rating=payload.guarantor_rating,
            coverage_percent=coverage_ratio,
        ),
        comment=exposure.get("comment"),
    )
    updated_record = build_exposure_record(update_payload, payload.exposure_id)
    exposure_repository.upsert_exposure(updated_record)

    guarantee = next(
        (
            item
            for item in crm_repository.list_guarantees()
            if item["exposure_id"] == payload.exposure_id
        ),
        None,
    )
    if guarantee is None:
        raise ValueError(f"Unable to create CRM guarantee for exposure {payload.exposure_id}")
    return _to_view(guarantee)


def get_crm_overview() -> CRMOverview:
    """Construit la vue globale du module CRM."""

    rows = list_guarantees()
    totals = aggregate_portfolio(
        {
            "gross_amount": row.gross_amount,
            "ead": row.ead,
            "rwa": row.rwa_after,
            "capital": row.capital_after,
        }
        for row in rows
    )
    total_before = sum(item.rwa_before for item in rows)
    average_coverage = safe_ratio(sum(item.coverage_amount for item in rows), totals["gross_amount"])

    highlight = None
    if rows:
        best_row = max(rows, key=lambda item: item.rwa_reduction)
        highlight = CRMHighlight(
            borrower_name=best_row.borrower_name,
            borrower_rw=best_row.borrower_rw,
            guarantor_name=best_row.guarantor_name,
            guarantor_rw=best_row.guarantor_rw,
            final_rw=best_row.final_rw,
            label="RWA reduit",
        )

    return CRMOverview(
        highlight=highlight,
        items=rows,
        summary=CRMSummary(
            total_expositions=totals["gross_amount"],
            total_ead=totals["ead"],
            total_rwa_before=round(total_before, 2),
            total_rwa_after=totals["rwa"],
            total_capital_after=totals["capital"],
            average_coverage=average_coverage,
        ),
    )
