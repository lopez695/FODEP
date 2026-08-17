"""Suivi mensuel des versements et cycle de vie prudentiel des expositions.

Le nombre de jours d'impayés n'est plus une saisie figée : il est dérivé de
l'historique des périodes marquées « impayé » (ancrage prudent au premier jour
du plus ancien mois impayé non régularisé). Le passage en créance douteuse est
automatique à partir de 90 jours, ou anticipé manuellement avec motif ; la
levée d'un déclassement manuel exige l'apurement des arriérés. Chaque action
est journalisée dans journal_operations : rien ne disparaît sans trace.

Les versements amortissent l'encours **bilan** : encours courant = encours
bilan d'origine - somme des versements. La part hors bilan (engagement non
tiré) n'est jamais touchée par un remboursement. L'encours amorti alimente
l'EAD bilan, donc le RWA et l'exigence de fonds propres : un remboursement
allège réellement la consommation de capital.
"""

from __future__ import annotations

import json
import logging
import re
import threading
from contextlib import nullcontext
from datetime import date
from typing import Any

from app.expositions.models import ExposureView
from database.connection import database_manager, utcnow_iso
from database.repositories.exposure_repository import exposure_repository
from database.repositories.suivi_versements_repository import (
    suivi_versements_repository,
)
from database.services.exposure_recalculation_service import (
    _payload_from_record,
    recalculate_all_exposures,
)
from database.services.rwa_calculation_service import (
    JOURS_IMPAYES_SEUIL_SOUFFRANCE,
    build_exposure_record,
    exposure_record_to_view,
    resolve_statut_prudentiel,
)

logger = logging.getLogger(__name__)

_PERIODE_PATTERN = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")
_STATUTS_VERSEMENT = ("verse", "impaye")
_JOURNAL_ENTITY_TYPE = "exposition_suivi"
_REFRESH_METADATA_KEY = "suivi_delinquency_refreshed_on"
# Tolérance d'arrondi sur les montants (le franc CFA n'a pas de subdivision,
# mais les saisies transitent par des flottants).
_TOLERANCE_MONTANT = 0.01


class ExpositionIntrouvableError(Exception):
    """L'exposition demandée n'existe pas."""


class SuiviValidationError(ValueError):
    """Saisie de suivi invalide (période, statut, montant ou motif)."""


class LeveeDeclassementRefuseeError(Exception):
    """Levée de déclassement impossible tant que les arriérés persistent."""


def _first_day_of_period(periode: str) -> date:
    return date(int(periode[:4]), int(periode[5:7]), 1)


def _derive_jours_impayes(
    oldest_unpaid_periode: str | None, reference: date | None = None
) -> int:
    if not oldest_unpaid_periode:
        return 0
    reference = reference or date.today()
    return max(0, (reference - _first_day_of_period(oldest_unpaid_periode)).days)


def _oldest_unpaid_periode(entries: list[dict[str, Any]]) -> str | None:
    unpaid = [
        str(entry["periode"]) for entry in entries if entry["statut"] == "impaye"
    ]
    return min(unpaid) if unpaid else None


def derive_jours_impayes_for(exposure_id: str) -> int:
    entries = suivi_versements_repository.list_for_exposure(exposure_id)
    return _derive_jours_impayes(_oldest_unpaid_periode(entries))


def _periode_of(value: Any) -> str | None:
    if not value:
        return None
    text = str(value)[:7]
    return text if _PERIODE_PATTERN.fullmatch(text) else None


def _validate_periode(periode: Any, record: dict[str, Any]) -> str:
    """Vérifie qu'un mois de suivi appartient bien à la vie du prêt."""

    periode = str(periode or "").strip()
    if not _PERIODE_PATTERN.fullmatch(periode):
        raise SuiviValidationError(
            "La période doit être au format AAAA-MM (ex. 2026-07)."
        )
    if periode > date.today().strftime("%Y-%m"):
        raise SuiviValidationError(
            "Impossible d'enregistrer un versement sur un mois futur."
        )
    octroi = _periode_of(record.get("grant_date"))
    if octroi is not None and periode < octroi:
        raise SuiviValidationError(
            f"Ce mois ({periode}) précède l'octroi du prêt ({octroi}) : "
            "aucune échéance n'était due."
        )
    echeance = _periode_of(record.get("maturity_date"))
    if echeance is not None and periode > echeance:
        raise SuiviValidationError(
            f"Ce mois ({periode}) est postérieur à l'échéance ({echeance}) : "
            "aucune échéance n'était due."
        )
    return periode


