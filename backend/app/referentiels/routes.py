"""Routes API du module referentiels."""

from fastapi import APIRouter

from app.referentiels.models import ReferentialBundle, ReferentialBundleUpdate
from app.referentiels.services import get_referential_bundle, replace_referential_bundle

router = APIRouter(prefix="/referentiels", tags=["Referentiels"])


@router.get("", response_model=ReferentialBundle)
def get_referentiels() -> ReferentialBundle:
    """Expose les tables prudentielles au frontend."""

    return get_referential_bundle()


@router.put("", response_model=ReferentialBundle)
def put_referentiels(payload: ReferentialBundleUpdate) -> ReferentialBundle:
    """Remplace integralement les baremes prudentiels (ponderation, CCF, notations).

    Tant qu'aucun ecran Flutter dedie n'est reconstruit (voir memoire, 4.3.13),
    ce point d'acces reste utilisable directement via /docs pour configurer
    les referentiels et debloquer le module hors bilan.
    """

    return replace_referential_bundle(payload)
