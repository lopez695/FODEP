"""Routes API du suivi des participations."""

from fastapi import APIRouter, status

from app.participations.models import (
    ParticipationCreate,
    ParticipationUpdate,
    ParticipationView,
    SyntheseParticipationsDetaillee,
)
from app.participations.services import (
    creer_participation,
    lister_participations,
    modifier_participation,
    supprimer_participation,
    synthese_detaillee,
)

router = APIRouter(prefix="/participations", tags=["Participations"])


@router.get("", response_model=list[ParticipationView])
def get_participations() -> list[ParticipationView]:
    """Liste les participations, groupees par categorie de l'EP34."""

    return lister_participations()


# Declaree avant « /{identifiant} » n'aurait pas d'importance ici, les autres
# routes a segment variable n'etant pas en GET : l'ordre reste neanmoins celui
# du plus specifique au plus general.
@router.get("/synthese", response_model=SyntheseParticipationsDetaillee)
def get_synthese_participations() -> SyntheseParticipationsDetaillee:
    """Totaux, fonds propres, immobilisations et les cinq limites de l'EP01."""

    return synthese_detaillee()


@router.post("", response_model=ParticipationView, status_code=status.HTTP_201_CREATED)
def post_participation(payload: ParticipationCreate) -> ParticipationView:
    return creer_participation(payload)


@router.put("/{identifiant}", response_model=ParticipationView)
def put_participation(
    identifiant: int, payload: ParticipationUpdate
) -> ParticipationView:
    return modifier_participation(identifiant, payload)


@router.delete("/{identifiant}", status_code=status.HTTP_204_NO_CONTENT)
def delete_participation(identifiant: int) -> None:
    supprimer_participation(identifiant)
