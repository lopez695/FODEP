"""Acces SQLite aux rapports generes."""

from __future__ import annotations

from contextlib import nullcontext
from typing import Any

from database.connection import database_manager


def _bool_to_int(value: bool) -> int:
    return 1 if value else 0


class ReportRepository:
    """Persiste les rapports et leurs lignes dans SQLite."""

    def list_reports(self) -> list[dict[str, Any]]:
        with database_manager.read_connection() as connection:
            report_rows = connection.execute(
                """
                SELECT
                    id,
                    cree_le         AS created_at,
                    periode         AS period,
                    type_rapport    AS report_type,
                    devise          AS currency,
                    perimetre_exposition AS exposure_scope,
                    inclure_graphe_categorie AS include_category_chart,
                    inclure_graphe_notation  AS include_rating_chart,
                    chemin_export_pdf   AS export_pdf_path,
                    chemin_export_excel AS export_excel_path
                FROM rapports
                ORDER BY cree_le DESC, id DESC
                """
            ).fetchall()

            line_rows = connection.execute(
                """
                SELECT
                    rapport_id      AS report_id,
                    ordre_ligne     AS line_order,
                    source,
                    element_id      AS item_id,
                    contrepartie    AS counterparty,
                    montant         AS amount,
                    ead,
                    rwa,
                    capital
                FROM lignes_rapport
                ORDER BY rapport_id, ordre_ligne
                """
            ).fetchall()

        lines_by_report: dict[str, list[dict[str, Any]]] = {}
        for row in line_rows:
            row_dict = dict(row)
            report_id = str(row_dict.pop("report_id"))
            row_dict.pop("line_order", None)
            lines_by_report.setdefault(report_id, []).append(row_dict)

        reports: list[dict[str, Any]] = []
        for row in report_rows:
            row_dict = dict(row)
            report_id = str(row_dict["id"])
            reports.append(
                {
                    "id": report_id,
                    "created_at": row_dict["created_at"],
                    "period": row_dict["period"],
                    "report_type": row_dict["report_type"],
                    "currency": row_dict["currency"],
                    "exposure_scope": row_dict["exposure_scope"],
                    "include_category_chart": bool(row_dict["include_category_chart"]),
                    "include_rating_chart": bool(row_dict["include_rating_chart"]),
                    "exports": {
                        "pdf": row_dict["export_pdf_path"],
                        "excel": row_dict["export_excel_path"],
                    },
                    "lines": lines_by_report.get(report_id, []),
                }
            )
        return reports

    def next_report_id(self) -> str:
        with database_manager.read_connection() as connection:
            row = connection.execute(
                "SELECT MAX(CAST(SUBSTR(id, 4) AS INTEGER)) AS max_index "
                "FROM rapports WHERE id GLOB 'RPT[0-9]*'"
            ).fetchone()
        max_index = int(row["max_index"]) if row and row["max_index"] is not None else 0
        return f"RPT{max_index + 1:03d}"

    def save_report(self, report: dict[str, Any], *, connection=None) -> dict[str, Any]:
        manager = nullcontext(connection) if connection is not None else database_manager.transaction()
        with manager as active_connection:
            active_connection.execute(
                """
                INSERT INTO rapports(
                    id,
                    cree_le,
                    periode,
                    type_rapport,
                    devise,
                    perimetre_exposition,
                    inclure_graphe_categorie,
                    inclure_graphe_notation,
                    chemin_export_pdf,
                    chemin_export_excel
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    cree_le = excluded.cree_le,
                    periode = excluded.periode,
                    type_rapport = excluded.type_rapport,
                    devise = excluded.devise,
                    perimetre_exposition = excluded.perimetre_exposition,
                    inclure_graphe_categorie = excluded.inclure_graphe_categorie,
                    inclure_graphe_notation = excluded.inclure_graphe_notation,
                    chemin_export_pdf = excluded.chemin_export_pdf,
                    chemin_export_excel = excluded.chemin_export_excel
                """,
                (
                    str(report["id"]),
                    report["created_at"].isoformat() if hasattr(report["created_at"], "isoformat") else str(report["created_at"]),
                    str(report["period"]),
                    str(report["report_type"]),
                    str(report["currency"]),
                    str(report["exposure_scope"]),
                    _bool_to_int(bool(report["include_category_chart"])),
                    _bool_to_int(bool(report["include_rating_chart"])),
                    str(report["exports"]["pdf"]),
                    str(report["exports"]["excel"]),
                ),
            )
            active_connection.execute(
                "DELETE FROM lignes_rapport WHERE rapport_id = ?",
                (str(report["id"]),),
            )
            active_connection.executemany(
                """
                INSERT INTO lignes_rapport(
                    rapport_id,
                    ordre_ligne,
                    source,
                    element_id,
                    contrepartie,
                    montant,
                    ead,
                    rwa,
                    capital
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    (
                        str(report["id"]),
                        index,
                        str(line["source"]),
                        str(line["item_id"]),
                        str(line["counterparty"]),
                        float(line["amount"]),
                        float(line["ead"]),
                        float(line["rwa"]),
                        float(line["capital"]),
                    )
                    for index, line in enumerate(report.get("lines", []), start=1)
                ],
            )
        return dict(report)


report_repository = ReportRepository()
