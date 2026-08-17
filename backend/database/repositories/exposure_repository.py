"""Accès SQLite au portefeuille d'expositions."""

from __future__ import annotations

from contextlib import nullcontext
import json
import re
from typing import Any

from database.connection import database_manager, utcnow_iso
from database.repositories.crm_repository import crm_repository

_SQLITE_CHUNK_SIZE = 400
_EXPOSURE_ID_PATTERN = re.compile(r"^CP(\d+)$")


def _bool_to_int(value: bool) -> int:
    return 1 if value else 0


def _nullable_bool_to_int(value: bool | None) -> int | None:
    if value is None:
        return None
    return 1 if value else 0


def _nullable_int_to_bool(value: Any) -> bool | None:
    if value is None:
        return None
    return bool(value)


def _normalize_key(value: str) -> str:
    return " ".join(value.lower().strip().split())


def _normalize_rating_label(value: Any, fallback: str = "Non noté") -> str:
    text = str(value or "").strip()
    normalized = _normalize_key(
        text.replace("é", "e").replace("è", "e").replace("ê", "e")
    )
    if not text:
        return fallback
    if normalized in {"non note", "non_note"}:
        return "Non noté"
    return text


def _chunked(values: list[str], size: int = _SQLITE_CHUNK_SIZE):
    for index in range(0, len(values), size):
        yield values[index : index + size]


def _parse_exposure_index(identifier: str) -> int | None:
    match = _EXPOSURE_ID_PATTERN.fullmatch(identifier.strip())
    if match is None:
        return None
    return int(match.group(1))


def _format_exposure_id(index: int) -> str:
    return f"CP{index:03d}"


# ── Requête SELECT principale avec tous les LEFT JOINs ───────────────────────

_SELECT_EXPOSURES = """
    SELECT
        e.id,
        e.date_analyse      AS analysis_date,
        e.date_octroi       AS grant_date,
        e.date_echeance     AS maturity_date,
        cp.nom              AS counterparty_name,
        cp.pays             AS country,
        cp.notation_pays    AS country_rating,
        cp.categorie_prudentielle AS category_raw,
        cp.categorie_standard     AS category_standard,
        e.type_prudentiel   AS prudential_type,
        e.crm_type,
        e.crm_mode,
        e.crm_libelle       AS crm_label,
        e.crm_existe        AS crm_exists,
        e.crm_couverture_pct AS crm_coverage_percent,
        cp.notation         AS rating,
        e.montant_brut      AS gross_amount,
        e.devise            AS currency,
        e.statut            AS status,
        e.jours_impayes     AS jours_impayes,
        e.statut_prudentiel AS statut_prudentiel,
        e.declassement_manuel AS declassement_manuel,
        e.declassement_motif  AS declassement_motif,
        e.declassement_le     AS declassement_le,
        -- Sous-entité souverain
        es.cas_particulier            AS sovereign_special_case,
        es.ponderation_zero_preferentiel AS sovereign_preferential_zero_weight,
        es.oce_etabli                 AS sovereign_oce_established,
        es.oce_note                   AS sovereign_oce_note,
        -- Sous-entité organisme public
        epb.cas_uemoa_fcfa            AS public_body_uemoa_fcfa_case,
        epb.activite_non_publique     AS public_body_non_public_activity,
        -- Sous-entité BMD
        eb.cas_haute_qualite              AS bmd_high_quality_case,
        eb.cas_uemoa_fcfa                 AS bmd_uemoa_fcfa_case,
        eb.criteres_uemoa_satisfaits      AS bmd_uemoa_criteria_satisfied,
        eb.cas_institution_listee_fcfa    AS bmd_listed_institution_fcfa_case,
        -- Sous-entité banque
        ebk.cas_institution               AS bank_institution_case,
        -- Sous-entité autre actif
        eoa.type_actif                    AS other_asset_type,
        -- Sous-entité hors bilan (détail risque)
        eob.niveau_risque                 AS off_balance_risk_level,
        -- Sous-entité clientèle de détail
        ert.criteres_eligibilite_satisfaits AS retail_eligibility_criteria_satisfied,
        -- Sous-entité immobilier résidentiel
        erm.eligible                      AS residential_mortgage_eligible,
        -- Sous-entité immobilier commercial
        ecr.eligible                      AS commercial_real_estate_eligible,
        -- Sous-entité exposition en défaut
        ed.ponderation_initiale               AS defaulted_exposure_initial_risk_weight,
        ed.immo_residentiel_en_defaut         AS defaulted_exposure_residential_mortgage_in_default,
        ed.provision_au_moins_vingt_pct       AS defaulted_exposure_provision_at_least_twenty_percent,
        -- Sous-entité entreprise
        ee.depasse_seuil_degradation_bceao    AS enterprise_exceeds_bceao_degradation_threshold,
        ee.procedure_prudentielle             AS enterprise_prudential_procedure,
        ee.sfi_hors_loi_bancaire              AS enterprise_investment_firm_without_banking_law,
        -- Résultats de calcul
        e.ponderation_initiale  AS original_rw,
        e.ponderation_finale    AS final_rw,
        e.ead,
        e.rwa,
        e.capital,
        e.commentaire           AS comment,
        e.champs_source_json    AS source_fields_json,
        -- CRM financée
        cf.valeur_collateral    AS collateral_value,
        cf.devise_collateral    AS collateral_currency,
        cf.type_collateral      AS collateral_type,
        cf.type_emetteur        AS issuer_type,
        cf.notation_emetteur    AS issuer_rating,
        cf.tranche_maturite     AS maturity_bucket,
        cf.convertible_indice_principal AS convertible_main_index,
        cf.opcvm_decote_max     AS opcvm_highest_haircut,
        cf.elements_panier_json AS basket_items_json,
        cf.decote_change        AS fx_haircut,
        cf.decote               AS haircut,
        cf.devise_exposition    AS exposure_currency,
        cf.ponderation          AS risk_weight,
        cf.collateral_eligible,
        cf.motif_ineligibilite  AS ineligibility_reason,
        cf.he,
        cf.hc,
        cf.hfx,
        cf.eva,
        cf.cva,
        cf.ead_apres_crm_financee AS ead_after_financed_crm,
        cf.rwa_final,
        cf.gain_crm             AS crm_gain,
        -- CRM non financée
        cn.nom_garant           AS guarantor_name,
        cn.categorie_garant     AS guarantor_category,
        cn.notation_garant      AS guarantor_rating,
        cn.pays_garant          AS guarantor_country,
        cn.notation_pays_garant AS guarantor_country_rating,
        cn.ponderation_pays_garant AS guarantor_country_rw,
        cn.ponderation_garant   AS guarantor_rw
    FROM expositions e
    INNER JOIN contreparties cp ON cp.id = e.contrepartie_id
    LEFT JOIN exposition_souveraine          es  ON es.exposition_id  = e.id
    LEFT JOIN exposition_organisme_public    epb ON epb.exposition_id = e.id
    LEFT JOIN exposition_bmd                 eb  ON eb.exposition_id  = e.id
    LEFT JOIN exposition_banque              ebk ON ebk.exposition_id = e.id
    LEFT JOIN exposition_autre_actif         eoa ON eoa.exposition_id = e.id
    LEFT JOIN exposition_hors_bilan_detail   eob ON eob.exposition_id = e.id
    LEFT JOIN exposition_clientele_detail    ert ON ert.exposition_id = e.id
    LEFT JOIN exposition_immo_residentiel    erm ON erm.exposition_id = e.id
    LEFT JOIN exposition_immo_commercial     ecr ON ecr.exposition_id = e.id
    LEFT JOIN exposition_souffrance          ed  ON ed.exposition_id  = e.id
    LEFT JOIN exposition_entreprise          ee  ON ee.exposition_id  = e.id
    LEFT JOIN exposition_risque_eleve        ehr ON ehr.exposition_id = e.id
    LEFT JOIN crm_financee cf ON cf.exposition_id = e.id
    LEFT JOIN crm_non_financee cn ON cn.exposition_id = e.id
"""


