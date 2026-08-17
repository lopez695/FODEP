"""Persistance batch dédiée aux imports Excel."""

from __future__ import annotations

from typing import Any

from database.repositories.exposure_repository import exposure_repository
from database.repositories.off_balance_repository import off_balance_repository


class ImportRepository:
    """Centralise les opérations bulk liées au pipeline d'import."""

    def persist_import(
        self,
        *,
        exposure_records: list[dict[str, Any]],
        off_balance_records: list[dict[str, Any]],
        mode: str,
        connection,
    ) -> dict[str, int]:
        normalized_mode = mode.strip().lower()
        if normalized_mode not in {"merge", "replace"}:
            raise ValueError("Mode d'import non supporté.")

        if normalized_mode == "replace":
            exposure_repository.clear_portfolio(connection=connection)
            existing_exposure_ids: set[str] = set()
            existing_off_balance_ids: set[str] = set()
        else:
            existing_exposure_ids = exposure_repository.get_existing_ids(
                [str(record["id"]) for record in exposure_records],
                connection=connection,
            )
            existing_off_balance_ids = off_balance_repository.get_existing_ids(
                [str(record["id"]) for record in off_balance_records],
                connection=connection,
            )

        exposure_repository.upsert_exposures(exposure_records, connection=connection)
        off_balance_repository.upsert_commitments(off_balance_records, connection=connection)

        inserted_exposures = sum(
            1 for record in exposure_records if str(record["id"]) not in existing_exposure_ids
        )
        updated_exposures = len(exposure_records) - inserted_exposures
        inserted_off_balance = sum(
            1 for record in off_balance_records if str(record["id"]) not in existing_off_balance_ids
        )
        updated_off_balance = len(off_balance_records) - inserted_off_balance

        return {
            "inserted_exposures": inserted_exposures,
            "updated_exposures": updated_exposures,
            "inserted_off_balance": inserted_off_balance,
            "updated_off_balance": updated_off_balance,
        }


import_repository = ImportRepository()
