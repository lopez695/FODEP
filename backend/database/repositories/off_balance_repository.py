"""Accès SQLite aux engagements hors bilan."""

from __future__ import annotations

from contextlib import nullcontext
from typing import Any

from database.connection import database_manager, utcnow_iso

_SQLITE_CHUNK_SIZE = 400


def _chunked(values: list[str], size: int = _SQLITE_CHUNK_SIZE):
    for index in range(0, len(values), size):
        yield values[index : index + size]


class OffBalanceRepository:
    """Persiste et lit les engagements hors bilan."""

    def list_commitments(self, search: str | None = None, engagement_type: str | None = None) -> list[dict[str, Any]]:
        query = """
            SELECT
                hb.id,
                hb.date_analyse     AS analysis_date,
                hb.contrepartie_id  AS counterparty_id,
                cp.nom              AS counterparty_name,
                cp.categorie_standard AS category,
                cp.notation         AS rating,
                hb.type_engagement  AS engagement_type,
                hb.montant_nominal  AS nominal_amount,
                hb.ccf,
                hb.ead,
                hb.ponderation      AS risk_weight,
                hb.rwa,
                hb.capital,
                hb.commentaire      AS comment
            FROM engagements_hors_bilan hb
            INNER JOIN contreparties cp ON cp.id = hb.contrepartie_id
            WHERE 1 = 1
        """
        params: list[Any] = []
        if search:
            like = f"%{search.lower()}%"
            query += " AND (LOWER(hb.id) LIKE ? OR LOWER(cp.nom) LIKE ?)"
            params.extend([like, like])
        if engagement_type:
            query += " AND hb.type_engagement = ?"
            params.append(engagement_type)
        query += " ORDER BY hb.id"

        with database_manager.read_connection() as connection:
            rows = connection.execute(query, params).fetchall()
        return [dict(row) for row in rows]

    def next_commitment_id(self) -> str:
        with database_manager.read_connection() as connection:
            row = connection.execute(
                "SELECT MAX(CAST(SUBSTR(id, 3) AS INTEGER)) AS max_index "
                "FROM engagements_hors_bilan WHERE id GLOB 'HB[0-9]*'"
            ).fetchone()
        max_index = int(row["max_index"]) if row and row["max_index"] is not None else 0
        return f"HB{max_index + 1:03d}"

    def get_existing_ids(self, commitment_ids: list[str], *, connection=None) -> set[str]:
        normalized_ids = sorted({str(item).strip() for item in commitment_ids if str(item).strip()})
        if not normalized_ids:
            return set()

        active_connection = connection or database_manager.connect()
        try:
            existing_ids: set[str] = set()
            for chunk in _chunked(normalized_ids):
                placeholders = ", ".join("?" for _ in chunk)
                rows = active_connection.execute(
                    f"SELECT id FROM engagements_hors_bilan WHERE id IN ({placeholders})",
                    chunk,
                ).fetchall()
                existing_ids.update(str(row["id"]) for row in rows)
            return existing_ids
        finally:
            if connection is None:
                active_connection.close()

    def upsert_commitment(self, record: dict[str, Any], *, connection=None) -> dict[str, Any]:
        self.upsert_commitments([record], connection=connection)
        return record

    def upsert_commitments(self, records: list[dict[str, Any]], *, connection=None) -> list[dict[str, Any]]:
        if not records:
            return []
        manager = nullcontext(connection) if connection is not None else database_manager.transaction()
        with manager as active_connection:
            now = utcnow_iso()
            active_connection.executemany(
                """
                INSERT INTO engagements_hors_bilan(
                    id,
                    contrepartie_id,
                    date_analyse,
                    type_engagement,
                    montant_nominal,
                    ccf,
                    ead,
                    ponderation,
                    rwa,
                    capital,
                    commentaire,
                    cree_le,
                    modifie_le
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    contrepartie_id = excluded.contrepartie_id,
                    date_analyse = excluded.date_analyse,
                    type_engagement = excluded.type_engagement,
                    montant_nominal = excluded.montant_nominal,
                    ccf = excluded.ccf,
                    ead = excluded.ead,
                    ponderation = excluded.ponderation,
                    rwa = excluded.rwa,
                    capital = excluded.capital,
                    commentaire = excluded.commentaire,
                    modifie_le = excluded.modifie_le
                """,
                [
                    (
                        str(record["id"]),
                        str(record["counterparty_id"]),
                        record["analysis_date"].isoformat()
                        if hasattr(record["analysis_date"], "isoformat")
                        else str(record["analysis_date"]),
                        str(record["engagement_type"]),
                        float(record["nominal_amount"]),
                        float(record["ccf"]),
                        float(record["ead"]),
                        float(record["risk_weight"]),
                        float(record["rwa"]),
                        float(record["capital"]),
                        record.get("comment"),
                        now,
                        now,
                    )
                    for record in records
                ],
            )
        return [dict(record) for record in records]

off_balance_repository = OffBalanceRepository()
