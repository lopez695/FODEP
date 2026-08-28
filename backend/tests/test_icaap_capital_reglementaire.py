"""Le socle Pilier 1 du PIEAFP, et le cycle auquel il se rattache.

Le dispositif (Titre XI) pose que les fonds propres internes s'AJOUTENT aux
exigences minimales : le PIEAFP part donc du Pilier 1 et ne le refait pas. Deux
choses se verifient ici.

D'abord que l'ecran ICAAP lit le meme Pilier 1 que le tableau de bord. Une
seconde implantation du ratio de solvabilite finirait par en diverger -- c'est
deja arrive sur la lecture des fonds propres (cf. `app.core.fonds_propres`), et
deux ecrans qui annoncent des ratios differents ne sont credibles ni l'un ni
l'autre.

Ensuite que les deux seuils soient distingues. Le Titre III pose des minimums
de 5 %, 6 % et 9 % AVANT coussin de conservation ; l'EP01 de la declaration,
lui, mesure contre 7,5 %, 8,5 % et 11,5 %. N'afficher que le minimum ferait
etat d'une marge que la declaration ne reconnait pas.
"""

from __future__ import annotations

import pytest

from app.core.bceao_calculations import CONSERVATION_BUFFER, MIN_SOLVENCY_RATIO
from app.dashboard.services import get_dashboard_snapshot
from app.icaap.models import BROUILLON, TRANSMIS, VALIDE, StatutCycleUpdate
from app.icaap.services import (
    DEPASSEE,
    RESPECTEE,
    SOUS_COUSSIN,
    _niveau,
    capital_reglementaire,
    changer_statut,
    cycle_courant,
)
from database.connection import database_manager


@pytest.fixture(scope="module", autouse=True)
def base_migree():
    """La base temporaire de la suite porte le schema du jour de la copie.

    Sans cet appel, `icaap_exercices` n'existe pas et les essais echouent sur
    le schema plutot que sur le comportement.
    """

    database_manager.initialize()


@pytest.fixture
def exercices_rendus():
    """Rend a la table les cycles que l'essai y ajoute."""

    ajoutes: list[int] = []
    yield ajoutes
    with database_manager.transaction() as connexion:
        for exercice in ajoutes:
            connexion.execute(
                "DELETE FROM icaap_exercices WHERE exercice = ?", (exercice,)
            )


def test_le_socle_reprend_les_chiffres_du_tableau_de_bord():
    """Meme portefeuille, memes fonds propres : memes ratios, au centieme."""

    socle = capital_reglementaire()
    metriques = {m.key: m.value for m in get_dashboard_snapshot().metrics}
    ratios = {n.code: n for n in socle.ratios}

    assert socle.apr_total == pytest.approx(metriques["rwa"], rel=1e-9)
    # Le tableau de bord porte les ratios en fraction, l'ICAAP en points.
    assert ratios["solvabilite"].observe == pytest.approx(
        metriques["solvabilite"] * 100.0, abs=1e-3
    )
    assert ratios["cet1"].observe == pytest.approx(
        metriques["cet1_ratio"] * 100.0, abs=1e-3
    )
    assert ratios["levier"].observe == pytest.approx(
        metriques["ratio_levier"] * 100.0, abs=1e-3
    )


def test_l_apr_se_ventile_sans_perte():
    """Credit + marche + operationnel redonne l'assiette du ratio (§90)."""

    socle = capital_reglementaire()
    somme = sum(e.apr for e in socle.exigences)

    assert somme == pytest.approx(socle.apr_total, rel=1e-9)
    assert sum(e.part for e in socle.exigences) == pytest.approx(100.0, abs=0.05)


def test_les_seuils_portent_le_coussin_de_conservation():
    """7,5 %, 8,5 % et 11,5 % : les seuils que l'EP01 mesure."""

    ratios = {n.code: n for n in capital_reglementaire().ratios}

    assert ratios["cet1"].exigence_avec_coussin == pytest.approx(7.5)
    assert ratios["tier1"].exigence_avec_coussin == pytest.approx(8.5)
    assert ratios["solvabilite"].exigence_avec_coussin == pytest.approx(11.5)


def test_le_coussin_ne_majore_pas_le_levier():
    """Le coussin se mesure sur les actifs ponderes, pas sur l'exposition.

    Majorer le levier de 2,5 points le porterait a 5,5 % : un seuil qui
    n'existe dans aucun texte, et que l'EP33 ne mesure pas.
    """

    levier = {n.code: n for n in capital_reglementaire().ratios}["levier"]

    assert levier.minimum == pytest.approx(3.0)
    assert levier.exigence_avec_coussin == pytest.approx(3.0)


def test_un_ratio_entre_les_deux_seuils_est_sous_coussin():
    """Respecter le minimum sans couvrir le coussin n'est pas « respectee ».

    C'est l'etat qui declenche les restrictions de distribution : l'afficher
    comme conforme ferait manquer le signal.
    """

    entre_les_deux = _niveau(
        "solvabilite", "Ratio de solvabilité total", 10.0, MIN_SOLVENCY_RATIO, 1_000.0
    )
    au_dessus = _niveau(
        "solvabilite", "Ratio de solvabilité total", 12.0, MIN_SOLVENCY_RATIO, 1_000.0
    )
    en_dessous = _niveau(
        "solvabilite", "Ratio de solvabilité total", 8.0, MIN_SOLVENCY_RATIO, 1_000.0
    )

    assert entre_les_deux.situation == SOUS_COUSSIN
    assert au_dessus.situation == RESPECTEE
    assert en_dessous.situation == DEPASSEE


def test_les_fonds_propres_requis_suivent_l_assiette():
    """11,5 % de l'APR total : le montant que le socle exige."""

    socle = capital_reglementaire()
    attendu = socle.apr_total * (MIN_SOLVENCY_RATIO + CONSERVATION_BUFFER)

    assert socle.exigence_globale.fonds_propres_requis == pytest.approx(
        attendu, rel=1e-6
    )
    assert socle.exigence_globale.marge == pytest.approx(
        socle.exigence_globale.fonds_propres_disponibles - attendu, rel=1e-6
    )


def test_le_cycle_naît_au_premier_acces(exercices_rendus):
    """Le cycle existe des lors que l'exercice existe."""

    exercices_rendus.append(2031)

    cycle = cycle_courant(2031)

    assert cycle.exercice == 2031
    assert cycle.statut == BROUILLON
    assert cycle.version == 1
    assert cycle.date_validation is None


def test_valider_date_le_cycle(exercices_rendus):
    """Le rapport PIEAFP engage les organes : la date fait partie de la piece."""

    exercices_rendus.append(2032)
    cycle_courant(2032)

    valide = changer_statut(
        2032,
        StatutCycleUpdate(statut=VALIDE, organe="Conseil d'administration"),
    )

    assert valide.statut == VALIDE
    assert valide.organe == "Conseil d'administration"
    assert valide.date_validation, "une validation sans date ne s'oppose a personne"


def test_rouvrir_apres_validation_incremente_la_version(exercices_rendus):
    """Une revision qui porterait le numero de la piece transmise ne vaudrait rien."""

    exercices_rendus.append(2033)
    cycle_courant(2033)

    changer_statut(2033, StatutCycleUpdate(statut=TRANSMIS))
    rouvert = changer_statut(2033, StatutCycleUpdate(statut=BROUILLON))

    assert rouvert.version == 2
    assert rouvert.date_validation is None

    # Rester en brouillon ne cree pas de version : seule la reouverture compte.
    encore = changer_statut(2033, StatutCycleUpdate(statut=BROUILLON))
    assert encore.version == 2
