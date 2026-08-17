"""Tests des invariants du module Value at Risk (Partie 3.4 de la spec).

Invariants communs aux trois méthodes :
- pire perte >= Expected Shortfall >= VaR ;
- VaR 95 % <= VaR 97,5 % <= VaR 99 % ;
- somme des effectifs de l'histogramme = nombre d'observations/simulations ;
- taux de dépassement historique cohérent avec le niveau de confiance ;
- Monte-Carlo : reproductibilité à graine identique ;
- paramétrique : cas analytique mu = 0, sigma connu ;
- couche données : valorisation d'une obligation simple vérifiée à la main
  et V(t) actions vérifiée sur un mini portefeuille de deux titres.
"""

from __future__ import annotations

import sys
from datetime import date
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.var_marche import (  # noqa: E402
    portefeuille_data,
    var_historique,
    var_montecarlo,
    var_parametrique,
)
from app.var_marche.portefeuille_data import (  # noqa: E402
    DonneesAbsentesError,
    ErreurDonneesVar,
    PositionObligation,
    interpoler_taux,
    prix_obligation_par_courbe,
)

NIVEAUX = (0.95, 0.975, 0.99)


@pytest.fixture(scope="module", autouse=True)
def _mode_simulation_pour_les_series(tmp_path_factory):
    """Les invariants des moteurs sont testés sur les séries simulées
    reproductibles : la couche de données est isolée dans un répertoire
    vide pour que d'éventuelles données réelles présentes sur la machine
    (portefeuille importé dans rwa_data.db, courbe UMOA actualisée)
    n'interfèrent pas avec les fixtures.

    L'isolation doit couvrir la base : le portefeuille marché importé depuis
    l'application est lu dans `metadonnees_app` et prime sur les CSV. Sans
    cette bascule, un import fait par l'utilisateur remplace les portefeuilles
    des fixtures et fait échouer des tests qui ne portent pas sur ses données.
    """

    from database.connection import database_manager

    patchs = pytest.MonkeyPatch()
    racine_vide = tmp_path_factory.mktemp("var_data_isolees")
    patchs.setattr(portefeuille_data, "app_data_root", lambda: racine_vide)
    patchs.setattr(database_manager, "db_path", racine_vide / "var_isolee.db")
    patchs.setenv("VAR_MODE_SIMULATION", "1")
    patchs.delenv("VAR_POSTGRES_DSN", raising=False)
    portefeuille_data.invalider_cache_series()
    yield
    patchs.undo()
    portefeuille_data.invalider_cache_series()


@pytest.fixture(scope="module")
def pertes_obligations() -> np.ndarray:
    serie = portefeuille_data.get_serie_pnl("obligations", 500, 1)
    return serie.pertes / 1e9


@pytest.fixture(scope="module")
def pertes_actions() -> np.ndarray:
    serie = portefeuille_data.get_serie_pnl("actions", 500, 1)
    return serie.pertes / 1e9


@pytest.fixture(scope="module")
def serie_actions() -> portefeuille_data.SeriePnl:
    return portefeuille_data.get_serie_pnl("actions", 500, 1)


@pytest.fixture(scope="module")
def serie_obligations() -> portefeuille_data.SeriePnl:
    return portefeuille_data.get_serie_pnl("obligations", 500, 1)


def _resultats_trois_methodes(serie: portefeuille_data.SeriePnl, type_portefeuille: str, niveau: float):
    pertes_md = serie.pertes / 1e9
    historique = var_historique.calculer(pertes_md, niveau)
    parametrique = var_parametrique.calculer(pertes_md, niveau)
    montecarlo = var_montecarlo.calculer(
        type_portefeuille=type_portefeuille,
        valeur_portefeuille=serie.valeur_portefeuille / 1e9,
        pertes_quotidiennes=serie.pertes_quotidiennes / 1e9,
        niveau_confiance=niveau,
        horizon_jours=1,
        nb_simulations=10_000,
        duration_modifiee=serie.duration_modifiee,
        variations_taux=serie.variations_taux,
    )
    return historique, parametrique, montecarlo


