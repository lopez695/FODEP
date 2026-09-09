"""Routes API des dispositions transitoires sur les fonds propres."""

from fastapi import APIRouter, status

from app.dispositions_transitoires.models import (
    DispositionsTransitoiresUpdate,
    DispositionsTransitoiresView,
)
from app.dispositions_transitoires.services import (
    enregistrer_dispositions,
    lire_dispositions,
    supprimer_dispositions,
)

router = APIRouter(
    prefix="/dispositions-transitoires", tags=["Dispositions transitoires"]
)


@router.get("", response_model=DispositionsTransitoiresView | None)
def get_dispositions(exercice: int | None = None) -> DispositionsTransitoiresView | None:
    """Les dispositions d'un exercice, ou du plus recent a defaut.

    Rend `null` quand rien n'a ete saisi : « rien n'a ete declare » et « tout
    vaut zero » ne se lisent pas de la meme facon, et l'ecran doit pouvoir les
    distinguer.

    L'apercu de l'etat EP04 qu'elles alimentent est sur
    « /rapports/fodep/ep04 » : il applique le taux de retrait imprime par la
    BCEAO, que seul le module de reporting relit dans le formulaire.
    """

    return lire_dispositions(exercice)


@router.put("", response_model=DispositionsTransitoiresView)
def put_dispositions(
    payload: DispositionsTransitoiresUpdate,
) -> DispositionsTransitoiresView:
    return enregistrer_dispositions(payload)


@router.delete("/{exercice}", status_code=status.HTTP_204_NO_CONTENT)
def delete_dispositions(exercice: int) -> None:
    supprimer_dispositions(exercice)
