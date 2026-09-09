"""Routes API du registre des instruments derives."""

from fastapi import APIRouter, status

from app.derives.models import DeriveCreate, DeriveUpdate, DeriveView
from app.derives.services import (
    creer_derive,
    lister_derives,
    modifier_derive,
    supprimer_derive,
)

router = APIRouter(prefix="/derives", tags=["Derives"])


@router.get("", response_model=list[DeriveView])
def get_derives() -> list[DeriveView]:
    """Liste les contrats derives, par nature puis par echeance.

    L'apercu de l'etat EP11 qu'ils alimentent n'est pas ici mais sur
    « /rapports/fodep/ep11 » : il applique les ponderations imprimees par la
    BCEAO, que seul le module de reporting relit dans le formulaire.
    """

    return lister_derives()


@router.post("", response_model=DeriveView, status_code=status.HTTP_201_CREATED)
def post_derive(payload: DeriveCreate) -> DeriveView:
    return creer_derive(payload)


@router.put("/{identifiant}", response_model=DeriveView)
def put_derive(identifiant: int, payload: DeriveUpdate) -> DeriveView:
    return modifier_derive(identifiant, payload)


@router.delete("/{identifiant}", status_code=status.HTTP_204_NO_CONTENT)
def delete_derive(identifiant: int) -> None:
    supprimer_derive(identifiant)
