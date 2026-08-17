"""Services d'accès aux tables prudentielles."""

from __future__ import annotations

from database.repositories.referential_repository import referential_repository
from app.referentiels.models import ReferentialBundle, ReferentialBundleUpdate


def get_risk_weight(segment: str, rating: str) -> float:
    """Recherche la pondération RW pour un segment et une note."""

    return referential_repository.get_risk_weight(segment, rating)


def get_ccf(engagement_type: str) -> float:
    """Recherche le CCF à appliquer à un engagement hors bilan."""

    return referential_repository.get_ccf(engagement_type)


def get_referential_bundle() -> ReferentialBundle:
    """Construit le paquet complet de référentiels."""

    return referential_repository.get_referential_bundle()


def replace_referential_bundle(payload: ReferentialBundleUpdate) -> ReferentialBundle:
    """Remplace integralement les baremes prudentiels configures."""

    referential_repository.replace_all(
        risk_weights=[item.model_dump() for item in payload.risk_weights],
        ccf_table=[item.model_dump() for item in payload.ccf_table],
        ratings=[item.model_dump() for item in payload.ratings],
        country_ratings=[item.model_dump() for item in payload.country_ratings],
    )
    return referential_repository.get_referential_bundle()
