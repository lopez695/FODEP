"""Tests du suivi mensuel des versements et du cycle de vie prudentiel."""

from __future__ import annotations

from datetime import date, timedelta

import pytest

from app.expositions import suivi_service
from app.expositions.models import ExposureCreate
from app.expositions.services import create_exposition, update_exposition
from database.services.rwa_calculation_service import (
    JOURS_IMPAYES_SEUIL_SOUFFRANCE,
    build_exposure_record,
    resolve_statut_prudentiel,
)


# ── Unitaires : statut dérivé et pondération en souffrance ───────────────────


def test_statut_prudentiel_saine_sans_impayes():
    assert (
        resolve_statut_prudentiel(jours_impayes=0, declassement_manuel=False)
        == "saine"
    )


def test_statut_prudentiel_impayee_sous_90_jours():
    assert (
        resolve_statut_prudentiel(jours_impayes=45, declassement_manuel=False)
        == "impayee"
    )


def test_statut_prudentiel_douteuse_a_90_jours():
    assert (
        resolve_statut_prudentiel(
            jours_impayes=JOURS_IMPAYES_SEUIL_SOUFFRANCE,
            declassement_manuel=False,
        )
        == "douteuse"
    )


def test_statut_prudentiel_douteuse_par_declassement_manuel():
    assert (
        resolve_statut_prudentiel(jours_impayes=0, declassement_manuel=True)
        == "douteuse"
    )


def _payload_entreprise(**overrides) -> ExposureCreate:
    data = {
        "analysis_date": date.today(),
        "counterparty_name": "Entreprise Test",
        "country": "Cote d'Ivoire",
        "category": "Entreprises",
        "rating": "BBB",
        "gross_amount": 1_000_000.0,
    }
    data.update(overrides)
    return ExposureCreate(**data)


def test_exposition_douteuse_ponderee_150_pct_sans_provisions():
    record = build_exposure_record(
        _payload_entreprise(jours_impayes=120), "TEST-150"
    )
    assert record["statut_prudentiel"] == "douteuse"
    assert record["original_rw"] == pytest.approx(1.5)
    assert record["rwa"] == pytest.approx(1_500_000.0)


def test_exposition_douteuse_ponderee_100_pct_avec_provisions_20_pct():
    record = build_exposure_record(
        _payload_entreprise(jours_impayes=120, provisions_amount=200_000.0),
        "TEST-100",
    )
    assert record["statut_prudentiel"] == "douteuse"
    assert record["original_rw"] == pytest.approx(1.0)


def test_exposition_impayee_sous_90_jours_garde_sa_ponderation():
    record = build_exposure_record(
        _payload_entreprise(jours_impayes=30), "TEST-NORM"
    )
    assert record["statut_prudentiel"] == "impayee"
    assert record["original_rw"] == pytest.approx(1.0)


def test_immo_residentiel_en_defaut_pondere_100_pct():
    payload = _payload_entreprise(
        category="Immobilier residentiel",
        jours_impayes=120,
        residential_mortgage_eligible=True,
    )
    record = build_exposure_record(payload, "TEST-IMMO")
    assert record["statut_prudentiel"] == "douteuse"
    assert record["original_rw"] == pytest.approx(1.0)


def test_declassement_manuel_pondere_en_souffrance_sans_impayes():
    record = build_exposure_record(
        _payload_entreprise(declassement_manuel=True), "TEST-MANUEL"
    )
    assert record["statut_prudentiel"] == "douteuse"
    assert record["original_rw"] == pytest.approx(1.5)


# ── Dérivation des jours d'impayés ───────────────────────────────────────────


def test_derive_jours_impayes_depuis_premier_mois_impaye():
    reference = date(2026, 7, 19)
    assert suivi_service._derive_jours_impayes("2026-04", reference) == 109
    assert suivi_service._derive_jours_impayes("2026-07", reference) == 18
    assert suivi_service._derive_jours_impayes(None, reference) == 0


# ── Intégration : base temporaire ────────────────────────────────────────────


