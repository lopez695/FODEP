"""Routes API du module dashboard."""

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import Response

from app.dashboard.models import DashboardSnapshot, FondsPropresUpdate
from app.dashboard.services import (
    build_fonds_propres_import_template,
    delete_fonds_propres_exercice,
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


@router.delete("/fonds-propres/{exercice}", response_model=DashboardSnapshot)
def supprimer_exercice_fp(exercice: int) -> DashboardSnapshot:
    """Retire un exercice de l'historique des fonds propres."""
    try:
        return delete_fonds_propres_exercice(exercice)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)
        ) from exc


@router.get("/fonds-propres/import/template")
def download_fonds_propres_import_template() -> Response:
    """Télécharge le modèle Excel d'import des Fonds Propres Réglementaires."""
    template_bytes = build_fonds_propres_import_template()
    return Response(
        content=template_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=modele_import_fonds_propres.xlsx"},
    )
