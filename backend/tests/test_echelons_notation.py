"""Les ecrans affichent des echelons de notation, jamais les cles du moteur.

Les grilles de ponderation sont indexees par des cles courtes ("AAA/AA",
"BB/B") : ce vocabulaire de code n'existe dans aucun texte prudentiel. Laisse
fuir a l'ecran, il decredibilise un rapport lu par un superviseur.
"""

from __future__ import annotations

import pytest

from app.core.calculations import (
    PRUDENTIAL_RATING_LABELS,
    bucketize_rating,
    prudential_rating_label,
)
from app.dashboard.services import get_dashboard_snapshot

_CLES_INTERNES = {"AAA/AA", "BB/B"}
_ECHELONS = set(PRUDENTIAL_RATING_LABELS.values())


@pytest.fixture(scope="module")
def snapshot():
    return get_dashboard_snapshot()


@pytest.mark.parametrize(
    ("notation", "attendu"),
    [
        ("AA-", "AAA à AA-"),
        ("A+", "A+ à A-"),
        ("BBB", "BBB+ à BBB-"),
        ("BB-", "BB+ à B-"),
        ("B-", "BB+ à B-"),
        ("< B-", "Inférieur à B-"),
        ("", "Non noté"),
    ],
)
def test_chaque_notation_devient_un_echelon_lisible(notation, attendu):
    assert prudential_rating_label(notation) == attendu


def test_un_echelon_deja_affiche_retrouve_son_bucket():
    # Sans ce chemin retour, une valeur relue depuis un ecran ou un export
    # retomberait en « Non noté » et changerait la ponderation.
    for bucket in _CLES_INTERNES:
        libelle = prudential_rating_label(bucket)
        assert bucketize_rating(libelle) == bucket


def test_le_portefeuille_servi_ne_contient_aucune_cle_interne(snapshot):
    # « A », « BBB » et « < B- » sont aussi des notations reelles du jeu de
    # donnees : seules les deux cles composites trahissent a coup sur une
    # fuite du vocabulaire interne.
    for row in snapshot.portfolio_overview:
        assert row.rating not in _CLES_INTERNES, (
            f"{row.id} : la cle interne « {row.rating} » est affichee comme "
            "notation de la contrepartie."
        )
        assert row.rating_band not in _CLES_INTERNES, (
            f"{row.id} : la cle interne « {row.rating_band} » est servie telle "
            "quelle au tableau de bord."
        )
        assert row.guarantor_rating_band not in _CLES_INTERNES


def test_la_note_de_la_contrepartie_reste_sa_note(snapshot):
    """L'echelon ne remplace pas la notation, il l'accompagne.

    Afficher « BBB+ a BBB- » pour une contrepartie notee BBB- laisse croire
    qu'elle n'a pas de note precise, alors que la donnee existe.
    """

    notees = [
        row
        for row in snapshot.portfolio_overview
        if row.rating not in {"Non noté", ""}
    ]
    if not notees:
        pytest.skip("Aucune contrepartie notee dans ce jeu de donnees.")
    for row in notees:
        assert row.rating not in _ECHELONS, (
            f"{row.id} : l'echelon « {row.rating} » a ecrase la notation de "
            "la contrepartie."
        )
        assert row.rating_band in _ECHELONS
        # La note doit rester coherente avec son echelon.
        assert prudential_rating_label(row.rating) == row.rating_band


def test_la_repartition_par_notation_ne_contient_aucune_cle_interne(snapshot):
    for entry in snapshot.rating_distribution:
        assert entry.label not in _CLES_INTERNES


def test_les_plus_grosses_expositions_non_plus(snapshot):
    for exposure in snapshot.top10_exposures:
        assert exposure.rating not in _CLES_INTERNES
