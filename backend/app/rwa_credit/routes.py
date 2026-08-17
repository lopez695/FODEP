"""Routes API du module d'analyse RWA Crédit."""

from __future__ import annotations

from fastapi import APIRouter

from app.rwa_credit.models import RwaCreditAnalysis
from app.rwa_credit.services import get_rwa_credit_analysis

router = APIRouter(prefix="/rwa-credit", tags=["RWA Crédit"])


@router.get("/analyse", response_model=RwaCreditAnalysis)
def get_analyse() -> RwaCreditAnalysis:
    """Retourne l'agrégation de l'onglet « Analyse RWA Crédit »."""

    return get_rwa_credit_analysis()
