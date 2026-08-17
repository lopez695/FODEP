"""Modeles du module CRM."""

from pydantic import BaseModel, Field


class GuaranteeCreate(BaseModel):
    """Represente la saisie d'une garantie CRM."""

    id: str | None = Field(default=None, description="Identifiant optionnel de la garantie.")
    exposure_id: str = Field(..., description="Identifiant de l'exposition couverte.")
    guarantor_name: str = Field(..., description="Nom du garant.")
    guarantor_category: str = Field(..., description="Categorie prudentielle du garant.")
    guarantor_rating: str = Field(..., description="Notation du garant.")
    coverage_amount: float = Field(..., description="Montant couvert par la garantie.")
    guarantee_type: str = Field(..., description="Nature de la technique CRM.")
    scenario_type: str = Field(..., description="Libelle du scenario CRM.")


class GuaranteeView(BaseModel):
    """Represente une ligne CRM avant et apres effet de mitigation."""

    id: str
    exposure_id: str
    borrower_name: str
    borrower_category: str
    borrower_rating: str
    gross_amount: float
    guarantor_name: str
    guarantor_category: str
    guarantor_rating: str
    guarantee_type: str
    coverage_amount: float
    coverage_ratio: float
    borrower_rw: float
    guarantor_rw: float
    final_rw: float
    ead: float
    rwa_before: float
    rwa_after: float
    capital_before: float
    capital_after: float
    rwa_reduction: float
    capital_saving: float


class CRMHighlight(BaseModel):
    """Represente le scenario principal affiche en tete d'ecran."""

    borrower_name: str
    borrower_rw: float
    guarantor_name: str
    guarantor_rw: float
    final_rw: float
    label: str


class CRMSummary(BaseModel):
    """Represente les agregats CRM de portefeuille."""

    total_expositions: float
    total_ead: float
    total_rwa_before: float
    total_rwa_after: float
    total_capital_after: float
    average_coverage: float


class CRMOverview(BaseModel):
    """Represente la vue globale du module CRM."""

    highlight: CRMHighlight | None
    items: list[GuaranteeView]
    summary: CRMSummary
