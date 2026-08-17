"""Routes API des groupes de clients lies."""

from fastapi import APIRouter, status

from app.groupes_clients.models import (
    ContrepartieView,
    GroupeCreate,
    GroupeUpdate,
    GroupeView,
    RattachementUpdate,
)
from app.groupes_clients.concentration import calculer_concentration
from app.groupes_clients.services import (
    creer_groupe,
    lister_contreparties,
    lister_groupes,
    modifier_groupe,
    rattacher_contrepartie,
    supprimer_groupe,
)

router = APIRouter(prefix="/groupes-clients", tags=["Groupes de clients lies"])


@router.get("", response_model=list[GroupeView])
def get_groupes() -> list[GroupeView]:
    """Liste les groupes et leurs membres."""

    return lister_groupes()


@router.post("", response_model=GroupeView, status_code=status.HTTP_201_CREATED)
def post_groupe(payload: GroupeCreate) -> GroupeView:
    return creer_groupe(payload)


@router.put("/{identifiant}", response_model=GroupeView)
def put_groupe(identifiant: int, payload: GroupeUpdate) -> GroupeView:
    return modifier_groupe(identifiant, payload)


@router.delete("/{identifiant}", status_code=status.HTTP_204_NO_CONTENT)
def delete_groupe(identifiant: int) -> None:
    """Supprime le groupe et detache ses membres, sans les effacer."""

    supprimer_groupe(identifiant)


@router.get("/concentration")
def get_concentration() -> dict:
    """Concentration des risques par groupe, du plus lourd au plus leger.

    Les montants sont ceux des etats EP29 a EP32 : deux ecrans qui montreraient
    des chiffres differents pour la meme notion ne seraient credibles ni l'un
    ni l'autre.
    """

    return calculer_concentration()


@router.get("/contreparties/liste", response_model=list[ContrepartieView])
def get_contreparties(sans_groupe: bool = False) -> list[ContrepartieView]:
    """Contreparties du portefeuille, filtrables sur celles sans groupe."""

    return lister_contreparties(sans_groupe=sans_groupe)


@router.put("/contreparties/{identifiant}", response_model=ContrepartieView)
def put_rattachement(
    identifiant: str, payload: RattachementUpdate
) -> ContrepartieView:
    """Rattache une contrepartie a un groupe et complete son identification."""

    return rattacher_contrepartie(identifiant, payload)