# ---------------------------------------------------------------------------
# Invariants communs
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("type_portefeuille", ["obligations", "actions"])
@pytest.mark.parametrize("niveau", NIVEAUX)
def test_pire_perte_es_var_ordonnes(type_portefeuille, niveau):
    serie = portefeuille_data.get_serie_pnl(type_portefeuille, 500, 1)
    for resultat in _resultats_trois_methodes(serie, type_portefeuille, niveau):
        assert resultat["pire_perte"] >= resultat["expected_shortfall"] >= resultat["var"]


@pytest.mark.parametrize("type_portefeuille", ["obligations", "actions"])
def test_var_croissante_avec_niveau_confiance(type_portefeuille):
    serie = portefeuille_data.get_serie_pnl(type_portefeuille, 500, 1)
    for indice_methode in range(3):
        vars_par_niveau = [
            _resultats_trois_methodes(serie, type_portefeuille, niveau)[indice_methode]["var"]
            for niveau in NIVEAUX
        ]
        assert vars_par_niveau[0] <= vars_par_niveau[1] <= vars_par_niveau[2]


@pytest.mark.parametrize("type_portefeuille", ["obligations", "actions"])
def test_somme_effectifs_histogramme(type_portefeuille):
    serie = portefeuille_data.get_serie_pnl(type_portefeuille, 500, 1)
    historique, parametrique, montecarlo = _resultats_trois_methodes(
        serie, type_portefeuille, 0.99
    )
    assert sum(c["effectif"] for c in historique["histogramme"]) == 500
    assert sum(c["effectif"] for c in parametrique["histogramme"]) == 500
    assert sum(c["effectif"] for c in montecarlo["histogramme"]) == 10_000
    assert len(historique["histogramme"]) == 40


def test_taux_depassement_coherent(pertes_obligations):
    for niveau in NIVEAUX:
        resultat = var_historique.calculer(pertes_obligations, niveau)
        attendu = (1.0 - niveau) * 100.0
        assert abs(resultat["taux_depassement_pct"] - attendu) <= 0.5


# ---------------------------------------------------------------------------
# Monte-Carlo
# ---------------------------------------------------------------------------


def test_montecarlo_reproductible(serie_obligations):
    def calcul():
        return var_montecarlo.calculer(
            type_portefeuille="obligations",
            valeur_portefeuille=serie_obligations.valeur_portefeuille / 1e9,
            pertes_quotidiennes=serie_obligations.pertes_quotidiennes / 1e9,
            niveau_confiance=0.99,
            horizon_jours=1,
            nb_simulations=10_000,
            graine=123,
            duration_modifiee=serie_obligations.duration_modifiee,
            variations_taux=serie_obligations.variations_taux,
        )

    premier, second = calcul(), calcul()
    assert premier["var"] == second["var"]
    assert premier["expected_shortfall"] == second["expected_shortfall"]
    assert premier["ic_var_95"] == second["ic_var_95"]
    assert premier["histogramme"] == second["histogramme"]


def test_montecarlo_ic_encadre_la_var(serie_actions):
    resultat = var_montecarlo.calculer(
        type_portefeuille="actions",
        valeur_portefeuille=serie_actions.valeur_portefeuille / 1e9,
        pertes_quotidiennes=serie_actions.pertes_quotidiennes / 1e9,
        niveau_confiance=0.99,
        horizon_jours=1,
        nb_simulations=10_000,
    )
    ic = resultat["ic_var_95"]
    assert ic["borne_basse"] <= resultat["var"] <= ic["borne_haute"]


# ---------------------------------------------------------------------------
# Paramétrique : cas analytique
# ---------------------------------------------------------------------------


def test_parametrique_cas_analytique():
    for niveau, z_attendu in var_parametrique.Z_ALPHA.items():
        var = var_parametrique.var_depuis_moments(0.0, 2.5, z_attendu)
        assert var == pytest.approx(z_attendu * 2.5, abs=1e-6)
        assert niveau in (0.95, 0.975, 0.99)


