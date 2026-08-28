"""Routes API du module ICAAP / PIEAFP."""

from __future__ import annotations

from fastapi import APIRouter

from app.icaap.models import CapitalReglementaire, CycleIcaap, StatutCycleUpdate
from app.icaap.services import capital_reglementaire, changer_statut

router = APIRouter(prefix="/icaap", tags=["ICAAP"])


@router.get("/capital-reglementaire", response_model=CapitalReglementaire)
def get_capital_reglementaire() -> CapitalReglementaire:
    """Le socle Pilier 1 sur lequel le PIEAFP vient se greffer."""

    return capital_reglementaire()


@router.put("/exercices/{exercice}/statut", response_model=CycleIcaap)
def put_statut(exercice: int, demande: StatutCycleUpdate) -> CycleIcaap:
    """Fait avancer le cycle annuel du PIEAFP d'une etape."""

    return changer_statut(exercice, demande)