class ExposureRepository:
    """Persiste et lit les expositions depuis SQLite."""

    def list_exposures(self, search: str | None = None, category: str | None = None) -> list[dict[str, Any]]:
        query = _SELECT_EXPOSURES + " WHERE 1 = 1"
        params: list[Any] = []
        if search:
            like = f"%{search.lower()}%"
            query += " AND (LOWER(e.id) LIKE ? OR LOWER(cp.nom) LIKE ? OR LOWER(cp.pays) LIKE ?)"
            params.extend([like, like, like])
        if category:
            normalized_category = category.lower()
            query += """
                AND (
                    LOWER(cp.categorie_prudentielle) = ?
                    OR LOWER(cp.categorie_standard) = ?
                )
            """
            params.extend([normalized_category, normalized_category])
        query += " ORDER BY e.id"

        with database_manager.read_connection() as connection:
            rows = connection.execute(query, params).fetchall()
        return [self._row_to_record(dict(row)) for row in rows]

    def get_exposure(self, exposure_id: str) -> dict[str, Any] | None:
        query = _SELECT_EXPOSURES + " WHERE e.id = ?"
        with database_manager.read_connection() as connection:
            row = connection.execute(query, [exposure_id.strip()]).fetchone()
        if row is None:
            return None
        return self._row_to_record(dict(row))

    def get_existing_ids(self, exposure_ids: list[str], *, connection=None) -> set[str]:
        normalized_ids = sorted({str(item).strip() for item in exposure_ids if str(item).strip()})
        if not normalized_ids:
            return set()

        active_connection = connection or database_manager.connect()
        try:
            existing_ids: set[str] = set()
            for chunk in _chunked(normalized_ids):
                placeholders = ", ".join("?" for _ in chunk)
                rows = active_connection.execute(
                    f"SELECT id FROM expositions WHERE id IN ({placeholders})",
                    chunk,
                ).fetchall()
                existing_ids.update(str(row["id"]) for row in rows)
            return existing_ids
        finally:
            if connection is None:
                active_connection.close()

    def next_exposure_id(self) -> str:
        with database_manager.read_connection() as connection:
            row = connection.execute(
                "SELECT MAX(CAST(SUBSTR(id, 3) AS INTEGER)) AS max_index "
                "FROM expositions WHERE id GLOB 'CP[0-9]*'"
            ).fetchone()
        max_index = int(row["max_index"]) if row and row["max_index"] is not None else 0
        return _format_exposure_id(max_index + 1)

    def upsert_exposure(self, record: dict[str, Any], *, connection=None) -> dict[str, Any]:
        self.upsert_exposures([record], connection=connection)
        return record

    def upsert_exposures(self, records: list[dict[str, Any]], *, connection=None) -> list[dict[str, Any]]:
        if not records:
            return []
        manager = nullcontext(connection) if connection is not None else database_manager.transaction()
        with manager as active_connection:
            now = utcnow_iso()
            self._upsert_counterparties(active_connection, records, now=now)
            # Table principale exposures (colonnes de base uniquement)
            active_connection.executemany(
                """
                INSERT INTO expositions(
                    id,
                    contrepartie_id,
                    type_prudentiel,
                    date_analyse,
                    date_octroi,
                    date_echeance,
                    montant_brut,
                    devise,
                    statut,
                    crm_existe,
                    crm_type,
                    crm_mode,
                    crm_libelle,
                    crm_couverture_pct,
                    ponderation_initiale,
                    ponderation_finale,
                    ead,
                    rwa,
                    capital,
                    jours_impayes,
                    statut_prudentiel,
                    declassement_manuel,
                    declassement_motif,
                    declassement_le,
                    commentaire,
                    champs_source_json,
                    cree_le,
                    modifie_le
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
                )
                ON CONFLICT(id) DO UPDATE SET
                    contrepartie_id      = excluded.contrepartie_id,
                    type_prudentiel      = excluded.type_prudentiel,
                    date_analyse         = excluded.date_analyse,
                    date_octroi          = excluded.date_octroi,
                    date_echeance        = excluded.date_echeance,
                    montant_brut         = excluded.montant_brut,
                    devise               = excluded.devise,
                    statut               = excluded.statut,
                    crm_existe           = excluded.crm_existe,
                    crm_type             = excluded.crm_type,
                    crm_mode             = excluded.crm_mode,
                    crm_libelle          = excluded.crm_libelle,
                    crm_couverture_pct   = excluded.crm_couverture_pct,
                    ponderation_initiale = excluded.ponderation_initiale,
                    ponderation_finale   = excluded.ponderation_finale,
                    ead                  = excluded.ead,
                    rwa                  = excluded.rwa,
                    capital              = excluded.capital,
                    jours_impayes        = excluded.jours_impayes,
                    statut_prudentiel    = excluded.statut_prudentiel,
                    declassement_manuel  = excluded.declassement_manuel,
                    declassement_motif   = excluded.declassement_motif,
                    declassement_le      = excluded.declassement_le,
                    commentaire          = excluded.commentaire,
                    champs_source_json   = excluded.champs_source_json,
                    modifie_le           = excluded.modifie_le
                """,
                [
                    (
                        str(record["id"]),
                        str(record["id"]),
                        str(record.get("prudential_type") or record.get("category_raw") or "e"),
                        record["analysis_date"].isoformat()
                        if hasattr(record["analysis_date"], "isoformat")
                        else str(record["analysis_date"]),
                        record["grant_date"].isoformat()
                        if record.get("grant_date") is not None
                        and hasattr(record["grant_date"], "isoformat")
                        else (
                            str(record["grant_date"])
                            if record.get("grant_date") is not None
                            else None
                        ),
                        record["maturity_date"].isoformat()
                        if record.get("maturity_date") is not None
                        and hasattr(record["maturity_date"], "isoformat")
                        else (
                            str(record["maturity_date"])
                            if record.get("maturity_date") is not None
                            else None
                        ),
                        float(record["gross_amount"]),
                        str(record.get("currency", "XOF")),
                        str(record.get("status", "Active")),
                        _bool_to_int(bool(record.get("crm_exists"))),
                        str(record.get("crm_type", "Aucune")),
                        str(record.get("crm_mode") or record.get("crm_details", {}).get("mode") or "Aucune"),
                        str(record.get("crm_label") or record.get("crm_details", {}).get("label") or record.get("crm_type", "Aucune")),
                        float(record.get("crm_coverage_percent", 0.0) or 0.0),
                        float(record.get("original_rw", 0.0) or 0.0),
                        float(record.get("final_rw", 0.0) or 0.0),
                        float(record.get("ead", 0.0) or 0.0),
                        float(record.get("rwa", 0.0) or 0.0),
                        float(record.get("capital", 0.0) or 0.0),
                        int(record.get("jours_impayes", 0) or 0),
                        str(record.get("statut_prudentiel") or "saine"),
                        _bool_to_int(bool(record.get("declassement_manuel"))),
                        record.get("declassement_motif"),
                        record.get("declassement_le"),
                        record.get("comment"),
                        json.dumps(
                            record.get("source_fields") or {},
                            ensure_ascii=False,
                        ),
                        now,
                        now,
                    )
                    for record in records
                ],
            )
            # Sous-tables de type prudentiel
            self._upsert_type_subtables(active_connection, records)
            # CRM
            crm_repository.sync_exposures_crm(records, connection=active_connection)
            self._log_operation(
                active_connection,
                entity_type="exposure",
                entity_id=None,
                operation="bulk_upsert",
                payload={
                    "count": len(records),
                    "ids": [record["id"] for record in records],
                },
            )
        return [dict(record) for record in records]

    def _upsert_type_subtables(self, connection, records: list[dict[str, Any]]) -> None:
        """Synchronise les 12 sous-tables de type prudentiel via le discriminant prudential_type.

        Chaque exposition est routée vers exactement une sous-table selon prudential_type,
        ce qui garantit la contrainte MERISE de spécialisation exclusive (1 parmi 12).
        """
        sovereign_rows, public_body_rows, bmd_rows, bank_rows = [], [], [], []
        retail_rows, res_mortgage_rows, comm_re_rows = [], [], []
        defaulted_rows, enterprise_rows, other_asset_rows, off_balance_rows = [], [], [], []
        high_risk_rows = []

        for r in records:
            eid = str(r["id"])
            ptype = str(r.get("prudential_type") or r.get("category_raw") or "e")

            if ptype == "a":
                sovereign_rows.append((
                    eid,
                    str(r.get("sovereign_special_case") or ""),
                    _bool_to_int(bool(r.get("sovereign_preferential_zero_weight"))),
                    _bool_to_int(bool(r.get("sovereign_oce_established"))),
                    str(r.get("sovereign_oce_note") or ""),
                ))
            elif ptype == "b":
                public_body_rows.append((
                    eid,
                    _nullable_bool_to_int(r.get("public_body_uemoa_fcfa_case")),
                    _nullable_bool_to_int(r.get("public_body_non_public_activity")),
                ))
            elif ptype == "c":
                bmd_rows.append((
                    eid,
                    _nullable_bool_to_int(r.get("bmd_high_quality_case")),
                    _nullable_bool_to_int(r.get("bmd_uemoa_fcfa_case")),
                    _nullable_bool_to_int(r.get("bmd_uemoa_criteria_satisfied")),
                    _nullable_bool_to_int(r.get("bmd_listed_institution_fcfa_case")),
                ))
            elif ptype == "d":
                bank_rows.append((eid, str(r.get("bank_institution_case") or "") or None))
            elif ptype == "e":
                enterprise_rows.append((
                    eid,
                    _nullable_bool_to_int(r.get("enterprise_exceeds_bceao_degradation_threshold")),
                    _nullable_bool_to_int(r.get("enterprise_prudential_procedure")),
                    _nullable_bool_to_int(r.get("enterprise_investment_firm_without_banking_law")),
                ))
            elif ptype == "f":
                retail_rows.append((eid, _nullable_bool_to_int(r.get("retail_eligibility_criteria_satisfied"))))
            elif ptype == "g":
                res_mortgage_rows.append((eid, _nullable_bool_to_int(r.get("residential_mortgage_eligible"))))
            elif ptype == "h":
                comm_re_rows.append((eid, _nullable_bool_to_int(r.get("commercial_real_estate_eligible"))))
            elif ptype == "i":
                d_rw = (
                    float(r["defaulted_exposure_initial_risk_weight"])
                    if r.get("defaulted_exposure_initial_risk_weight") is not None
                    else None
                )
                defaulted_rows.append((
                    eid,
                    d_rw,
                    _nullable_bool_to_int(r.get("defaulted_exposure_residential_mortgage_in_default")),
                    _nullable_bool_to_int(r.get("defaulted_exposure_provision_at_least_twenty_percent")),
                ))
            elif ptype == "j":
                high_risk_rows.append((eid,))
            elif ptype == "k":
                other_asset_rows.append((eid, str(r.get("other_asset_type") or "") or None))

            # Le hors bilan n'est pas une catégorie prudentielle (a..k) mais
            # une composante que n'importe quelle exposition peut avoir en
            # plus de sa catégorie ; il est donc routé indépendamment du
            # switch ci-dessus plutôt que via un ptype "l" qui n'existe plus
            # dans CATEGORY_OPTIONS (et ne serait donc jamais atteint).
            off_balance_level = r.get("off_balance_risk_level")
            if off_balance_level:
                off_balance_rows.append((eid, str(off_balance_level)))

        if sovereign_rows:
            connection.executemany(
                """INSERT INTO exposition_souveraine(exposition_id, cas_particulier, ponderation_zero_preferentiel, oce_etabli, oce_note)
                   VALUES (?, ?, ?, ?, ?)
                   ON CONFLICT(exposition_id) DO UPDATE SET
                     cas_particulier = excluded.cas_particulier,
                     ponderation_zero_preferentiel = excluded.ponderation_zero_preferentiel,
                     oce_etabli = excluded.oce_etabli,
                     oce_note = excluded.oce_note""",
                sovereign_rows,
            )
        if public_body_rows:
            connection.executemany(
                """INSERT INTO exposition_organisme_public(exposition_id, cas_uemoa_fcfa, activite_non_publique)
                   VALUES (?, ?, ?)
                   ON CONFLICT(exposition_id) DO UPDATE SET
                     cas_uemoa_fcfa = excluded.cas_uemoa_fcfa,
                     activite_non_publique = excluded.activite_non_publique""",
                public_body_rows,
            )
        if bmd_rows:
            connection.executemany(
                """INSERT INTO exposition_bmd(exposition_id, cas_haute_qualite, cas_uemoa_fcfa, criteres_uemoa_satisfaits, cas_institution_listee_fcfa)
                   VALUES (?, ?, ?, ?, ?)
                   ON CONFLICT(exposition_id) DO UPDATE SET
                     cas_haute_qualite = excluded.cas_haute_qualite,
                     cas_uemoa_fcfa = excluded.cas_uemoa_fcfa,
                     criteres_uemoa_satisfaits = excluded.criteres_uemoa_satisfaits,
                     cas_institution_listee_fcfa = excluded.cas_institution_listee_fcfa""",
                bmd_rows,
            )
        if bank_rows:
            connection.executemany(
                """INSERT INTO exposition_banque(exposition_id, cas_institution)
                   VALUES (?, ?)
                   ON CONFLICT(exposition_id) DO UPDATE SET cas_institution = excluded.cas_institution""",
                bank_rows,
            )
        if retail_rows:
            connection.executemany(
                """INSERT INTO exposition_clientele_detail(exposition_id, criteres_eligibilite_satisfaits)
                   VALUES (?, ?)
                   ON CONFLICT(exposition_id) DO UPDATE SET criteres_eligibilite_satisfaits = excluded.criteres_eligibilite_satisfaits""",
                retail_rows,
            )
        if res_mortgage_rows:
            connection.executemany(
                """INSERT INTO exposition_immo_residentiel(exposition_id, eligible)
                   VALUES (?, ?)
                   ON CONFLICT(exposition_id) DO UPDATE SET eligible = excluded.eligible""",
                res_mortgage_rows,
            )
        if comm_re_rows:
            connection.executemany(
                """INSERT INTO exposition_immo_commercial(exposition_id, eligible)
                   VALUES (?, ?)
                   ON CONFLICT(exposition_id) DO UPDATE SET eligible = excluded.eligible""",
                comm_re_rows,
            )
        if defaulted_rows:
            connection.executemany(
                """INSERT INTO exposition_souffrance(exposition_id, ponderation_initiale, immo_residentiel_en_defaut, provision_au_moins_vingt_pct)
                   VALUES (?, ?, ?, ?)
                   ON CONFLICT(exposition_id) DO UPDATE SET
                     ponderation_initiale = excluded.ponderation_initiale,
                     immo_residentiel_en_defaut = excluded.immo_residentiel_en_defaut,
                     provision_au_moins_vingt_pct = excluded.provision_au_moins_vingt_pct""",
                defaulted_rows,
            )
        if enterprise_rows:
            connection.executemany(
                """INSERT INTO exposition_entreprise(exposition_id, depasse_seuil_degradation_bceao, procedure_prudentielle, sfi_hors_loi_bancaire)
                   VALUES (?, ?, ?, ?)
                   ON CONFLICT(exposition_id) DO UPDATE SET
                     depasse_seuil_degradation_bceao = excluded.depasse_seuil_degradation_bceao,
                     procedure_prudentielle = excluded.procedure_prudentielle,
                     sfi_hors_loi_bancaire = excluded.sfi_hors_loi_bancaire""",
                enterprise_rows,
            )
        if other_asset_rows:
            connection.executemany(
                """INSERT INTO exposition_autre_actif(exposition_id, type_actif)
                   VALUES (?, ?)
                   ON CONFLICT(exposition_id) DO UPDATE SET type_actif = excluded.type_actif""",
                other_asset_rows,
            )
        if off_balance_rows:
            connection.executemany(
                """INSERT INTO exposition_hors_bilan_detail(exposition_id, niveau_risque)
                   VALUES (?, ?)
                   ON CONFLICT(exposition_id) DO UPDATE SET niveau_risque = excluded.niveau_risque""",
                off_balance_rows,
            )
        if high_risk_rows:
            connection.executemany(
                """INSERT INTO exposition_risque_eleve(exposition_id)
                   VALUES (?)
                   ON CONFLICT(exposition_id) DO NOTHING""",
                high_risk_rows,
            )

    def clear_portfolio(self, *, connection=None) -> None:
        manager = nullcontext(connection) if connection is not None else database_manager.transaction()
        with manager as active_connection:
            active_connection.execute("DELETE FROM engagements_hors_bilan")
            active_connection.execute("DELETE FROM crm_financee")
            active_connection.execute("DELETE FROM crm_non_financee")
            # Les sous-tables de type sont supprimées en cascade via FK
            active_connection.execute("DELETE FROM expositions")
            active_connection.execute("DELETE FROM contreparties")

    def delete_exposures(
        self,
        exposure_ids: list[str],
        *,
        connection=None,
        reindex_ids: bool = False,
    ) -> dict[str, int | list[str] | bool | dict[str, str]]:
        normalized_ids = sorted({str(item).strip() for item in exposure_ids if str(item).strip()})
        if not normalized_ids:
            return {
                "requested_ids": [],
                "deleted_ids": [],
                "missing_ids": [],
                "deleted_count": 0,
                "missing_count": 0,
                "reindexed_ids": False,
                "renumbered_ids": {},
            }

        placeholders = ", ".join("?" for _ in normalized_ids)
        manager = nullcontext(connection) if connection is not None else database_manager.transaction()
        with manager as active_connection:
            rows = active_connection.execute(
                f"SELECT id FROM expositions WHERE id IN ({placeholders})",
                normalized_ids,
            ).fetchall()
            deleted_ids = sorted(str(row["id"]) for row in rows)
            missing_ids = [item for item in normalized_ids if item not in deleted_ids]
            if deleted_ids:
                delete_placeholders = ", ".join("?" for _ in deleted_ids)
                # Les sous-tables sont supprimées en CASCADE
                active_connection.execute(
                    f"DELETE FROM expositions WHERE id IN ({delete_placeholders})",
                    deleted_ids,
                )
                renumbered_ids = (
                    self._reindex_exposure_ids(active_connection)
                    if reindex_ids
                    else {}
                )
                self._cleanup_orphan_counterparties(active_connection)
                self._log_operation(
                    active_connection,
                    entity_type="exposure",
                    entity_id=None,
                    operation="bulk_delete",
                    payload={
                        "ids": deleted_ids,
                        "missing_ids": missing_ids,
                        "reindex_ids": reindex_ids,
                        "renumbered_ids": renumbered_ids,
                    },
                )
            else:
                renumbered_ids = {}

        return {
            "requested_ids": normalized_ids,
            "deleted_ids": deleted_ids,
            "missing_ids": missing_ids,
            "deleted_count": len(deleted_ids),
            "missing_count": len(missing_ids),
            "reindexed_ids": bool(reindex_ids and renumbered_ids),
            "renumbered_ids": renumbered_ids,
        }

    def _reindex_exposure_ids(self, connection) -> dict[str, str]:
        rows = connection.execute(
            """
            SELECT
                cp.id,
                CASE
                    WHEN EXISTS(
                        SELECT 1
                        FROM expositions e_exists
                        WHERE e_exists.contrepartie_id = cp.id
                    ) THEN 1
                    ELSE 0
                END AS has_exposure,
                MIN(
                    CASE
                        WHEN e.id LIKE 'CP%' THEN CAST(SUBSTR(e.id, 3) AS INTEGER)
                        ELSE NULL
                    END
                ) AS exposure_order
            FROM contreparties cp
            LEFT JOIN expositions e ON e.contrepartie_id = cp.id
            WHERE cp.id LIKE 'CP%'
            GROUP BY cp.id
            """
        ).fetchall()
        ordered_rows = sorted(
            rows,
            key=lambda row: (
                0 if int(row["has_exposure"]) else 1,
                row["exposure_order"] if row["exposure_order"] is not None else 10**9,
                _parse_exposure_index(str(row["id"])) or 10**9,
                str(row["id"]),
            ),
        )
        ordered_ids = [str(row["id"]) for row in ordered_rows]
        all_renumbered_ids = {
            current_id: _format_exposure_id(index)
            for index, current_id in enumerate(ordered_ids, start=1)
            if current_id != _format_exposure_id(index)
        }
        if not all_renumbered_ids:
            return {}

        connection.execute("PRAGMA defer_foreign_keys = ON")
        temporary_ids = {
            source_id: f"__TMP_CP_{position:06d}__"
            for position, source_id in enumerate(all_renumbered_ids.keys(), start=1)
        }

        for source_id, temporary_id in temporary_ids.items():
            self._remap_exposure_identifier(connection, source_id, temporary_id)
        for source_id, final_id in all_renumbered_ids.items():
            self._remap_exposure_identifier(
                connection,
                temporary_ids[source_id],
                final_id,
            )

        exposure_ids_after = {
            str(row["id"])
            for row in connection.execute(
                "SELECT id FROM expositions WHERE id LIKE 'CP%'"
            ).fetchall()
        }
        return {
            source_id: target_id
            for source_id, target_id in all_renumbered_ids.items()
            if target_id in exposure_ids_after
        }

    def _remap_exposure_identifier(
        self,
        connection,
        source_id: str,
        target_id: str,
    ) -> None:
        connection.execute(
            "UPDATE contreparties SET id = ? WHERE id = ?",
            (target_id, source_id),
        )
        connection.execute(
            "UPDATE expositions SET id = ? WHERE id = ?",
            (target_id, source_id),
        )
        connection.execute(
            "UPDATE expositions SET contrepartie_id = ? WHERE contrepartie_id = ?",
            (target_id, source_id),
        )
        # Sous-tables de type (PKs remappées — les FK suivent via CASCADE)
        for table in (
            "exposition_souveraine",
            "exposition_organisme_public",
            "exposition_bmd",
            "exposition_banque",
            "exposition_clientele_detail",
            "exposition_immo_residentiel",
            "exposition_immo_commercial",
            "exposition_souffrance",
            "exposition_entreprise",
            "exposition_risque_eleve",
            "exposition_autre_actif",
            "exposition_hors_bilan_detail",
        ):
            connection.execute(
                f"UPDATE {table} SET exposition_id = ? WHERE exposition_id = ?",
                (target_id, source_id),
            )
        connection.execute(
            "UPDATE suivi_versements SET exposition_id = ? WHERE exposition_id = ?",
            (target_id, source_id),
        )
        connection.execute(
            "UPDATE crm_financee SET exposition_id = ? WHERE exposition_id = ?",
            (target_id, source_id),
        )
        connection.execute(
            "UPDATE crm_non_financee SET exposition_id = ? WHERE exposition_id = ?",
            (target_id, source_id),
        )
        connection.execute(
            "UPDATE crm_garanties SET exposition_id = ? WHERE exposition_id = ?",
            (target_id, source_id),
        )
        connection.execute(
            "UPDATE engagements_hors_bilan SET contrepartie_id = ? WHERE contrepartie_id = ?",
            (target_id, source_id),
        )
        connection.execute(
            """
            UPDATE lignes_rapport
            SET element_id = ?
            WHERE source = 'Exposition' AND element_id = ?
            """,
            (target_id, source_id),
        )

    def _upsert_counterparties(self, connection, records: list[dict[str, Any]], *, now: str) -> None:
        connection.executemany(
            """
            INSERT INTO contreparties(
                id,
                nom,
                pays,
                notation_pays,
                categorie_standard,
                categorie_prudentielle,
                notation,
                cree_le,
                modifie_le
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                nom = excluded.nom,
                pays = excluded.pays,
                notation_pays = excluded.notation_pays,
                categorie_standard = excluded.categorie_standard,
                categorie_prudentielle = excluded.categorie_prudentielle,
                notation = excluded.notation,
                modifie_le = excluded.modifie_le
            """,
            [
                (
                    str(record["id"]),
                    str(record["counterparty_name"]),
                    str(record["country"]),
                    str(record.get("country_rating", "Non noté") or "Non noté"),
                    str(record.get("category_standard", "Entreprises")),
                    str(record.get("category_raw", record.get("category_standard", "Entreprises"))),
                    str(record["rating"]),
                    now,
                    now,
                )
                for record in records
            ],
        )

    def _cleanup_orphan_counterparties(self, connection) -> None:
        connection.execute(
            """
            DELETE FROM contreparties
            WHERE id NOT IN (SELECT contrepartie_id FROM expositions)
              AND id NOT IN (SELECT contrepartie_id FROM engagements_hors_bilan)
            """
        )

    def _log_operation(self, connection, *, entity_type: str, entity_id: str | None, operation: str, payload: dict[str, Any]) -> None:
        connection.execute(
            """
            INSERT INTO journal_operations(type_entite, entite_id, operation, payload_json, cree_le)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                entity_type,
                entity_id,
                operation,
                json.dumps(payload, ensure_ascii=False),
                utcnow_iso(),
            ),
        )

    def _row_to_record(self, row: dict[str, Any]) -> dict[str, Any]:
        try:
            source_fields = json.loads(str(row.get("source_fields_json") or "{}"))
            if not isinstance(source_fields, dict):
                source_fields = {}
        except json.JSONDecodeError:
            source_fields = {}
        crm_mode = str(row.get("crm_mode") or "Aucune")
        if crm_mode == "CRM financee":
            crm_details = {
                "mode": crm_mode,
                "label": row.get("crm_label") or row.get("crm_type") or "Aucune",
                "collateral_value": float(row.get("collateral_value", 0.0) or 0.0),
                "collateral_currency": str(row.get("collateral_currency") or "XOF"),
                "collateral_type": str(
                    row.get("collateral_type") or "Liquidités dans la même devise"
                ),
                "issuer_type": str(row.get("issuer_type") or ""),
                "issuer_rating": _normalize_rating_label(row.get("issuer_rating"), fallback=""),
                "maturity_bucket": str(row.get("maturity_bucket") or "<=1 an"),
                "convertible_main_index": bool(
                    row.get("convertible_main_index", 1)
                ),
                "opcvm_highest_haircut": float(
                    row.get("opcvm_highest_haircut", 0.30) or 0.30
                ),
                "basket_items": json.loads(
                    str(row.get("basket_items_json") or "[]")
                ),
                "fx_haircut": float(row.get("fx_haircut", 0.0) or 0.0),
                "exposure_currency": str(row.get("exposure_currency") or "XOF"),
                "risk_weight": float(row.get("risk_weight", 0.0) or 0.0),
                "eligible": bool(row.get("collateral_eligible", 1)),
                "eligibility_reason": str(row.get("ineligibility_reason") or ""),
                "he": float(row.get("he", 0.0) or 0.0),
                "hc": float(row.get("hc", 0.0) or 0.0),
                "hfx": float(row.get("hfx", 0.0) or 0.0),
                "eva": float(row.get("eva", 0.0) or 0.0),
                "cva": float(row.get("cva", 0.0) or 0.0),
                "ead_after_financed_crm": float(
                    row.get("ead_after_financed_crm", 0.0) or 0.0
                ),
                "rwa_final": float(row.get("rwa_final", 0.0) or 0.0),
                "crm_gain": float(row.get("crm_gain", 0.0) or 0.0),
                "guarantor_name": "",
                "guarantor_category": "",
                "guarantor_rating": "",
                "coverage_percent": float(row.get("crm_coverage_percent", 0.0) or 0.0),
                "haircut": float(row.get("haircut", 0.0) or 0.0),
            }
            guarantor_rw = 0.0
        elif crm_mode == "CRM non financee":
            crm_details = {
                "mode": crm_mode,
                "label": row.get("crm_label") or row.get("crm_type") or "Aucune",
                "collateral_value": 0.0,
                "issuer_type": "",
                "issuer_rating": "",
                "maturity_bucket": "<=1 an",
                "fx_haircut": 0.0,
                "guarantor_name": str(row.get("guarantor_name") or ""),
                "guarantor_category": str(row.get("guarantor_category") or ""),
                "guarantor_rating": _normalize_rating_label(
                    row.get("guarantor_rating"),
                    fallback="",
                ),
                "guarantor_country": str(row.get("guarantor_country") or ""),
                "guarantor_country_rating": _normalize_rating_label(
                    row.get("guarantor_country_rating"),
                    fallback="",
                ),
                "guarantor_country_rw": float(row.get("guarantor_country_rw", 0.0) or 0.0),
                "coverage_percent": float(row.get("crm_coverage_percent", 0.0) or 0.0),
            }
            guarantor_rw = float(row.get("guarantor_rw", 0.0) or 0.0)
            # Pondération substituée sur la part couverte : sans elle, un lecteur
            # ne peut pas savoir si la garantie allège réellement l'exigence.
            crm_details["guarantor_risk_weight"] = guarantor_rw
        else:
            crm_details = {
                "mode": "Aucune",
                "label": row.get("crm_type") or "Aucune",
                "coverage_percent": 0.0,
            }
            guarantor_rw = 0.0
        return {
            "id": str(row["id"]),
            "analysis_date": row["analysis_date"],
            "grant_date": row.get("grant_date"),
            "maturity_date": row.get("maturity_date"),
            "counterparty_name": str(row["counterparty_name"]),
            "country": str(row["country"]),
            "country_rating": _normalize_rating_label(row.get("country_rating")),
            "prudential_type": str(row.get("prudential_type") or row.get("category_raw") or "e"),
            "category_raw": str(row.get("category_raw") or row.get("category_standard") or "Entreprises"),
            "category_dashboard": str(row.get("category_standard") or "Entreprises"),
            "category_standard": str(row.get("category_standard") or "Entreprises"),
            "rating": _normalize_rating_label(row.get("rating")),
            "gross_amount": float(row.get("gross_amount", 0.0) or 0.0),
            **source_fields,
            "source_fields": source_fields,
            "currency": str(row.get("currency") or "XOF"),
            "status": str(row.get("status") or "Active"),
            "jours_impayes": int(row.get("jours_impayes") or 0),
            "statut_prudentiel": str(row.get("statut_prudentiel") or "saine"),
            "declassement_manuel": bool(row.get("declassement_manuel")),
            "declassement_motif": row.get("declassement_motif"),
            "declassement_le": row.get("declassement_le"),
            "sovereign_special_case": str(row.get("sovereign_special_case") or ""),
            "sovereign_preferential_zero_weight": bool(
                row.get("sovereign_preferential_zero_weight")
            ),
            "sovereign_oce_established": bool(row.get("sovereign_oce_established")),
            "sovereign_oce_note": str(row.get("sovereign_oce_note") or ""),
            "public_body_uemoa_fcfa_case": _nullable_int_to_bool(
                row.get("public_body_uemoa_fcfa_case")
            ),
            "public_body_non_public_activity": _nullable_int_to_bool(
                row.get("public_body_non_public_activity")
            ),
            "bmd_high_quality_case": _nullable_int_to_bool(
                row.get("bmd_high_quality_case")
            ),
            "bmd_uemoa_fcfa_case": _nullable_int_to_bool(
                row.get("bmd_uemoa_fcfa_case")
            ),
            "bmd_uemoa_criteria_satisfied": _nullable_int_to_bool(
                row.get("bmd_uemoa_criteria_satisfied")
            ),
            "bmd_listed_institution_fcfa_case": _nullable_int_to_bool(
                row.get("bmd_listed_institution_fcfa_case")
            ),
            "bank_institution_case": str(row.get("bank_institution_case") or "")
            or None,
            "other_asset_type": str(row.get("other_asset_type") or "") or None,
            "off_balance_risk_level":
                str(row.get("off_balance_risk_level") or "") or None,
            "retail_eligibility_criteria_satisfied": _nullable_int_to_bool(
                row.get("retail_eligibility_criteria_satisfied")
            ),
            "residential_mortgage_eligible": _nullable_int_to_bool(
                row.get("residential_mortgage_eligible")
            ),
            "commercial_real_estate_eligible": _nullable_int_to_bool(
                row.get("commercial_real_estate_eligible")
            ),
            "defaulted_exposure_initial_risk_weight": (
                float(row.get("defaulted_exposure_initial_risk_weight"))
                if row.get("defaulted_exposure_initial_risk_weight") is not None
                else None
            ),
            "defaulted_exposure_residential_mortgage_in_default": _nullable_int_to_bool(
                row.get("defaulted_exposure_residential_mortgage_in_default")
            ),
            "defaulted_exposure_provision_at_least_twenty_percent": _nullable_int_to_bool(
                row.get("defaulted_exposure_provision_at_least_twenty_percent")
            ),
            "enterprise_exceeds_bceao_degradation_threshold": _nullable_int_to_bool(
                row.get("enterprise_exceeds_bceao_degradation_threshold")
            ),
            "enterprise_prudential_procedure": _nullable_int_to_bool(
                row.get("enterprise_prudential_procedure")
            ),
            "enterprise_investment_firm_without_banking_law": _nullable_int_to_bool(
                row.get("enterprise_investment_firm_without_banking_law")
            ),
            "crm_exists": bool(row.get("crm_exists")),
            "crm_type": str(row.get("crm_type") or "Aucune"),
            "crm_mode": crm_mode,
            "crm_label": str(row.get("crm_label") or row.get("crm_type") or "Aucune"),
            "crm_coverage_percent": float(row.get("crm_coverage_percent", 0.0) or 0.0),
            "crm_details": crm_details,
            "guarantor_rw": guarantor_rw,
            "original_rw": float(row.get("original_rw", 0.0) or 0.0),
            "final_rw": float(row.get("final_rw", 0.0) or 0.0),
            "ead": float(row.get("ead", 0.0) or 0.0),
            "rwa": float(row.get("rwa", 0.0) or 0.0),
            "capital": float(row.get("capital", 0.0) or 0.0),
            "comment": row.get("comment"),
        }


exposure_repository = ExposureRepository()
