"""Synchronisation légère des champs Expositions entre Excel source et SQLite."""

from __future__ import annotations

from datetime import datetime, timezone
import logging
from pathlib import Path
import shutil
from threading import Lock, Thread
from typing import Any

from app.core.excel_repository import ExcelImportValidationError, excel_repository
from app.core.runtime_paths import is_packaged_runtime, seed_data_path
from database.connection import database_manager, utcnow_iso
from database.repositories.exposure_repository import exposure_repository

logger = logging.getLogger(__name__)

_SYNC_METADATA_KEYS = (
    "active_excel_source_path",
    "last_exposure_reference_backfill_at",
    "last_exposure_reference_source_mtime",
    "last_upload_import_at",
)


def _has_value(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    return True


def _parse_utc_datetime(value: Any) -> datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    normalized = text.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def _parse_float(value: Any) -> float | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


class ExposureSyncService:
    """Complète SQLite avec les dates/référentiels portés par le classeur source."""

    def __init__(self) -> None:
        self._state_lock = Lock()
        self._is_running = False

    def schedule_reference_fields_backfill(
        self,
        *,
        force: bool = False,
    ) -> dict[str, Any]:
        source_path = excel_repository.source_path
        if not source_path.exists():
            return {
                "status": "skipped",
                "reason": "excel_source_not_found",
                "source_path": str(source_path),
                "updated_count": 0,
            }
        if not force:
            skip_payload = self._build_skip_payload_if_fresh(source_path)
            if skip_payload is not None:
                return skip_payload

        with self._state_lock:
            if self._is_running:
                return {
                    "status": "already_running",
                    "source_path": str(source_path),
                }
            self._is_running = True

        Thread(
            target=self._run_backfill_job,
            kwargs={"force": force},
            name="exposure-reference-backfill",
            daemon=True,
        ).start()
        return {
            "status": "scheduled",
            "source_path": str(source_path),
        }

    def backfill_reference_fields_from_excel(
        self,
        *,
        force: bool = False,
    ) -> dict[str, Any]:
        source_path = excel_repository.source_path
        if not source_path.exists():
            return {
                "status": "skipped",
                "reason": "excel_source_not_found",
                "source_path": str(source_path),
                "updated_count": 0,
            }

        if not force:
            skip_payload = self._build_skip_payload_if_fresh(source_path)
            if skip_payload is not None:
                return skip_payload

        workbook_index = self._load_workbook_index(source_path)
        sqlite_records = exposure_repository.list_exposures()
        if not sqlite_records:
            self._write_sync_metadata(
                source_path=source_path,
                updated_count=0,
                matched_count=0,
            )
            return {
                "status": "success",
                "source_path": str(source_path),
                "matched_count": 0,
                "updated_count": 0,
                "backup_path": None,
            }

        records_to_update: list[dict[str, Any]] = []
        matched_count = 0
        for record in sqlite_records:
            template_fields = workbook_index.get(str(record["id"]))
            if template_fields is None:
                continue
            matched_count += 1
            updated = False

            if not _has_value(record.get("grant_date")) and template_fields.get("grant_date") is not None:
                record["grant_date"] = template_fields["grant_date"]
                updated = True

            if not _has_value(record.get("maturity_date")) and template_fields.get("maturity_date") is not None:
                record["maturity_date"] = template_fields["maturity_date"]
                updated = True

            current_country_rating = str(record.get("country_rating") or "").strip()
            source_country_rating = str(template_fields.get("country_rating") or "").strip()
            if (
                (not current_country_rating or current_country_rating == "Non noté")
                and source_country_rating
                and source_country_rating != "Non noté"
            ):
                record["country_rating"] = source_country_rating
                updated = True

            if updated:
                records_to_update.append(record)

        backup_path = (
            database_manager.create_backup("before_exposure_reference_backfill")
            if records_to_update
            else None
        )
        if records_to_update:
            with database_manager.transaction() as connection:
                exposure_repository.upsert_exposures(records_to_update, connection=connection)
                self._write_sync_metadata(
                    source_path=source_path,
                    updated_count=len(records_to_update),
                    matched_count=matched_count,
                    connection=connection,
                )
        else:
            self._write_sync_metadata(
                source_path=source_path,
                updated_count=0,
                matched_count=matched_count,
            )

        return {
            "status": "success",
            "source_path": str(source_path),
            "matched_count": matched_count,
            "updated_count": len(records_to_update),
            "backup_path": str(backup_path) if backup_path is not None else None,
        }

    def _load_workbook_index(self, source_path: Path) -> dict[str, dict[str, Any]]:
        try:
            return excel_repository.exposure_template_fields_by_id()
        except ExcelImportValidationError:
            if not self._restore_packaged_workbook(source_path):
                logger.warning(
                    "Le classeur Excel local ne correspond pas au format complet attendu. "
                    "Le backfill des references Expositions continue en mode compatibilite: %s",
                    source_path,
                )
                return excel_repository.exposure_template_fields_by_id_relaxed()
            return excel_repository.exposure_template_fields_by_id()

    def _restore_packaged_workbook(self, source_path: Path) -> bool:
        if not is_packaged_runtime():
            return False

        packaged_template_path = seed_data_path("modele_import_rwa.xlsx")
        if not packaged_template_path.is_file():
            return False

        try:
            if packaged_template_path.resolve() == source_path.resolve():
                return False
        except OSError:
            return False

        source_path.parent.mkdir(parents=True, exist_ok=True)
        if source_path.exists():
            backup_path = source_path.with_name(
                f"{source_path.stem}_invalid_backup_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}{source_path.suffix}"
            )
            shutil.copy2(source_path, backup_path)

        shutil.copy2(packaged_template_path, source_path)
        logger.warning(
            "Le modèle Excel local était invalide. Restauration depuis le modèle embarqué: %s",
            packaged_template_path,
        )
        return True

    def _run_backfill_job(self, *, force: bool) -> None:
        try:
            result = self.backfill_reference_fields_from_excel(force=force)
            logger.info(
                "Backfill Expositions terminé: statut=%s source=%s",
                result.get("status"),
                result.get("source_path"),
            )
        except Exception:
            logger.exception(
                "Le backfill asynchrone des champs Expositions depuis Excel a échoué."
            )
        finally:
            with self._state_lock:
                self._is_running = False

    def _build_skip_payload_if_fresh(self, source_path: Path) -> dict[str, Any] | None:
        metadata = self._read_sync_metadata()
        if not metadata:
            return None

        active_source_path = str(metadata.get("active_excel_source_path") or "").strip()
        if active_source_path != str(source_path):
            return None

        last_backfill_at = _parse_utc_datetime(
            metadata.get("last_exposure_reference_backfill_at")
        )
        if last_backfill_at is None:
            return None

        last_upload_import_at = _parse_utc_datetime(metadata.get("last_upload_import_at"))
        if last_upload_import_at is not None and last_upload_import_at > last_backfill_at:
            return None

        current_mtime = source_path.stat().st_mtime
        stored_mtime = _parse_float(metadata.get("last_exposure_reference_source_mtime"))
        if stored_mtime is not None and abs(current_mtime - stored_mtime) < 0.001:
            return {
                "status": "skipped",
                "reason": "excel_source_unchanged",
                "source_path": str(source_path),
                "updated_count": 0,
            }

        current_mtime_dt = datetime.fromtimestamp(current_mtime, tz=timezone.utc)
        if current_mtime_dt <= last_backfill_at:
            return {
                "status": "skipped",
                "reason": "excel_source_not_modified_since_last_backfill",
                "source_path": str(source_path),
                "updated_count": 0,
            }

        return None

    def _read_sync_metadata(self) -> dict[str, str]:
        placeholders = ", ".join("?" for _ in _SYNC_METADATA_KEYS)
        with database_manager.read_connection() as connection:
            rows = connection.execute(
                f"""
                SELECT cle AS key, valeur AS value
                FROM metadonnees_app
                WHERE cle IN ({placeholders})
                """,
                _SYNC_METADATA_KEYS,
            ).fetchall()
        return {
            str(row["key"]): str(row["value"])
            for row in rows
            if row["key"] is not None and row["value"] is not None
        }

    def _write_sync_metadata(
        self,
        *,
        source_path: Path,
        updated_count: int,
        matched_count: int,
        connection=None,
    ) -> None:
        payload = {
            "active_excel_source_path": str(source_path),
            "last_exposure_reference_backfill_at": utcnow_iso(),
            "last_exposure_reference_backfill_count": str(updated_count),
            "last_exposure_reference_match_count": str(matched_count),
            "last_exposure_reference_source_mtime": f"{source_path.stat().st_mtime:.6f}",
            "storage_backend": "sqlite",
        }
        if connection is not None:
            self._write_metadata_payload(connection, payload)
            return
        with database_manager.transaction() as active_connection:
            self._write_metadata_payload(active_connection, payload)

    @staticmethod
    def _write_metadata_payload(connection, payload: dict[str, str]) -> None:
        for key, value in payload.items():
            connection.execute(
                """
                INSERT INTO metadonnees_app(cle, valeur)
                VALUES(?, ?)
                ON CONFLICT(cle) DO UPDATE SET valeur = excluded.valeur
                """,
                (key, value),
            )


exposure_sync_service = ExposureSyncService()
