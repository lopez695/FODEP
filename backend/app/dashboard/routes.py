"""Routes API du module dashboard."""

from fastapi import APIRouter
from fastapi.responses import Response

from app.dashboard.models import DashboardSnapshot, FondsPropresUpdate
from app.dashboard.services import (
    build_fonds_propres_import_template,
    get_dashboard_snapshot,
    update_fonds_propres,
)

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("", response_model=DashboardSnapshot)
def get_dashboard() -> DashboardSnapshot:
    """Retourne la vue complete du dashboard."""

    return get_dashboard_snapshot()

@router.put("/fonds-propres", response_model=DashboardSnapshot)
def update_fp(data: FondsPropresUpdate) -> DashboardSnapshot:
    """Met a jour manuellement les fonds propres et retourne le nouveau dashboard."""
    return update_fonds_propres(data)


@router.get("/fonds-propres/import/template")
def download_fonds_propres_import_template() -> Response:
    """Télécharge le modèle Excel d'import des Fonds Propres Réglementaires."""
    template_bytes = build_fonds_propres_import_template()
    return Response(
        content=template_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=modele_import_fonds_propres.xlsx"},
    )
