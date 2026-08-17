"""Modeles du module referentiels."""

from pydantic import BaseModel, Field


class RiskWeightReference(BaseModel):
    """Represente une ligne de table de ponderation RW."""

    id: str = Field(..., description="Identifiant de la ligne de referentiel.")
    segment: str = Field(..., description="Segment prudentiel concerne.")
    rating: str = Field(..., description="Bucket de notation.")
    risk_weight: float = Field(..., description="Ponderation prudentielle.")
    approach: str = Field(..., description="Approche reglementaire utilisee.")


class CcfReference(BaseModel):
    """Represente une ligne de table CCF."""

    id: str = Field(..., description="Identifiant de la ligne CCF.")
    engagement_type: str = Field(..., description="Nature de l'engagement.")
    ccf: float = Field(..., description="Facteur de conversion de credit.")


class RatingReference(BaseModel):
    """Represente une note disponible dans l'application."""

    id: str = Field(..., description="Identifiant de la notation.")
    label: str = Field(..., description="Libelle de la note.")
    description: str = Field(..., description="Description simple de la note.")
    sort_order: int = Field(..., description="Ordre d'affichage de la note.")


class ReferentialBundle(BaseModel):
    """Regroupe les referentiels exposes au frontend."""

    risk_weights: list[RiskWeightReference]
    ccf_table: list[CcfReference]
    ratings: list[RatingReference]


class RiskWeightReferenceInput(BaseModel):
    """Ligne de bareme de ponderation a persister."""

    id: str
    segment: str
    rating: str
    risk_weight: float
    approach: str


class CcfReferenceInput(BaseModel):
    """Ligne de bareme CCF a persister."""

    id: str
    engagement_type: str
    ccf: float


class RatingReferenceInput(BaseModel):
    """Ligne de notation a persister."""

    id: str
    label: str
    description: str
    sort_order: int


class CountryRatingReferenceInput(BaseModel):
    """Ligne de notation souveraine par pays a persister."""

    country: str
    sovereign_rating: str
    risk_weight: float


class ReferentialBundleUpdate(BaseModel):
    """Payload de remplacement complet des referentiels prudentiels.

    Remplace integralement le contenu des 4 tables (delete puis insert),
    conformement au comportement de ReferentialRepository.replace_all.
    """

    risk_weights: list[RiskWeightReferenceInput] = Field(default_factory=list)
    ccf_table: list[CcfReferenceInput] = Field(default_factory=list)
    ratings: list[RatingReferenceInput] = Field(default_factory=list)
    country_ratings: list[CountryRatingReferenceInput] = Field(default_factory=list)
