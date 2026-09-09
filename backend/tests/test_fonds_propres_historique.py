"""Les fonds propres se conservent exercice par exercice.

`update_fonds_propres` relisait la ligne la plus recente et la reecrivait : la
table n'a jamais porte plus d'un enregistrement, quel que soit le nombre de
saisies. L'absence d'historique se payait sur la declaration -- les limites des
EP35 a EP38 se mesurent, dit le formulaire, sur les fonds propres de l'EXERCICE
PRECEDENT, et l'export les rapportait a l'exercice declare faute de mieux.

C'est aussi ce qui bloquait la deduction, au CET1, de l'excedent des limites
franchies : mesurer sur les fonds propres de l'annee en cours rendrait le
calcul circulaire, la deduction baissant le CET1 qui releve le ratio qui
augmente la deduction. Rapporte a un millesime clos, l'exces est un nombre
fixe, et `app.core.limites_prudentielles` le pose en une passe.
"""

from __future__ import annotations

import pytest

from app.dashboard.models import FondsPropresUpdate
from app.dashboard.services import get_dashboard_snapshot, update_fonds_propres
from database.connection import database_manager


def _saisie(exercice: int, capital: float) -> FondsPropresUpdate:
    return FondsPropresUpdate(
        exercice=exercice,
        capital_ordinaire=capital,
        reserves=0.0,
        resultats_report=0.0,
        resultat_eligible=0.0,
        deductions_prud_cet1=0.0,
        instruments_at1=0.0,
        primes_emission_at1=0.0,
        deductions_prud_at1=0.0,
        dettes_subordonnees_t2=0.0,
        provisions_generales_t2=0.0,
        deductions_prud_t2=0.0,
    )


@pytest.fixture(scope="module", autouse=True)
def base_migree():
    """Applique les migrations a la base temporaire de la suite.

    La base des tests est recopiee depuis la graine : elle porte le schema du
    jour de la copie, pas les migrations posees depuis. Sans cet appel, la
    colonne d'exercice n'existe pas et les essais echouent sur le schema
    plutot que sur le comportement.
    """

    database_manager.initialize()


@pytest.fixture
def exercices_rendus():
    """Rend a la table les exercices que l'essai y ajoute."""

    ajoutes: list[int] = []
    yield ajoutes
    with database_manager.transaction() as connexion:
        for exercice in ajoutes:
            connexion.execute(
                "DELETE FROM fonds_propres WHERE exercice = ?", (exercice,)
            )


def test_une_saisie_sans_exercice_est_refusee():
    """Un client qui n'envoie pas d'exercice doit echouer, pas ecraser.

    L'exercice a d'abord ete facultatif, l'annee en cours servant de defaut :
    une interface restee sur une version anterieure ecrasait alors l'exercice
    courant avec les chiffres d'un autre, sans que rien ne le signale. C'est
    arrive deux fois sur les fonds propres declares. Le refus est franc.
    """

    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        FondsPropresUpdate(
            capital_ordinaire=1.0,
            reserves=0.0,
            resultats_report=0.0,
            resultat_eligible=0.0,
            deductions_prud_cet1=0.0,
            instruments_at1=0.0,
            primes_emission_at1=0.0,
            deductions_prud_at1=0.0,
            dettes_subordonnees_t2=0.0,
            provisions_generales_t2=0.0,
            deductions_prud_t2=0.0,
        )


def test_un_exercice_hors_bornes_est_refuse():
    """Une annee absurde ne cree pas une ligne de plus dans l'historique."""

    from pydantic import ValidationError

    for annee in (1999, 2101):
        with pytest.raises(ValidationError):
            _saisie(annee, 1.0)


def test_deux_exercices_coexistent(exercices_rendus):
    """Saisir un exercice n'efface pas le precedent."""

    exercices_rendus.extend([2019, 2018])

    update_fonds_propres(_saisie(2018, 1_000.0))
    update_fonds_propres(_saisie(2019, 2_000.0))

    historique = {h.exercice: h for h in get_dashboard_snapshot().fonds_propres.historique}
    assert 2018 in historique, "l'exercice precedent a ete efface"
    assert 2019 in historique
    assert historique[2018].cet1 == pytest.approx(1_000.0)
    assert historique[2019].cet1 == pytest.approx(2_000.0)


def test_resaisir_le_meme_exercice_le_corrige(exercices_rendus):
    """Un exercice deja saisi est corrige, pas duplique."""

    exercices_rendus.append(2017)

    update_fonds_propres(_saisie(2017, 1_000.0))
    update_fonds_propres(_saisie(2017, 3_000.0))

    historique = [
        h for h in get_dashboard_snapshot().fonds_propres.historique
        if h.exercice == 2017
    ]
    assert len(historique) == 1, "l'exercice a ete duplique"
    assert historique[0].cet1 == pytest.approx(3_000.0)


def test_l_historique_va_du_plus_recent_au_plus_ancien(exercices_rendus):
    """L'ordre est celui de la lecture : le dernier exercice en premier."""

    exercices_rendus.extend([2015, 2016])

    update_fonds_propres(_saisie(2015, 1_000.0))
    update_fonds_propres(_saisie(2016, 1_000.0))

    annees = [h.exercice for h in get_dashboard_snapshot().fonds_propres.historique]
    assert annees == sorted(annees, reverse=True)


def test_les_fonds_propres_courants_sont_ceux_du_dernier_exercice(exercices_rendus):
    """Une correction portee en retard sur un exercice ancien ne prend pas la main.

    Le tri se faisait sur `date_analyse`, un horodatage de saisie : corriger
    2015 aujourd'hui l'aurait place devant l'exercice le plus recent.
    """

    exercices_rendus.extend([2014])

    courant_avant = get_dashboard_snapshot().fonds_propres.exercice
    update_fonds_propres(_saisie(2014, 42.0))
    courant_apres = get_dashboard_snapshot().fonds_propres

    if courant_avant is not None and courant_avant > 2014:
        assert courant_apres.exercice == courant_avant
        assert courant_apres.cet1 != pytest.approx(42.0)