def _log_suivi(
    exposure_id: str,
    operation: str,
    payload: dict[str, Any],
    *,
    connection=None,
) -> None:
    manager = (
        nullcontext(connection)
        if connection is not None
        else database_manager.transaction()
    )
    with manager as active_connection:
        active_connection.execute(
            """
            INSERT INTO journal_operations(type_entite, entite_id, operation, payload_json, cree_le)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                _JOURNAL_ENTITY_TYPE,
                exposure_id,
                operation,
                json.dumps(payload, ensure_ascii=False),
                utcnow_iso(),
            ),
        )


def _rebuild_exposure(
    record: dict[str, Any], *, connection=None, **overrides: Any
) -> ExposureView:
    """Rejoue le calcul réglementaire d'une ligne avec ses valeurs de suivi."""

    payload = _payload_from_record(record)
    if overrides:
        payload = payload.model_copy(update=overrides)
    exposure_id = str(record["id"])
    rebuilt = build_exposure_record(payload, exposure_id)
    rebuilt["id"] = exposure_id
    exposure_repository.upsert_exposure(rebuilt, connection=connection)
    return exposure_record_to_view(rebuilt)


def _initial_on_balance(record: dict[str, Any]) -> float:
    """Encours bilan d'origine, base immuable de l'amortissement.

    Les lignes créées avant le suivi n'ont pas ce champ : l'encours bilan
    courant fait alors foi (aucun versement n'a encore été enregistré).
    """

    for key in ("initial_on_balance_amount", "on_balance_exposure_amount"):
        value = record.get(key)
        if value is not None and float(value) > 0:
            return float(value)
    return float(record.get("gross_amount") or 0.0)


def _off_balance_amount(record: dict[str, Any]) -> float:
    value = record.get("off_balance_exposure_amount")
    return max(0.0, float(value)) if value is not None else 0.0


def _total_verse(entries: list[dict[str, Any]]) -> float:
    return sum(
        float(entry.get("montant_verse") or 0.0)
        for entry in entries
        if entry.get("statut") == "verse"
    )


def _get_record_or_raise(exposure_id: str) -> dict[str, Any]:
    record = exposure_repository.get_exposure(exposure_id)
    if record is None:
        raise ExpositionIntrouvableError(
            f"Exposition {exposure_id} introuvable."
        )
    return record


def _journal_entries(exposure_id: str, limit: int = 50) -> list[dict[str, Any]]:
    with database_manager.read_connection() as connection:
        rows = connection.execute(
            """
            SELECT operation, payload_json, cree_le
            FROM journal_operations
            WHERE type_entite = ? AND entite_id = ?
            ORDER BY id DESC
            LIMIT ?
            """,
            (_JOURNAL_ENTITY_TYPE, exposure_id, limit),
        ).fetchall()
    entries: list[dict[str, Any]] = []
    for row in rows:
        try:
            payload = json.loads(str(row["payload_json"] or "{}"))
        except json.JSONDecodeError:
            payload = {}
        entries.append(
            {
                "operation": str(row["operation"]),
                "payload": payload,
                "cree_le": str(row["cree_le"]),
            }
        )
    return entries


def get_suivi(exposure_id: str) -> dict[str, Any]:
    """Vue complète du suivi d'une exposition (périodes, statut, journal)."""

    record = _get_record_or_raise(exposure_id)
    entries = suivi_versements_repository.list_for_exposure(exposure_id)
    if entries:
        jours_impayes = _derive_jours_impayes(_oldest_unpaid_periode(entries))
    else:
        jours_impayes = int(record.get("jours_impayes") or 0)
    statut = resolve_statut_prudentiel(
        jours_impayes=jours_impayes,
        declassement_manuel=bool(record.get("declassement_manuel")),
    )
    # Le temps qui passe aggrave les arriérés sans qu'aucune saisie n'ait lieu.
    # Si la ligne persistée ne reflète plus le statut dérivé, elle est
    # recalculée immédiatement : le panneau de suivi et le RWA du portefeuille
    # ne peuvent pas annoncer deux classements différents pour la même ligne.
    if int(record.get("jours_impayes") or 0) != jours_impayes or str(
        record.get("statut_prudentiel") or ""
    ) != statut:
        try:
            _rebuild_exposure(record, jours_impayes=jours_impayes)
            record = _get_record_or_raise(exposure_id)
        except Exception:
            logger.exception(
                "Le réalignement du statut prudentiel de %s a échoué ; "
                "valeurs persistées conservées.",
                exposure_id,
            )
    return {
        "exposure_id": str(record["id"]),
        "counterparty_name": str(record.get("counterparty_name") or ""),
        "notation": record.get("rating"),
        "encours": record.get("gross_amount"),
        "montant_initial": _initial_on_balance(record),
        "montant_hors_bilan": _off_balance_amount(record),
        "total_verse": _total_verse(entries),
        "devise": record.get("currency") or "XOF",
        "ponderation": record.get("final_rw", record.get("risk_weight")),
        "rwa": record.get("rwa"),
        "ead": record.get("ead_total_amount", record.get("ead")),
        "statut_prudentiel": statut,
        "jours_impayes": jours_impayes,
        "jours_impayes_suivis": bool(entries),
        "seuil_jours_souffrance": JOURS_IMPAYES_SEUIL_SOUFFRANCE,
        "declassement_manuel": bool(record.get("declassement_manuel")),
        "declassement_motif": record.get("declassement_motif"),
        "declassement_le": record.get("declassement_le"),
        "periode_courante": date.today().strftime("%Y-%m"),
        "date_octroi": record.get("grant_date"),
        "date_echeance": record.get("maturity_date"),
        "maturite": _maturite_en_annees(record.get("exposure_maturity_months")),
        "maturite_residuelle": _maturite_en_annees(
            record.get("residual_maturity_months")
        ),
        "entries": entries,
        "journal": _journal_entries(exposure_id),
    }


def _maturite_en_annees(months: Any) -> float | None:
    """Maturité en années à partir des mois déjà calculés par le moteur.

    Le panneau de suivi ne recalcule pas les maturités : il réutilise celles
    qui ont servi à pondérer la ligne, sans quoi il afficherait une durée
    différente de celle utilisée par le calcul réglementaire.
    """

    if months is None:
        return None
    try:
        return max(0.0, int(months) / 12.0)
    except (TypeError, ValueError):
        return None


def record_versement(
    exposure_id: str,
    *,
    periode: str,
    statut: str,
    montant_verse: float | None = None,
    commentaire: str | None = None,
) -> dict[str, Any]:
    """Enregistre (ou corrige) le versement d'un mois puis recalcule la ligne."""

    record = _get_record_or_raise(exposure_id)
    periode = _validate_periode(periode, record)
    statut = str(statut or "").strip().lower()
    if statut not in _STATUTS_VERSEMENT:
        raise SuiviValidationError(
            "Le statut du mois doit être 'verse' ou 'impaye'."
        )
    if montant_verse is not None and float(montant_verse) < 0:
        raise SuiviValidationError("Le montant versé ne peut pas être négatif.")
    # Un mois impayé ne porte aucun versement : conserver un montant sur une
    # période déclarée impayée reviendrait à amortir l'encours avec un
    # règlement qui n'a pas eu lieu.
    montant = (
        float(montant_verse)
        if statut == "verse" and montant_verse is not None
        else None
    )

    encours_initial = _initial_on_balance(record)
    hors_bilan = _off_balance_amount(record)

    with database_manager.transaction() as connection:
        previous = suivi_versements_repository.get_entry(exposure_id, periode)
        suivi_versements_repository.upsert_entry(
            exposure_id=exposure_id,
            periode=periode,
            statut=statut,
            montant_verse=montant,
            commentaire=(commentaire or "").strip() or None,
            connection=connection,
        )
        entries = suivi_versements_repository.list_for_exposure(
            exposure_id, connection=connection
        )
        total_verse = _total_verse(entries)
        # Le cumul des remboursements ne peut pas excéder le capital prêté :
        # au-delà, l'encours deviendrait négatif et le RWA perdrait tout sens.
        if total_verse > encours_initial + _TOLERANCE_MONTANT:
            raise SuiviValidationError(
                "Le cumul des versements "
                f"({total_verse:,.0f}) dépasse l'encours d'origine "
                f"({encours_initial:,.0f}). Corrigez le montant saisi."
                .replace(",", " ")
            )

        _log_suivi(
            exposure_id,
            "versement_enregistre" if statut == "verse" else "impaye_enregistre",
            {
                "periode": periode,
                "statut": statut,
                "montant_verse": montant,
                "commentaire": (commentaire or "").strip() or None,
                "precedent": (
                    {
                        "statut": previous["statut"],
                        "montant_verse": previous["montant_verse"],
                    }
                    if previous
                    else None
                ),
            },
            connection=connection,
        )

        _apply_entries_to_exposure(record, entries, connection=connection)
    return get_suivi(exposure_id)


def _apply_entries_to_exposure(
    record: dict[str, Any],
    entries: list[dict[str, Any]],
    *,
    connection=None,
) -> ExposureView:
    """Reporte l'historique des versements sur la ligne d'exposition.

    Les versements amortissent le seul encours bilan ; l'engagement hors bilan
    non tiré reste dû et conserve son montant. L'encours amorti devient l'EAD
    bilan, d'où découlent le RWA et l'exigence de fonds propres.
    """

    encours_initial = _initial_on_balance(record)
    hors_bilan = _off_balance_amount(record)
    nouvel_encours = max(encours_initial - _total_verse(entries), 0.0)
    return _rebuild_exposure(
        record,
        connection=connection,
        jours_impayes=_derive_jours_impayes(_oldest_unpaid_periode(entries)),
        gross_amount=nouvel_encours,
        on_balance_exposure_amount=nouvel_encours,
        initial_on_balance_amount=encours_initial,
        off_balance_exposure_amount=hors_bilan,
        loan_total_amount=encours_initial + hors_bilan,
    )


def declasser_exposition(exposure_id: str, *, motif: str) -> dict[str, Any]:
    """Déclasse manuellement une exposition en créance douteuse (motif requis)."""

    record = _get_record_or_raise(exposure_id)
    motif = str(motif or "").strip()
    if not motif:
        raise SuiviValidationError("Le motif du déclassement est obligatoire.")
    if bool(record.get("declassement_manuel")):
        raise SuiviValidationError(
            "Cette exposition est déjà déclassée manuellement."
        )
    horodatage = utcnow_iso()
    _log_suivi(
        exposure_id,
        "declassement_manuel",
        {"motif": motif, "statut_precedent": record.get("statut_prudentiel")},
    )
    jours = (
        derive_jours_impayes_for(exposure_id)
        if suivi_versements_repository.has_entries(exposure_id)
        else int(record.get("jours_impayes") or 0)
    )
    _rebuild_exposure(
        record,
        jours_impayes=jours,
        declassement_manuel=True,
        declassement_motif=motif,
        declassement_le=horodatage,
    )
    return get_suivi(exposure_id)


def lever_declassement(exposure_id: str, *, motif: str) -> dict[str, Any]:
    """Lève un déclassement manuel, uniquement après apurement des arriérés."""

    record = _get_record_or_raise(exposure_id)
    motif = str(motif or "").strip()
    if not motif:
        raise SuiviValidationError("Le motif de la levée est obligatoire.")
    if not bool(record.get("declassement_manuel")):
        raise SuiviValidationError(
            "Cette exposition n'est pas déclassée manuellement."
        )
    jours = (
        derive_jours_impayes_for(exposure_id)
        if suivi_versements_repository.has_entries(exposure_id)
        else int(record.get("jours_impayes") or 0)
    )
    if jours >= JOURS_IMPAYES_SEUIL_SOUFFRANCE:
        raise LeveeDeclassementRefuseeError(
            "Levée impossible : les arriérés ne sont pas apurés "
            f"({jours} jours d'impayés, seuil {JOURS_IMPAYES_SEUIL_SOUFFRANCE})."
        )
    _log_suivi(
        exposure_id,
        "levee_declassement",
        {"motif": motif, "jours_impayes": jours},
    )
    _rebuild_exposure(
        record,
        jours_impayes=jours,
        declassement_manuel=False,
        declassement_motif=None,
        declassement_le=None,
    )
    return get_suivi(exposure_id)


def apply_server_side_suivi(payload, exposure_id: str):
    """Protège les champs de suivi contre l'écrasement par une édition de formulaire.

    Le statut prudentiel et les jours d'impayés dérivés appartiennent au
    serveur : une mise à jour via PUT ne peut ni lever un déclassement ni
    réécrire un historique de versements.
    """

    record = exposure_repository.get_exposure(exposure_id)
    if record is None:
        return payload
    protections: dict[str, Any] = {
        "declassement_manuel": bool(record.get("declassement_manuel")),
        "declassement_motif": record.get("declassement_motif"),
        "declassement_le": record.get("declassement_le"),
    }
    if suivi_versements_repository.has_entries(exposure_id):
        protections["jours_impayes"] = derive_jours_impayes_for(exposure_id)
    return payload.model_copy(update=protections)


def refresh_delinquency(*, force: bool = False) -> dict[str, Any]:
    """Réaligne les lignes suivies sur leur historique de versements.

    Deux dérives sont corrigées ici : les jours d'impayés, qui s'aggravent avec
    le temps sans qu'aucune saisie n'ait lieu, et l'encours amorti, qui doit
    toujours valoir « encours d'origine - cumul des versements ». Le passage
    est idempotent : une ligne déjà juste n'est pas réécrite.
    """

    today = date.today().isoformat()
    with database_manager.read_connection() as connection:
        row = connection.execute(
            "SELECT valeur FROM metadonnees_app WHERE cle = ?",
            (_REFRESH_METADATA_KEY,),
        ).fetchone()
    if not force and row is not None and str(row["valeur"]) == today:
        return {"status": "skipped", "reason": "already_refreshed_today"}

    refreshed = 0
    for exposure_id in sorted(suivi_versements_repository.tracked_exposure_ids()):
        record = exposure_repository.get_exposure(exposure_id)
        if record is None:
            continue
        entries = suivi_versements_repository.list_for_exposure(exposure_id)
        derived = _derive_jours_impayes(_oldest_unpaid_periode(entries))
        encours_attendu = max(
            _initial_on_balance(record) - _total_verse(entries), 0.0
        )
        if int(record.get("jours_impayes") or 0) == derived and abs(
            float(record.get("gross_amount") or 0.0) - encours_attendu
        ) <= _TOLERANCE_MONTANT:
            continue
        try:
            _apply_entries_to_exposure(record, entries)
            refreshed += 1
        except Exception:
            logger.exception(
                "Le rafraîchissement des impayés de %s a échoué ; ligne conservée.",
                exposure_id,
            )

    with database_manager.transaction() as connection:
        connection.execute(
            """
            INSERT INTO metadonnees_app(cle, valeur) VALUES(?, ?)
            ON CONFLICT(cle) DO UPDATE SET valeur = excluded.valeur
            """,
            (_REFRESH_METADATA_KEY, today),
        )
    if refreshed:
        logger.info(
            "Jours d'impayés dérivés rafraîchis pour %s exposition(s).", refreshed
        )
    return {"status": "completed", "refreshed_count": refreshed}


def _startup_realignment() -> None:
    """Recalcul réglementaire puis réalignement du suivi, dans cet ordre.

    Les deux passes réécrivent les mêmes lignes. Les enchaîner dans un seul fil
    évite qu'un recalcul lancé en parallèle ne restaure un encours non amorti à
    partir d'un état lu avant le réalignement.
    """

    try:
        recalculate_all_exposures()
    except Exception:
        logger.exception(
            "Le recalcul réglementaire de démarrage a échoué ; "
            "le réalignement du suivi continue."
        )
    try:
        refresh_delinquency()
    except Exception:
        logger.exception("Le réalignement du suivi des versements a échoué.")


def schedule_startup_delinquency_refresh() -> None:
    """Réaligne les expositions en arrière-plan au démarrage de l'API."""

    thread = threading.Thread(
        target=_startup_realignment,
        name="suivi-delinquency-refresh",
        daemon=True,
    )
    thread.start()