@pytest.fixture
def temp_db(tmp_path, monkeypatch):
    from database.connection import database_manager

    monkeypatch.setattr(database_manager, "db_path", tmp_path / "test_rwa.db")
    # Base neuve : schema.sql est à jour, les migrations historiques (schéma
    # anglais d'origine) ne doivent pas être rejouées — on les marque appliquées,
    # comme le fait le seed de production.
    connection = database_manager.connect()
    try:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                applied_at TEXT NOT NULL
            )
            """
        )
        for path in sorted(database_manager.migrations_dir.glob("*.sql")):
            try:
                version = int(path.stem.split("_", 1)[0])
            except ValueError:
                continue
            connection.execute(
                "INSERT OR IGNORE INTO schema_migrations(version, name, applied_at) "
                "VALUES (?, ?, ?)",
                (version, path.stem, "test"),
            )
        connection.commit()
    finally:
        connection.close()
    database_manager.initialize()
    yield database_manager


def _periode_il_y_a(jours: int) -> str:
    return (date.today() - timedelta(days=jours)).strftime("%Y-%m")


def test_cycle_impaye_declassement_regularisation(temp_db):
    view = create_exposition(_payload_entreprise())
    assert view.statut_prudentiel == "saine"
    assert view.final_rw == pytest.approx(1.0)

    # Impayé ancien (> 90 jours) : bascule automatique en douteuse à 150 %.
    suivi = suivi_service.record_versement(
        view.id, periode=_periode_il_y_a(150), statut="impaye"
    )
    assert suivi["jours_impayes"] >= JOURS_IMPAYES_SEUIL_SOUFFRANCE
    assert suivi["statut_prudentiel"] == "douteuse"
    from database.repositories.exposure_repository import exposure_repository

    record = exposure_repository.get_exposure(view.id)
    assert record["statut_prudentiel"] == "douteuse"
    assert record["final_rw"] == pytest.approx(1.5)
    assert record["rwa"] == pytest.approx(1_500_000.0)

    # Régularisation : le mois est marqué versé, retour à saine à 100 %.
    suivi = suivi_service.record_versement(
        view.id,
        periode=_periode_il_y_a(150),
        statut="verse",
        montant_verse=50_000.0,
    )
    assert suivi["jours_impayes"] == 0
    assert suivi["statut_prudentiel"] == "saine"
    record = exposure_repository.get_exposure(view.id)
    assert record["final_rw"] == pytest.approx(1.0)

    # L'historique conserve la trace de l'impayé initial et de la correction.
    operations = [entry["operation"] for entry in suivi["journal"]]
    assert "impaye_enregistre" in operations
    assert "versement_enregistre" in operations


def test_declassement_manuel_et_protection_du_put(temp_db):
    view = create_exposition(_payload_entreprise())

    with pytest.raises(suivi_service.SuiviValidationError):
        suivi_service.declasser_exposition(view.id, motif="   ")

    suivi = suivi_service.declasser_exposition(
        view.id, motif="Procédure collective ouverte"
    )
    assert suivi["statut_prudentiel"] == "douteuse"
    assert suivi["declassement_manuel"] is True

    # Une édition de formulaire ne peut pas effacer le déclassement.
    updated = update_exposition(view.id, _payload_entreprise())
    assert updated.statut_prudentiel == "douteuse"
    assert updated.declassement_manuel is True
    assert updated.final_rw == pytest.approx(1.5)

    # Levée valide : pas d'arriérés au-dessus du seuil.
    suivi = suivi_service.lever_declassement(
        view.id, motif="Situation régularisée"
    )
    assert suivi["statut_prudentiel"] == "saine"
    assert suivi["declassement_manuel"] is False


def test_levee_refusee_tant_que_les_arrieres_persistent(temp_db):
    view = create_exposition(_payload_entreprise())
    suivi_service.record_versement(
        view.id, periode=_periode_il_y_a(150), statut="impaye"
    )
    suivi_service.declasser_exposition(view.id, motif="Défaut avéré")

    with pytest.raises(suivi_service.LeveeDeclassementRefuseeError):
        suivi_service.lever_declassement(view.id, motif="Tentative prématurée")


def test_saisies_invalides_rejetees(temp_db):
    view = create_exposition(_payload_entreprise())

    with pytest.raises(suivi_service.SuiviValidationError):
        suivi_service.record_versement(view.id, periode="07/2026", statut="verse")

    periode_future = (date.today().replace(day=1) + timedelta(days=45)).strftime(
        "%Y-%m"
    )
    with pytest.raises(suivi_service.SuiviValidationError):
        suivi_service.record_versement(
            view.id, periode=periode_future, statut="verse"
        )

    with pytest.raises(suivi_service.SuiviValidationError):
        suivi_service.record_versement(
            view.id, periode=_periode_il_y_a(30), statut="paye"
        )

    with pytest.raises(suivi_service.ExpositionIntrouvableError):
        suivi_service.get_suivi("CP999")


# ── Amortissement de l'encours par les versements ────────────────────────────


def _payload_avec_hors_bilan(**overrides) -> ExposureCreate:
    """Ligne mixte : 44,5 M au bilan + 8,5 M d'engagement hors bilan."""

    return _payload_entreprise(
        gross_amount=44_500_000.0,
        loan_total_amount=53_000_000.0,
        on_balance_exposure_amount=44_500_000.0,
        off_balance_exposure_amount=8_500_000.0,
        grant_date=date.today() - timedelta(days=800),
        maturity_date=date.today() + timedelta(days=800),
        **overrides,
    )


