"""Recalcul global des expositions lorsque les règles prudentielles évoluent.

Les métriques (pondération, EAD, RWA, capital) sont persistées au moment de la
création ou de l'import d'une exposition. Quand les règles de calcul changent
(correction d'un barème, alignement sur le dispositif prudentiel...), les
lignes déjà en base conservent leurs anciennes valeurs : ce service rejoue
build_exposure_record sur chaque ligne à partir de ses données sources, puis
réécrit les métriques. Il est déclenché au démarrage de l'API dès que la
version des règles (CALC_RULES_VERSION) diffère de celle enregistrée en base.
"""

from __future__ import annotations

import logging
import threading
from datetime import date
from typing import Any

from app.expositions.models import ExposureCreate, ExposureCrmDetails
from database.connection import database_manager, utcnow_iso
from database.repositories.exposure_repository import exposure_repository
from database.services.rwa_calculation_service import build_exposure_record

logger = logging.getLogger(__name__)

# Incrémenter à chaque évolution des règles de calcul pour déclencher un
# recalcul automatique des expositions persistées au prochain démarrage.
# 2026-07-19 v1 : alignement sur le dispositif prudentiel UMOA (plancher pays
# limité aux entreprises, grille IF par maturité, défaut prudent à 150 %,
# ARC financée sans double déduction, Hfx 8 %, capital minimum 9 %).
# 2026-07-19 v2 : dates d'octroi incohérentes (postérieures à l'échéance ou à
# la date d'analyse) ignorées — maturité initiale indéterminée et traitement
# long terme prudent au lieu d'un faux « 0 mois » ouvrant le court terme.
# 2026-07-19 v3 : statut prudentiel de vie — toute exposition avec >= 90 jours
# d'impayés (ou déclassée manuellement) est pondérée comme une créance en
# souffrance (150 %, 100 % si provisions >= 20 %) sans perdre sa catégorie.
# 2026-07-21 v4 : les versements amortissent l'encours BILAN (et non plus
# l'engagement total, part hors bilan comprise) ; l'encours amorti alimente
# désormais l'EAD bilan, donc le RWA et l'exigence de fonds propres. Le taux de
# provisionnement d'une créance en souffrance se mesure sur l'encours bilan.
# 2026-07-21 v5 : une ligne classée en catégorie « créances en souffrance » est
# douteuse par construction — elle ne peut plus être annoncée saine dans le
# suivi ni échapper au taux de créances en souffrance du tableau de bord.
# 2026-07-22 v6 : la sûreté financée est ramenée dans la devise réelle de
# l'exposition. Le détail CRM portait « XOF » par défaut : sur une ligne en
# EUR ou en USD, le collatéral était multiplié par le cours et effaçait
# l'exposition (EAD et RWA nuls sur 9 lignes du portefeuille de référence).
# 2026-07-22 v7 : une garantie personnelle ne peut plus alourdir l'exigence.
# La substitution n'est retenue que si le garant est moins lourdement pondéré
# que le débiteur ; sinon la pondération du débiteur est conservée. Supprime
# du même coup le plafond de 150 % appliqué à la pondération moyenne, qui
# n'avait pas de fondement dans le dispositif.
# 2026-08-11 v8 : l'EAD est calculée sur l'encours bilan net de provisions. Le
# provisionnement absorbe déjà la perte attendue ; pondérer le brut exigeait
# des fonds propres contre un risque déjà couvert et écartait le tableau de
# bord de la déclaration prudentielle (§ 8.6.2 de la notice FODEP). L'encours
# brut reste porté par l'exposition, en regard de ses provisions.
CALC_RULES_VERSION = "2026-08-11-dispositif-umoa-v8"

_METADATA_KEY = "exposure_calc_rules_version"

_PAYLOAD_FIELDS: tuple[str, ...] = (
    "analysis_date",
    "grant_date",
    "maturity_date",
    "counterparty_name",
    "country",
    "country_rating",
    "rating",
    "gross_amount",
    "loan_total_amount",
    "on_balance_exposure_amount",
    "initial_on_balance_amount",
    "off_balance_exposure_amount",
    "provisions_amount",
    "jours_impayes",
    "currency",
    "status",
    "declassement_manuel",
    "declassement_motif",
    "declassement_le",
    "sovereign_special_case",
    "sovereign_preferential_zero_weight",
    "sovereign_oce_established",
    "sovereign_oce_note",
    "public_body_uemoa_fcfa_case",
    "public_body_non_public_activity",
    "bmd_high_quality_case",
    "bmd_uemoa_fcfa_case",
    "bmd_uemoa_criteria_satisfied",
    "bmd_listed_institution_fcfa_case",
    "bank_institution_case",
    "other_asset_type",
    "off_balance_risk_level",
    "retail_eligibility_criteria_satisfied",
    "residential_mortgage_eligible",
    "commercial_real_estate_eligible",
    "defaulted_exposure_initial_risk_weight",
    "defaulted_exposure_residential_mortgage_in_default",
    "defaulted_exposure_provision_at_least_twenty_percent",
    "enterprise_exceeds_bceao_degradation_threshold",
    "enterprise_prudential_procedure",
    "enterprise_investment_firm_without_banking_law",
    "crm_type",
    "crm_coverage_percent",
    "comment",
)


