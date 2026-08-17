"""L'ecran Referentiels doit montrer les grilles reellement appliquees.

La migration 021 renommait les tables anglaises en francais. Comme
`schema.sql` s'execute AVANT les migrations et cree deja les tables
francaises, le renommage echouait sur « une table de ce nom existe deja » --
erreur volontairement toleree pour rendre les migrations rejouables. Les
donnees restaient donc dans les tables anglaises et l'ecran affichait des
listes vides.

Rien ne le signalait : le moteur de calcul porte ses propres grilles et
continuait de ponderer correctement.
"""

from __future__ import annotations

import pytest

from database.connection import database_manager
from database.repositories.referential_repository import referential_repository


@pytest.fixture(scope="module", autouse=True)
def base_initialisee():
    database_manager.initialize()


def test_les_ponderations_sont_visibles():
    references = referential_repository.list_risk_weight_references()
    assert references, (
        "L'ecran Referentiels n'affiche aucune ponderation : les baremes sont "
        "restes dans les tables d'avant le renommage."
    )


def test_les_facteurs_de_conversion_sont_visibles():
    assert referential_repository.list_ccf_references()


def test_les_notations_sont_visibles():
    assert referential_repository.list_rating_references()


def test_le_rapatriement_ne_recopie_pas_par_dessus_l_existant():
    """Une table deja alimentee fait foi, meme corrigee a la main."""

    avant = len(referential_repository.list_risk_weight_references())
    database_manager.initialize()
    apres = len(referential_repository.list_risk_weight_references())
    assert apres == avant, (
        "Un second demarrage a duplique les baremes : le rapatriement doit "
        "ne remplir que le vide."
    )


def test_les_ponderations_couvrent_les_segments_du_dispositif():
    references = referential_repository.list_risk_weight_references()
    segments = {reference.segment for reference in references}
    assert len(segments) >= 5, (
        f"Seuls {len(segments)} segments sont exposes : la reprise semble "
        "partielle."
    )
    for reference in references:
        assert 0.0 <= reference.risk_weight <= 15.0, (
            f"Ponderation hors de toute echelle prudentielle : "
            f"{reference.segment} {reference.rating} = {reference.risk_weight}"
        )
