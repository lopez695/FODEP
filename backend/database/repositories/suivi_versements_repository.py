"""Accès SQLite au suivi mensuel des versements."""

from __future__ import annotations

from contextlib import nullcontext
from typing import Any

from database.connection import database_manager, utcnow_iso


class SuiviVersementsRepository:
    """Persiste et lit les périodes de versement d'une exposition."""

    def list_for_exposure(
        self, exposure_id: str, *, connection=None
    ) -> list[dict[str, Any]]:
        # `connection` permet de lire les lignes déjà écrites mais non encore
        # validées dans la transaction en cours : une connexion de lecture
        # séparée (WAL) ne les verrait pas.
        manager = (
            nullcontext(connection)
            if connection is not None
            else database_manager.read_connection()
        )
        with manager as active_connection:
            rows = active_connection.execute(
                """
                SELECT id, exposition_id, periode, statut, montant_verse,
                       commentaire, cree_le, modifie_le
                FROM suivi_versements
                WHERE exposition_id = ?
                ORDER BY periode DESC
                """,
                (exposure_id.strip(),),
            ).fetchall()
        return [dict(row) for row in rows]

    def list_all_reimbursements(self) -> dict[str, dict[str, float]]:
        """Retourne tous les versements (statut = verse) groupés par exposition."""
        with database_manager.read_connection() as connection:
            rows = connection.execute(
                """
                SELECT exposition_id, periode, montant_verse
                FROM suivi_versements
                WHERE statut = 'verse'
                """
            ).fetchall()
        result: dict[str, dict[str, float]] = {}
        for row in rows:
            exp_id = str(row["exposition_id"])
            if exp_id not in result:
                result[exp_id] = {}
            if row["montant_verse"] is not None:
                result[exp_id][str(row["periode"])] = float(row["montant_verse"])
        return result

    def get_entry(self, exposure_id: str, periode: str) -> dict[str, Any] | None:
        with database_manager.read_connection() as connection:
            row = connection.execute(
                """
                SELECT id, exposition_id, periode, statut, montant_verse,
                       commentaire, cree_le, modifie_le
                FROM suivi_versements
                WHERE exposition_id = ? AND periode = ?
                """,
                (exposure_id.strip(), periode.strip()),
            ).fetchone()
        return dict(row) if row is not None else None

    def upsert_entry(
        self,
        *,
        exposure_id: str,
        periode: str,
        statut: str,
        montant_verse: float | None,
        commentaire: str | None,
        connection=None,
    ) -> None:
        manager = (
            nullcontext(connection)
            if connection is not None
            else database_manager.transaction()
        )
        now = utcnow_iso()
        with manager as active_connection:
            active_connection.execute(
                """
                INSERT INTO suivi_versements(
                    exposition_id, periode, statut, montant_verse,
                    commentaire, cree_le, modifie_le
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(exposition_id, periode) DO UPDATE SET
                    statut        = excluded.statut,
                    montant_verse = excluded.montant_verse,
                    commentaire   = excluded.commentaire,
                    modifie_le    = excluded.modifie_le
                """,
                (
                    exposure_id.strip(),
                    periode.strip(),
                    statut,
                    montant_verse,
                    commentaire,
                    now,
                    now,
                ),
            )

    def has_entries(self, exposure_id: str) -> bool:
        with database_manager.read_connection() as connection:
            row = connection.execute(
                "SELECT 1 FROM suivi_versements WHERE exposition_id = ? LIMIT 1",
                (exposure_id.strip(),),
            ).fetchone()
        return row is not None

    def oldest_unpaid_periods(self) -> dict[str, str]:
        """Plus ancienne période encore impayée, par exposition."""

        with database_manager.read_connection() as connection:
            rows = connection.execute(
                """
                SELECT exposition_id, MIN(periode) AS periode
                FROM suivi_versements
                WHERE statut = 'impaye'
                GROUP BY exposition_id
                """
            ).fetchall()
        return {str(row["exposition_id"]): str(row["periode"]) for row in rows}

    def tracked_exposure_ids(self) -> set[str]:
        with database_manager.read_connection() as connection:
            rows = connection.execute(
                "SELECT DISTINCT exposition_id FROM suivi_versements"
            ).fetchall()
        return {str(row["exposition_id"]) for row in rows}


suivi_versements_repository = SuiviVersementsRepository()