def test_versement_amortit_le_bilan_sans_toucher_au_hors_bilan(temp_db):
    view = create_exposition(_payload_avec_hors_bilan())
    assert view.gross_amount == pytest.approx(44_500_000.0)

    suivi = suivi_service.record_versement(
        view.id,
        periode=_periode_il_y_a(60),
        statut="verse",
        montant_verse=500_000.0,
    )

    # L'encours baisse du montant remboursé : il ne remonte pas au niveau de
    # l'engagement total (53 M), qui inclut la part hors bilan non tirée.
    assert suivi["encours"] == pytest.approx(44_000_000.0)
    assert suivi["montant_initial"] == pytest.approx(44_500_000.0)
    assert suivi["total_verse"] == pytest.approx(500_000.0)

    from database.repositories.exposure_repository import exposure_repository

    record = exposure_repository.get_exposure(view.id)
    assert record["gross_amount"] == pytest.approx(44_000_000.0)
    assert record["on_balance_exposure_amount"] == pytest.approx(44_000_000.0)
    assert record["off_balance_exposure_amount"] == pytest.approx(8_500_000.0)
    assert record["initial_on_balance_amount"] == pytest.approx(44_500_000.0)


def test_versement_reduit_ead_rwa_et_capital(temp_db):
    view = create_exposition(_payload_avec_hors_bilan())
    rwa_initial = view.rwa

    suivi_service.record_versement(
        view.id,
        periode=_periode_il_y_a(60),
        statut="verse",
        montant_verse=4_500_000.0,
    )

    from database.repositories.exposure_repository import exposure_repository

    record = exposure_repository.get_exposure(view.id)
    # 40 M au bilan + 8,5 M hors bilan pondérés à 100 % (entreprise BBB).
    assert record["ead_bilan_amount"] == pytest.approx(40_000_000.0)
    assert record["ead_total_amount"] == pytest.approx(48_500_000.0)
    assert record["rwa"] == pytest.approx(48_500_000.0)
    assert record["rwa"] < rwa_initial
    assert record["capital"] == pytest.approx(record["rwa"] * 0.09)


def test_versements_successifs_cumulent_sans_deriver(temp_db):
    view = create_exposition(_payload_avec_hors_bilan())

    for jours, montant in ((120, 1_000_000.0), (90, 1_000_000.0), (60, 500_000.0)):
        suivi = suivi_service.record_versement(
            view.id,
            periode=_periode_il_y_a(jours),
            statut="verse",
            montant_verse=montant,
        )

    assert suivi["total_verse"] == pytest.approx(2_500_000.0)
    assert suivi["encours"] == pytest.approx(42_000_000.0)

    # Correction d'un mois déjà saisi : le cumul est recalculé, pas empilé.
    suivi = suivi_service.record_versement(
        view.id,
        periode=_periode_il_y_a(60),
        statut="verse",
        montant_verse=1_500_000.0,
    )
    assert suivi["total_verse"] == pytest.approx(3_500_000.0)
    assert suivi["encours"] == pytest.approx(41_000_000.0)


def test_mois_repasse_en_impaye_restitue_l_encours(temp_db):
    view = create_exposition(_payload_avec_hors_bilan())
    periode = _periode_il_y_a(60)

    suivi_service.record_versement(
        view.id, periode=periode, statut="verse", montant_verse=2_000_000.0
    )
    suivi = suivi_service.record_versement(
        view.id, periode=periode, statut="impaye"
    )

    # Le règlement est annulé : l'encours revient à son montant d'origine.
    assert suivi["total_verse"] == pytest.approx(0.0)
    assert suivi["encours"] == pytest.approx(44_500_000.0)


def test_versement_superieur_a_l_encours_refuse(temp_db):
    view = create_exposition(_payload_avec_hors_bilan())

    with pytest.raises(suivi_service.SuiviValidationError):
        suivi_service.record_versement(
            view.id,
            periode=_periode_il_y_a(60),
            statut="verse",
            montant_verse=45_000_000.0,
        )

    # La ligne reste intacte : ni versement enregistré, ni encours modifié.
    suivi = suivi_service.get_suivi(view.id)
    assert suivi["entries"] == []
    assert suivi["encours"] == pytest.approx(44_500_000.0)


def test_periode_hors_vie_du_pret_refusee(temp_db):
    view = create_exposition(_payload_avec_hors_bilan())

    avant_octroi = (date.today() - timedelta(days=900)).strftime("%Y-%m")
    with pytest.raises(suivi_service.SuiviValidationError):
        suivi_service.record_versement(
            view.id, periode=avant_octroi, statut="verse"
        )


def test_maturites_du_suivi_alignees_sur_le_moteur(temp_db):
    view = create_exposition(_payload_avec_hors_bilan())
    suivi = suivi_service.get_suivi(view.id)

    assert suivi["maturite"] == pytest.approx(view.exposure_maturity_months / 12)
    assert suivi["maturite_residuelle"] == pytest.approx(
        view.residual_maturity_months / 12
    )


def test_creance_en_souffrance_n_est_jamais_annoncee_saine():
    """Catégorie « créances en souffrance » : douteuse sans impayé saisi."""

    assert (
        resolve_statut_prudentiel(
            jours_impayes=0, declassement_manuel=False, category_code="i"
        )
        == "douteuse"
    )
    record = build_exposure_record(
        _payload_entreprise(category="Creances en souffrance"), "TEST-SOUFFRANCE"
    )
    assert record["prudential_type"] == "i"
    assert record["statut_prudentiel"] == "douteuse"