def test_parametrique_es_superieur_var():
    for niveau, z in var_parametrique.Z_ALPHA.items():
        var = var_parametrique.var_depuis_moments(0.0, 1.0, z)
        es = var_parametrique.es_depuis_moments(0.0, 1.0, z, niveau)
        assert es > var


# ---------------------------------------------------------------------------
# Couche données
# ---------------------------------------------------------------------------


def test_valorisation_obligation_flux_unique_courbe_plate():
    """Obligation zéro coupon de nominal 10 000, courbe plate à 6 %.

    Un seul flux de 10 000 dans exactement 2 ans :
    prix attendu = 10 000 / 1,06^2 = 8 899,96 soit 89,0 % du nominal.
    """

    position = PositionObligation(
        isin="TEST0001",
        emetteur="Test",
        devise="XOF",
        valeur_nominale=10_000.0,
        taux_coupon_pct=0.0,
        frequence_coupon=1,
        date_emission=date(2020, 7, 10),
        date_echeance=date(2026, 7, 10),
        quantite=1,
        prix_marche_pct=None,
    )
    courbe_plate = [(0.25, 6.0), (10.0, 6.0)]
    jour = date(2024, 7, 10)
    echeance_annees = (date(2026, 7, 10) - jour).days / 365.25
    prix_attendu = 10_000.0 / (1.06**echeance_annees) / 10_000.0 * 100.0
    prix = prix_obligation_par_courbe(position, courbe_plate, jour)
    assert prix == pytest.approx(prix_attendu, abs=1e-9)


def test_interpolation_lineaire_taux():
    points = [(1.0, 5.0), (3.0, 7.0)]
    assert interpoler_taux(points, 2.0) == pytest.approx(6.0)
    assert interpoler_taux(points, 0.5) == pytest.approx(5.0)  # extrapolation plate
    assert interpoler_taux(points, 8.0) == pytest.approx(7.0)


