"""L'exces d'une limite prudentielle, et ce qu'il retranche des fonds propres.

Le formulaire imprime ses formules en tete de colonne : l'EP35 annonce
« g = Max[0 ; a x (d - 25%)] », « i = max(g ; h) », « k = Max (total i ; j) ».
Ce sont elles que ce module doit rendre, et non une approximation qui leur
ressemblerait -- un exces surestime sort du capital qui n'avait pas a en
sortir, un exces sous-estime laisse passer une declaration fausse.
"""

from __future__ import annotations

import pytest

from app.core.bceao_calculations import calculate_fonds_propres
from app.core.limites_prudentielles import (
    ExcedentsDeLimites,
    excedent_immobilisations,
    excedent_immobilisations_participations,
    excedent_participations,
    excedent_parties_liees,
)


def test_une_limite_respectee_ne_retranche_rien():
    """Sous le plafond, il n'y a pas d'exces -- pas meme un arrondi."""

    assert excedent_immobilisations(140.0, 0.0, 1_000.0) == 0.0
    assert excedent_immobilisations_participations(600.0, 399.0, 1_000.0) == 0.0
    assert excedent_parties_liees(199.0, 1_000.0) == 0.0


def test_l_exces_est_le_depassement_du_plafond_et_rien_de_plus():
    """Ce qui sort des fonds propres, c'est la part au-dela de la limite.

    Non l'encours entier : un etablissement qui detient 17 % d'immobilisations
    hors exploitation pour un plafond de 15 % n'en perd pas dix-sept, il en
    perd deux.
    """

    assert excedent_immobilisations(170.0, 0.0, 1_000.0) == pytest.approx(20.0)
    assert excedent_immobilisations_participations(
        900.0, 250.0, 1_000.0
    ) == pytest.approx(150.0)
    assert excedent_parties_liees(280.0, 1_000.0) == pytest.approx(80.0)


def test_un_denominateur_absent_ne_vaut_pas_limite_respectee():
    """Sans fonds propres de reference, la limite n'est pas mesurable.

    Le calcul rend zero -- il n'y a rien d'autre a rendre -- mais c'est
    `mesures` qui porte la nuance, et l'appelant doit la dire.
    """

    assert excedent_parties_liees(1_000.0, 0.0) == 0.0
    assert not ExcedentsDeLimites().mesures
    assert ExcedentsDeLimites(exercice_precedent=2025).mesures


def test_les_deux_limites_individuelles_ne_se_cumulent_pas():
    """i = max(g ; h), et non g + h.

    Une participation qui depasse a la fois les 25 % du capital de son
    emetteur et les 15 % des fonds propres de base ne se deduit qu'une fois :
    c'est la contrainte la plus mordante qui vaut. Les additionner
    retrancherait du capital deux fois pour un seul depassement.
    """

    # Capital emetteur 100, souscription 40 : g = 40 - 25 = 15.
    # Fonds propres T1 100, montant net 40 : h = 40 - 15 = 25.
    excedent = excedent_participations([(100.0, 40.0, 40.0)], 100.0, 1_000.0)
    (g, h, i), = excedent.par_entite
    assert (g, h) == pytest.approx((15.0, 25.0))
    assert i == pytest.approx(25.0)
    assert excedent.a_deduire == pytest.approx(25.0)


def test_la_limite_globale_ne_s_ajoute_pas_aux_individuelles():
    """k = Max(total des i ; j), et non leur somme.

    Le meme encours fonde les deux mesures : les additionner reviendrait a
    deduire deux fois le meme depassement.
    """

    # Deux participations de 40 sur des emetteurs de capital 200 : aucune
    # individuelle ne mord (40 < 25 % de 200, et 40 < 15 % de 400).
    entites = [(200.0, 40.0, 40.0), (200.0, 40.0, 40.0)]
    # Total net 80 pour des fonds propres effectifs de 100 : j = 80 - 60 = 20.
    excedent = excedent_participations(entites, 400.0, 100.0)

    assert [i for _, _, i in excedent.par_entite] == [0.0, 0.0]
    assert excedent.exces_global == pytest.approx(20.0)
    assert excedent.a_deduire == pytest.approx(20.0)


def test_une_participation_sans_capital_d_emetteur_n_invente_pas_d_exces():
    """La part du capital detenu ne se calcule pas sans son denominateur.

    L'EP35 laisse alors la colonne vide, et l'export le signale. Rendre un
    exces ici reviendrait a deduire du capital sur une donnee manquante.
    """

    excedent = excedent_participations([(0.0, 500.0, 500.0)], 10_000.0, 10_000.0)
    (g, _, _), = excedent.par_entite
    assert g == 0.0


def test_la_deduction_sort_des_fonds_propres_de_base():
    """Les quatre lignes s'additionnent, et le CET1 baisse d'autant.

    C'est l'objet de tout le calcul : sans cette soustraction, le CET1 declare
    et les trois ratios de solvabilite sont surestimes.
    """

    excedents = ExcedentsDeLimites(
        participations=10.0,
        immobilisations=20.0,
        immobilisations_participations=30.0,
        parties_liees=40.0,
        exercice_precedent=2025,
    )
    assert excedents.total == pytest.approx(100.0)
    assert set(excedents.par_code_dispru()) == {"PA149", "IM006", "IM010", "PR004"}

    saisies = {"capital_ordinaire": 1_000.0}
    sans = calculate_fonds_propres(saisies)
    avec = calculate_fonds_propres(saisies, excedents.total)
    assert sans["cet1"] - avec["cet1"] == pytest.approx(100.0)
    # Et le Tier 1 comme le total suivent : la deduction porte sur le CET1,
    # dont ils derivent.
    assert sans["t1"] - avec["t1"] == pytest.approx(100.0)
    assert sans["total_capital"] - avec["total_capital"] == pytest.approx(100.0)


def test_la_deduction_ne_rend_jamais_les_fonds_propres_negatifs():
    """Un exces superieur au capital le ramene a zero, pas en dessous."""

    agregats = calculate_fonds_propres({"capital_ordinaire": 100.0}, 500.0)
    assert agregats["cet1"] == 0.0
    assert agregats["t1"] == 0.0
