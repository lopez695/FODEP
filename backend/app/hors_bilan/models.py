"""Modeles du module hors bilan."""

from datetime import date

from pydantic import BaseModel, Field


class OffBalanceCommitmentCreate(BaseModel):
    """Represente la saisie d'un engagement hors bilan."""

    id: str | None = Field(default=None, description="Identifiant optionnel de l'engagement.")
    analysis_date: date = Field(..., description="Date d'analyse.")
    counterparty_id: str = Field(..., description="Identifiant de la contrepartie.")
    engagement_type: str = Field(..., description="Nature de l'engagement.")
    nominal_amount: float = Field(..., description="Montant nominal de l'engagement.")
    comment: str | None = Field(default=None, description="Commentaire de suivi.")


class OffBalanceCommitmentView(BaseModel):
    """Represente un engagement hors bilan avec calculs EAD et RWA."""

    id: str
    analysis_date: date
    counterparty_id: str
    counterparty_name: str
    category: str
    rating: str
    engagement_type: str
    nominal_amount: float
    ccf: float
    ead: float
    risk_weight: float
    rwa: float
    capital: float
    comment: str | None = None


class OffBalanceSummary(BaseModel):
    """Represente les totaux du portefeuille hors bilan."""

    total_engagements: float
    total_ead: float
    total_rwa: float
    total_capital: float
