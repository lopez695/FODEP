"""Accès SQLite aux données CRM."""

from __future__ import annotations

from contextlib import nullcontext
import json
from typing import Any

from app.core.calculations import calculate_capital
from database.connection import database_manager

_SQLITE_CHUNK_SIZE = 400


def _bool_to_int(value: bool) -> int:
    return 1 if value else 0


def _normalize_key(value: str) -> str:
    return " ".join(value.lower().strip().split())


def _chunked(values: list[str], size: int = _SQLITE_CHUNK_SIZE):
    for index in range(0, len(values), size):
        yield values[index : index + size]


class CrmRepository:
    """Fournit les synchronisations et vues CRM depuis SQLite."""

    def sync_exposures_crm(
        self,
        exposure_records: list[dict[str, Any]],
        *,
        connection=None,
    ) -> None:
        if not exposure_records:
            return

        manager = nullcontext(connection) if connection is not None else database_manager.transaction()
        with manager as active_connection:
            exposure_ids = [str(record["id"]) for record in exposure_records]
            for chunk in _chunked(exposure_ids):
                placeholders = ", ".join("?" for _ in chunk)
                active_connection.execute(
                    f"DELETE FROM crm_financee WHERE exposition_id IN ({placeholders})",
                    chunk,
                )
                active_connection.execute(
                    f"DELETE FROM crm_non_financee WHERE exposition_id IN ({placeholders})",
                    chunk,
                )

            financed_rows: list[tuple[Any, ...]] = []
            non_financed_rows: list[tuple[Any, ...]] = []
            for exposure_record in exposure_records:
                exposure_id = str(exposure_record["id"])
                crm_details = dict(exposure_record.get("crm_details", {}))
                crm_mode = str(
                    exposure_record.get("crm_mode")
                    or crm_details.get("mode")
                    or "Aucune"
                )

                if crm_mode == "CRM financee":
                    financed_rows.append(
                        (
                            exposure_id,
                            float(crm_details.get("collateral_value", 0.0) or 0.0),
                            str(crm_details.get("collateral_currency", "XOF") or "XOF"),
                            str(
                                crm_details.get("collateral_type")
                                or "Liquidités dans la même devise"
                            ),
                            str(crm_details.get("issuer_type", "") or ""),
                            str(crm_details.get("issuer_rating", "") or ""),
                            str(crm_details.get("maturity_bucket", "<=1 an") or "<=1 an"),
                            _bool_to_int(bool(crm_details.get("convertible_main_index", True))),
                            float(crm_details.get("opcvm_highest_haircut", 0.30) or 0.30),
                            json.dumps(crm_details.get("basket_items", []), ensure_ascii=False),
                            float(crm_details.get("fx_haircut", 0.0) or 0.0),
                            float(crm_details.get("haircut", 0.0) or 0.0),
                            str(crm_details.get("exposure_currency", "XOF") or "XOF"),
                            float(crm_details.get("risk_weight", 0.0) or 0.0),
                            _bool_to_int(bool(crm_details.get("eligible", True))),
                            str(crm_details.get("eligibility_reason", "") or ""),
                            float(crm_details.get("he", 0.0) or 0.0),
                            float(crm_details.get("hc", 0.0) or 0.0),
                            float(crm_details.get("hfx", 0.0) or 0.0),
                            float(crm_details.get("eva", 0.0) or 0.0),
                            float(crm_details.get("cva", 0.0) or 0.0),
                            float(crm_details.get("ead_after_financed_crm", 0.0) or 0.0),
                            float(crm_details.get("rwa_final", 0.0) or 0.0),
                            float(crm_details.get("crm_gain", 0.0) or 0.0),
                        )
                    )
                elif crm_mode == "CRM non financee":
                    non_financed_rows.append(
                        (
                            exposure_id,
                            str(crm_details.get("guarantor_name", "") or ""),
                            str(crm_details.get("guarantor_category", "") or ""),
                            str(crm_details.get("guarantor_rating", "") or ""),
                            str(crm_details.get("guarantor_country", "") or ""),
                            str(crm_details.get("guarantor_country_rating", "") or ""),
                            float(crm_details.get("guarantor_country_rw", 0.0) or 0.0),
                            float(exposure_record.get("guarantor_rw", 0.0) or 0.0),
                            float(
                                crm_details.get(
                                    "coverage_percent",
                                    exposure_record.get("crm_coverage_percent", 0.0),
                                )
                                or 0.0
                            ),
                        )
                    )

            if financed_rows:
                active_connection.executemany(
                    """
                    INSERT INTO crm_financee(
                        exposition_id,
                        valeur_collateral,
                        devise_collateral,
                        type_collateral,
                        type_emetteur,
                        notation_emetteur,
                        tranche_maturite,
                        convertible_indice_principal,
                        opcvm_decote_max,
                        elements_panier_json,
                        decote_change,
                        decote,
                        devise_exposition,
                        ponderation,
                        collateral_eligible,
                        motif_ineligibilite,
                        he,
                        hc,
                        hfx,
                        eva,
                        cva,
                        ead_apres_crm_financee,
                        rwa_final,
                        gain_crm
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(exposition_id) DO UPDATE SET
                        valeur_collateral = excluded.valeur_collateral,
                        devise_collateral = excluded.devise_collateral,
                        type_collateral = excluded.type_collateral,
                        type_emetteur = excluded.type_emetteur,
                        notation_emetteur = excluded.notation_emetteur,
                        tranche_maturite = excluded.tranche_maturite,
                        convertible_indice_principal = excluded.convertible_indice_principal,
                        opcvm_decote_max = excluded.opcvm_decote_max,
                        elements_panier_json = excluded.elements_panier_json,
                        decote_change = excluded.decote_change,
                        decote = excluded.decote,
                        devise_exposition = excluded.devise_exposition,
                        ponderation = excluded.ponderation,
                        collateral_eligible = excluded.collateral_eligible,
                        motif_ineligibilite = excluded.motif_ineligibilite,
                        he = excluded.he,
                        hc = excluded.hc,
                        hfx = excluded.hfx,
                        eva = excluded.eva,
                        cva = excluded.cva,
                        ead_apres_crm_financee = excluded.ead_apres_crm_financee,
                        rwa_final = excluded.rwa_final,
                        gain_crm = excluded.gain_crm
                    """,
                    financed_rows,
                )

            if non_financed_rows:
                active_connection.executemany(
                    """
                    INSERT INTO crm_non_financee(
                        exposition_id,
                        nom_garant,
                        categorie_garant,
                        notation_garant,
                        pays_garant,
                        notation_pays_garant,
                        ponderation_pays_garant,
                        ponderation_garant,
                        taux_couverture
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(exposition_id) DO UPDATE SET
                        nom_garant = excluded.nom_garant,
                        categorie_garant = excluded.categorie_garant,
                        notation_garant = excluded.notation_garant,
                        pays_garant = excluded.pays_garant,
                        notation_pays_garant = excluded.notation_pays_garant,
                        ponderation_pays_garant = excluded.ponderation_pays_garant,
                        ponderation_garant = excluded.ponderation_garant,
                        taux_couverture = excluded.taux_couverture
                    """,
                    non_financed_rows,
                )

    def list_guarantees(self, search: str | None = None, guarantee_type: str | None = None) -> list[dict[str, Any]]:
        query = """
            SELECT
                e.id AS exposure_id,
                cp.nom AS borrower_name,
                cp.categorie_standard AS borrower_category,
                cp.notation AS borrower_rating,
                e.montant_brut AS gross_amount,
                e.crm_type AS guarantee_type,
                e.crm_mode,
                e.crm_libelle AS crm_label,
                e.crm_couverture_pct AS crm_coverage_percent,
                e.ponderation_initiale AS borrower_rw,
                e.ponderation_finale AS final_rw,
                e.ead,
                e.rwa,
                e.capital,
                cf.valeur_collateral AS collateral_value,
                cf.type_emetteur AS issuer_type,
                cf.notation_emetteur AS issuer_rating,
                cf.tranche_maturite AS maturity_bucket,
                cf.decote_change AS fx_haircut,
                cf.decote AS haircut,
                cn.nom_garant AS guarantor_name,
                cn.categorie_garant AS guarantor_category,
                cn.notation_garant AS guarantor_rating,
                cn.ponderation_garant AS guarantor_rw
            FROM expositions e
            INNER JOIN contreparties cp ON cp.id = e.contrepartie_id
            LEFT JOIN crm_financee cf ON cf.exposition_id = e.id
            LEFT JOIN crm_non_financee cn ON cn.exposition_id = e.id
            WHERE e.crm_mode <> 'Aucune'
        """
        params: list[Any] = []
        if search:
            like = f"%{search.lower()}%"
            query += " AND (LOWER(cp.nom) LIKE ? OR LOWER(COALESCE(cn.nom_garant, cf.type_emetteur, '')) LIKE ?)"
            params.extend([like, like])
        if guarantee_type:
            query += " AND LOWER(e.crm_type) = ?"
            params.append(guarantee_type.lower())
        query += " ORDER BY e.id"

        with database_manager.read_connection() as connection:
            rows = connection.execute(query, params).fetchall()

        items: list[dict[str, Any]] = []
        for row in rows:
            coverage_ratio = float(row["crm_coverage_percent"] or 0.0)
            gross_amount = float(row["gross_amount"] or 0.0)
            coverage_amount = 0.0
            guarantor_name = "Sans garant"
            guarantor_category = row["borrower_category"]
            guarantor_rating = row["borrower_rating"]
            guarantor_rw = float(row["borrower_rw"] or 0.0)

            if row["crm_mode"] == "CRM financee":
                coverage_amount = float(row["collateral_value"] or 0.0)
                guarantor_name = str(row["issuer_type"] or "Garant non renseigne")
                guarantor_category = "Souverains" if _normalize_key(guarantor_name) == "souverain" else "Entreprises"
                guarantor_rating = str(row["issuer_rating"] or row["borrower_rating"] or "Non noté")
            else:
                coverage_amount = round(gross_amount * coverage_ratio, 2)
                guarantor_name = str(row["guarantor_name"] or "Garant non renseigne")
                guarantor_category = str(row["guarantor_category"] or row["borrower_category"])
                guarantor_rating = str(row["guarantor_rating"] or row["borrower_rating"])
                guarantor_rw = float(row["guarantor_rw"] or 0.0)

            rwa_before = round(float(row["ead"] or 0.0) * float(row["borrower_rw"] or 0.0), 2)
            capital_before = calculate_capital(rwa_before)
            rwa_after = round(float(row["rwa"] or 0.0), 2)
            # Recalculé au taux courant plutôt que lu en base : les montants
            # persistés peuvent dater d'un ancien paramétrage du ratio.
            capital_after = calculate_capital(rwa_after)

            items.append(
                {
                    "id": f"CRM_{row['exposure_id']}",
                    "exposure_id": row["exposure_id"],
                    "borrower_name": row["borrower_name"],
                    "borrower_category": row["borrower_category"],
                    "borrower_rating": row["borrower_rating"],
                    "gross_amount": gross_amount,
                    "guarantor_name": guarantor_name,
                    "guarantor_category": guarantor_category,
                    "guarantor_rating": guarantor_rating,
                    "guarantee_type": row["guarantee_type"],
                    "coverage_amount": coverage_amount,
                    "coverage_ratio": coverage_ratio,
                    "borrower_rw": float(row["borrower_rw"] or 0.0),
                    "guarantor_rw": guarantor_rw,
                    "final_rw": float(row["final_rw"] or 0.0),
                    "ead": float(row["ead"] or 0.0),
                    "rwa_before": rwa_before,
                    "rwa_after": rwa_after,
                    "capital_before": capital_before,
                    "capital_after": capital_after,
                    "rwa_reduction": round(rwa_before - rwa_after, 2),
                    "capital_saving": round(capital_before - capital_after, 2),
                }
            )
        return items


crm_repository = CrmRepository()