def _coerce_date(value: Any) -> date | None:
    if value is None or isinstance(value, date):
        return value
    try:
        return date.fromisoformat(str(value)[:10])
    except ValueError:
        return None


def _payload_from_record(record: dict[str, Any]) -> ExposureCreate:
    data: dict[str, Any] = {}
    for field in _PAYLOAD_FIELDS:
        if field in record and record[field] is not None:
            data[field] = record[field]
    for date_field in ("analysis_date", "grant_date", "maturity_date"):
        if date_field in data:
            coerced = _coerce_date(data[date_field])
            if coerced is None:
                data.pop(date_field)
            else:
                data[date_field] = coerced
    data.setdefault("analysis_date", date.today())
    data["category"] = str(
        record.get("category_raw")
        or record.get("category_standard")
        or "Entreprises"
    )
    crm_details = record.get("crm_details")
    if isinstance(crm_details, dict) and crm_details:
        try:
            data["crm_details"] = ExposureCrmDetails(**crm_details)
        except (TypeError, ValueError):
            logger.warning(
                "Détails CRM illisibles pour %s : recalcul sans CRM détaillée.",
                record.get("id"),
            )
    return ExposureCreate(**data)


def _read_stored_rules_version() -> str | None:
    with database_manager.read_connection() as connection:
        row = connection.execute(
            "SELECT valeur FROM metadonnees_app WHERE cle = ?",
            (_METADATA_KEY,),
        ).fetchone()
    return str(row["valeur"]) if row and row["valeur"] is not None else None


def _write_rules_version() -> None:
    with database_manager.transaction() as connection:
        connection.execute(
            """
            INSERT INTO metadonnees_app(cle, valeur)
            VALUES(?, ?)
            ON CONFLICT(cle) DO UPDATE SET valeur = excluded.valeur
            """,
            (_METADATA_KEY, CALC_RULES_VERSION),
        )
        connection.execute(
            """
            INSERT INTO metadonnees_app(cle, valeur)
            VALUES('exposure_calc_rules_recalculated_at', ?)
            ON CONFLICT(cle) DO UPDATE SET valeur = excluded.valeur
            """,
            (utcnow_iso(),),
        )


def recalculate_all_exposures(*, force: bool = False) -> dict[str, Any]:
    """Rejoue le calcul réglementaire sur toutes les expositions persistées."""

    stored_version = _read_stored_rules_version()
    if not force and stored_version == CALC_RULES_VERSION:
        return {
            "status": "skipped",
            "reason": "calc_rules_version_up_to_date",
            "version": CALC_RULES_VERSION,
            "recalculated_count": 0,
        }

    try:
        database_manager.create_backup("before_calc_rules_recalculation")
    except Exception:
        logger.exception(
            "La sauvegarde préalable au recalcul des expositions a échoué ; "
            "le recalcul continue sans sauvegarde."
        )

    records = exposure_repository.list_exposures()
    recalculated = 0
    failures = 0
    for record in records:
        exposure_id = str(record.get("id") or "")
        if not exposure_id:
            continue
        try:
            payload = _payload_from_record(record)
            rebuilt = build_exposure_record(payload, exposure_id)
            rebuilt["id"] = exposure_id
            exposure_repository.upsert_exposure(rebuilt)
            recalculated += 1
        except Exception:
            failures += 1
            logger.exception(
                "Le recalcul de l'exposition %s a échoué ; ligne conservée en l'état.",
                exposure_id,
            )

    _write_rules_version()
    logger.info(
        "Recalcul réglementaire des expositions terminé : %s recalculées, %s échecs (version %s).",
        recalculated,
        failures,
        CALC_RULES_VERSION,
    )
    return {
        "status": "completed",
        "version": CALC_RULES_VERSION,
        "previous_version": stored_version,
        "recalculated_count": recalculated,
        "failure_count": failures,
    }


def schedule_startup_recalculation() -> None:
    """Lance le recalcul en arrière-plan si la version des règles a changé."""

    if _read_stored_rules_version() == CALC_RULES_VERSION:
        return
    thread = threading.Thread(
        target=recalculate_all_exposures,
        name="exposure-calc-rules-recalculation",
        daemon=True,
    )
    thread.start()
