"""Routes API du module hors bilan."""

from fastapi import APIRouter, HTTPException, Query, status

from app.hors_bilan.models import (
    OffBalanceCommitmentCreate,
    OffBalanceCommitmentView,
    OffBalanceSummary,
)
from app.hors_bilan.services import create_commitment, get_commitment_summary, list_commitments

router = APIRouter(prefix="/hors-bilan", tags=["Hors Bilan"])


@router.get("", response_model=list[OffBalanceCommitmentView])
def get_hors_bilan(
    search: str | None = Query(default=None),
    engagement_type: str | None = Query(default=None),
) -> list[OffBalanceCommitmentView]:
    """Retourne les engagements hors bilan."""

    return list_commitments(search=search, engagement_type=engagement_type)


@router.post("", response_model=OffBalanceCommitmentView, status_code=status.HTTP_201_CREATED)
def post_hors_bilan(payload: OffBalanceCommitmentCreate) -> OffBalanceCommitmentView:
    """Cree un engagement hors bilan."""

    try:
        return create_commitment(payload)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/summary", response_model=OffBalanceSummary)
def get_hors_bilan_summary() -> OffBalanceSummary:
    """Retourne les agregats du portefeuille hors bilan."""

    return get_commitment_summary()