def test_serie_actions_mini_portefeuille(tmp_path, monkeypatch):
    """V(t) = somme quantite x cours sur un portefeuille de deux titres."""

    (tmp_path / "positions_actions.csv").write_text(
        "ticker;libelle;secteur;quantite\nAAA;Titre A;Banque;10\nBBB;Titre B;Industrie;5\n",
        encoding="utf-8",
    )
    (tmp_path / "historique_cours_actions.csv").write_text(
        "date;ticker;cours_cloture\n"
        "2026-07-06;AAA;100\n2026-07-06;BBB;200\n"
        "2026-07-07;AAA;110\n2026-07-07;BBB;190\n"
        "2026-07-08;AAA;105\n2026-07-08;BBB;210\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(portefeuille_data, "app_data_root", lambda: tmp_path)
    portefeuille_data.invalider_cache_series()
    try:
        serie = portefeuille_data.get_serie_pnl("actions", 2, 1)
        # V = [10x100+5x200, 10x110+5x190, 10x105+5x210] = [2000, 2050, 2100]
        assert serie.valeur_portefeuille == pytest.approx(2100.0)
        # pertes = V(t-1) - V(t) = [-50, -50]
        assert list(serie.pertes) == pytest.approx([-50.0, -50.0])
        assert serie.source_donnees == "reelles"
    finally:
        portefeuille_data.invalider_cache_series()


def test_profondeur_insuffisante_erreur_explicite(tmp_path, monkeypatch):
    (tmp_path / "positions_actions.csv").write_text(
        "ticker;libelle;secteur;quantite\nAAA;Titre A;Banque;10\n",
        encoding="utf-8",
    )
    (tmp_path / "historique_cours_actions.csv").write_text(
        "date;ticker;cours_cloture\n2026-07-06;AAA;100\n2026-07-07;AAA;110\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(portefeuille_data, "app_data_root", lambda: tmp_path)
    portefeuille_data.invalider_cache_series()
    try:
        with pytest.raises(ErreurDonneesVar, match="Profondeur d'historique insuffisante"):
            portefeuille_data.get_serie_pnl("actions", 250, 1)
    finally:
        portefeuille_data.invalider_cache_series()


def test_titre_absent_historique_erreur_explicite(tmp_path, monkeypatch):
    (tmp_path / "positions_actions.csv").write_text(
        "ticker;libelle;secteur;quantite\nAAA;Titre A;Banque;10\nZZZ;Titre Z;Banque;1\n",
        encoding="utf-8",
    )
    (tmp_path / "historique_cours_actions.csv").write_text(
        "date;ticker;cours_cloture\n2026-07-06;AAA;100\n2026-07-07;AAA;110\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(portefeuille_data, "app_data_root", lambda: tmp_path)
    portefeuille_data.invalider_cache_series()
    try:
        with pytest.raises(ErreurDonneesVar, match="ZZZ"):
            portefeuille_data.get_serie_pnl("actions", 1, 1)
    finally:
        portefeuille_data.invalider_cache_series()


def test_mode_simulation_sans_donnees(tmp_path, monkeypatch):
    """Avec VAR_MODE_SIMULATION=1 (fixture module), repli simulation."""

    monkeypatch.setattr(portefeuille_data, "app_data_root", lambda: tmp_path)
    portefeuille_data.invalider_cache_series()
    try:
        serie = portefeuille_data.get_serie_pnl("actions", 500, 1)
        assert serie.source_donnees == "simulation"
        assert len(serie.pertes) == 500
        # Reproductibilité : la graine est fixe par type de portefeuille.
        serie_bis = portefeuille_data.get_serie_pnl("actions", 500, 1)
        assert list(serie.pertes) == list(serie_bis.pertes)
    finally:
        portefeuille_data.invalider_cache_series()


def test_sans_donnees_erreur_explicite_par_defaut(tmp_path, monkeypatch):
    """Sans VAR_MODE_SIMULATION, l'absence de données est une erreur claire."""

    monkeypatch.setattr(portefeuille_data, "app_data_root", lambda: tmp_path)
    monkeypatch.delenv("VAR_MODE_SIMULATION", raising=False)
    portefeuille_data.invalider_cache_series()
    try:
        with pytest.raises(DonneesAbsentesError, match="Aucune donnée réelle"):
            portefeuille_data.get_serie_pnl("actions", 500, 1)
        with pytest.raises(DonneesAbsentesError, match="obligations"):
            portefeuille_data.get_serie_pnl("obligations", 500, 1)
    finally:
        portefeuille_data.invalider_cache_series()


def test_mode_reglementaire_sans_historique_obligations(tmp_path, monkeypatch):
    """Positions + courbe du jour, sans historique de prix : la série de
    pertes est vide mais la valorisation et la duration restent disponibles,
    et les VaR paramétrique et Monte-Carlo produisent une valeur strictement
    positive (mode réglementaire). Reproduit le parcours utilisateur :
    import du portefeuille puis « Actualiser la courbe des taux »."""

    (tmp_path / "positions_obligations.csv").write_text(
        "isin;emetteur;devise;valeur_nominale;taux_coupon_pct;"
        "frequence_coupon;date_emission;date_echeance;quantite;prix_marche_pct\n"
        "OB1;Etat CI;XOF;10000;6.0;1;2024-01-30;2031-01-30;1000;\n",
        encoding="utf-8",
    )
    (tmp_path / "historique_taux.csv").write_text(
        "date;maturite_annees;taux_pct\n"
        "2026-07-16;0.25;5.2\n2026-07-16;1;5.6\n"
        "2026-07-16;5;6.1\n2026-07-16;10;6.5\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(portefeuille_data, "app_data_root", lambda: tmp_path)
    # Neutralise un éventuel portefeuille importé dans le rwa_data.db local :
    # ce test doit valoriser uniquement les positions CSV de la fixture.
    monkeypatch.setattr(
        portefeuille_data, "_lire_valeur_marche_portefeuilles_sqlite", lambda: None
    )
    monkeypatch.delenv("VAR_MODE_SIMULATION", raising=False)
    portefeuille_data.invalider_cache_series()
    try:
        serie = portefeuille_data.get_serie_pnl("obligations", 250, 1)
        assert len(serie.pertes) == 0
        assert serie.valeur_portefeuille > 0
        assert serie.duration_modifiee is not None
        assert serie.duration_modifiee > 0
        assert any("mode réglementaire" in a for a in serie.avertissements)

        resultat = var_parametrique.calculer(
            serie.pertes / 1e9,
            0.99,
            type_portefeuille="obligations",
            valeur_portefeuille=serie.valeur_portefeuille / 1e9,
            duration_modifiee=serie.duration_modifiee,
            horizon_jours=1,
            volatilite_reglementaire=0.03,
        )
        assert resultat["var"] > 0

        resultat_mc = var_montecarlo.calculer(
            type_portefeuille="obligations",
            valeur_portefeuille=serie.valeur_portefeuille / 1e9,
            pertes_quotidiennes=serie.pertes_quotidiennes / 1e9,
            niveau_confiance=0.99,
            horizon_jours=1,
            nb_simulations=1_000,
            graine=42,
            duration_modifiee=serie.duration_modifiee,
            variations_taux=serie.variations_taux,
            volatilite_reglementaire=0.03,
        )
        assert resultat_mc["var"] > 0
    finally:
        portefeuille_data.invalider_cache_series()


def test_nouveaux_fichiers_charges_automatiquement(tmp_path, monkeypatch):
    """Le dépôt ou la modification d'un fichier invalide le cache tout seul."""

    monkeypatch.setattr(portefeuille_data, "app_data_root", lambda: tmp_path)
    (tmp_path / "positions_actions.csv").write_text(
        "ticker;libelle;secteur;quantite\nAAA;Titre A;Banque;10\n",
        encoding="utf-8",
    )
    (tmp_path / "historique_cours_actions.csv").write_text(
        "date;ticker;cours_cloture\n"
        "2026-07-06;AAA;100\n2026-07-07;AAA;110\n2026-07-08;AAA;105\n",
        encoding="utf-8",
    )
    portefeuille_data.invalider_cache_series()
    try:
        premiere = portefeuille_data.get_serie_pnl("actions", 2, 1)
        assert premiere.valeur_portefeuille == pytest.approx(1050.0)

        # Nouvel import : le fichier est réécrit avec une journée de plus.
        # Aucune invalidation manuelle : l'empreinte (mtime + taille) suffit.
        (tmp_path / "historique_cours_actions.csv").write_text(
            "date;ticker;cours_cloture\n"
            "2026-07-06;AAA;100\n2026-07-07;AAA;110\n"
            "2026-07-08;AAA;105\n2026-07-09;AAA;120\n",
            encoding="utf-8",
        )
        seconde = portefeuille_data.get_serie_pnl("actions", 2, 1)
        assert seconde.valeur_portefeuille == pytest.approx(1200.0)
        assert list(seconde.pertes) == pytest.approx([50.0, -150.0])
    finally:
        portefeuille_data.invalider_cache_series()


def test_horizon_met_a_echelle_racine_temps(serie_obligations):
    serie_10j = portefeuille_data.get_serie_pnl("obligations", 500, 10)
    ratio = serie_10j.pertes[-1] / serie_obligations.pertes[-1]
    assert ratio == pytest.approx(np.sqrt(10.0), rel=1e-12)


# ---------------------------------------------------------------------------
# Cohérence inter-méthodes (Partie 6)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("type_portefeuille", ["obligations", "actions"])
def test_coherence_entre_methodes(type_portefeuille):
    serie = portefeuille_data.get_serie_pnl(type_portefeuille, 500, 1)
    historique, parametrique, montecarlo = _resultats_trois_methodes(
        serie, type_portefeuille, 0.99
    )
    vars_calculees = [historique["var"], parametrique["var"], montecarlo["var"]]
    reference = max(vars_calculees)
    assert reference > 0
    for valeur in vars_calculees:
        assert abs(valeur - reference) / reference < 0.30
