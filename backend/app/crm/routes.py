"""Routes API du module CRM."""

from fastapi import APIRouter, HTTPException, Query, status

from app.crm.models import CRMOverview, GuaranteeCreate, GuaranteeView
from app.crm.services import create_guarantee, get_crm_overview, list_guarantees

router = APIRouter(prefix="/crm", tags=["CRM"])


@router.get("", response_model=CRMOverview)
def get_crm() -> CRMOverview:
    """Retourne la vue globale du module CRM."""

    return get_crm_overview()


@router.get("/items", response_model=list[GuaranteeView])
def get_crm_items(
    search: str | None = Query(default=None),
    guarantee_type: str | None = Query(default=None),
) -> list[GuaranteeView]:
    """Retourne les lignes CRM avec filtres simples."""

    return list_guarantees(search=search, guarantee_type=guarantee_type)


@router.post("", response_model=GuaranteeView, status_code=status.HTTP_201_CREATED)
def post_crm(payload: GuaranteeCreate) -> GuaranteeView:
    """Cree une garantie CRM."""

    try:
        return create_guarantee(payload)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
