"""Services métier du module expositions."""

from __future__ import annotations

import csv
import json
import logging
from datetime import date, datetime
from io import BytesIO, StringIO
from typing import Any

from app.core.calculations import aggregate_portfolio, calculate_capital, convert_currency_amount
from app.expositions.models import ExposureCreate, ExposureCrmDetails, ExposureSummary, ExposureView
from app.referentiels import services as referentiels_service
from database.connection import database_manager
from database.repositories.exposure_repository import exposure_repository
from database.repositories.off_balance_repository import off_balance_repository
from database.services.excel_import_service import excel_import_service
from database.services.exposure_sync_service import exposure_sync_service
from database.services.export_service import export_service
from database.services.rwa_calculation_service import (
    build_exposure_record,
    crm_mode_from_type,
    exposure_record_to_view,
)

logger = logging.getLogger(__name__)


def _next_counterparty_id() -> str:
    return exposure_repository.next_exposure_id()


def get_next_exposition_id() -> str:
    """Retourne le prochain identifiant CP disponible."""

    return _next_counterparty_id()


def list_expositions(search: str | None = None, category: str | None = None) -> list[ExposureView]:
    """Liste les expositions avec filtres simples."""

    try:
        exposure_sync_service.schedule_reference_fields_backfill()
    except Exception:
        logger.exception(
            "La planification du backfill des maturites Expositions a echoue.",
        )

    exposures = exposure_repository.list_exposures(search=search, category=category)
    from database.repositories.suivi_versements_repository import suivi_versements_repository
    reimbursements = suivi_versements_repository.list_all_reimbursements()
    
    views = []
    for item in exposures:
        view = exposure_record_to_view(item)
        if view.id in reimbursements:
            view.actual_reimbursements = reimbursements[view.id]
        views.append(view)
    return views


def create_exposition(payload: ExposureCreate) -> ExposureView:
    """Crée une nouvelle exposition et la persiste dans SQLite."""

    exposure_id = _next_counterparty_id()
    record = build_exposure_record(payload, exposure_id)
    exposure_repository.upsert_exposure(record)
    return exposure_record_to_view(record)


def preview_exposition(payload: ExposureCreate) -> ExposureView:
    """Calcule une exposition sans la persister."""

    preview_id = payload.id or "PREVIEW"
    record = build_exposure_record(payload, preview_id)
    return exposure_record_to_view(record)


def update_exposition(exposure_id: str, payload: ExposureCreate) -> ExposureView:
    """Met à jour une exposition existante et la persiste dans SQLite."""

    from app.expositions.suivi_service import apply_server_side_suivi

    # Le statut prudentiel et les jours d'impayés dérivés appartiennent au
    # serveur : une édition de formulaire ne peut pas les écraser.
    payload = apply_server_side_suivi(payload, exposure_id)
    record = build_exposure_record(payload, payload.id or exposure_id)
    record["id"] = exposure_id
    exposure_repository.upsert_exposure(record)
    return exposure_record_to_view(record)


def delete_exposition(exposure_id: str) -> bool:
    """Supprime une exposition existante de SQLite."""

    result = exposure_repository.delete_exposures([exposure_id])
    return int(result["deleted_count"]) > 0


def delete_expositions(
    exposure_ids: list[str],
    *,
    reindex_ids: bool = False,
) -> dict[str, int | list[str] | bool | dict[str, str]]:
    """Supprime plusieurs expositions via leurs IDs."""

    return exposure_repository.delete_exposures(
        exposure_ids,
        reindex_ids=reindex_ids,
    )


def get_exposition_summary() -> ExposureSummary:
    """Agrège les totaux du portefeuille d'expositions."""

    rows = list_expositions()
    totals = aggregate_portfolio(
        {
            "gross_amount": convert_currency_amount(
                row.loan_total_amount if row.loan_total_amount is not None else row.gross_amount,
                from_currency=row.currency,
                to_currency="XOF",
            ),
            "ead": convert_currency_amount(row.ead, from_currency=row.currency, to_currency="XOF"),
            "rwa": convert_currency_amount(row.rwa, from_currency=row.currency, to_currency="XOF"),
            "capital": convert_currency_amount(row.capital, from_currency=row.currency, to_currency="XOF"),
        }
        for row in rows
    )
    return ExposureSummary(
        total_expositions=totals["gross_amount"],
        total_ead=totals["ead"],
        total_rwa=totals["rwa"],
        total_capital=totals["capital"],
    )


def get_excel_import_spec() -> dict[str, Any]:
    """Retourne la description du format d'import Excel attendu."""

    return excel_import_service.get_import_spec()


def build_excel_import_template() -> bytes:
    """Construit un modèle Excel d'import prêt à être téléchargé."""

    return excel_import_service.build_template_workbook()


def inspect_uploaded_workbook(
    workbook_bytes: bytes,
    filename: str | None = None,
) -> dict[str, Any]:
    """Inspecte un classeur uploadé sans écrire en base."""

    return excel_import_service.inspect_uploaded_workbook(workbook_bytes, filename)


def import_uploaded_workbook(
    workbook_bytes: bytes,
    filename: str | None = None,
    *,
    mode: str = "merge",
) -> dict[str, Any]:
    """Importe un classeur d'expositions dans SQLite."""

    return excel_import_service.import_uploaded_workbook(
        workbook_bytes,
        filename,
        mode=mode,
    )


def export_expositions_to_csv() -> BytesIO:
    """Exporte les expositions en fichier CSV."""

    rows = list_expositions()
    output = StringIO()
    writer = csv.writer(output, delimiter=";")
    writer.writerow(
        [
            "ID",
            "Date Analyse",
            "Contrepartie",
            "Pays",
            "Categorie",
            "Notation",
            "Montant Brut",
            "Devise",
            "Statut",
            "Type CRM",
            "Taux Couverture CRM (%)",
            "Mode CRM",
            "Libelle CRM",
            "Valeur Collateral",
            "Ponderation Initiale",
            "Ponderation Finale",
            "EAD",
            "RWA",
            "Capital Requis",
            "Commentaire",
        ]
    )
    for row in rows:
        writer.writerow(
            [
                row.id,
                row.analysis_date.isoformat(),
                row.counterparty.name,
                row.counterparty.country,
                row.counterparty.category,
                row.counterparty.rating,
                round(row.gross_amount, 2),
                row.currency,
                row.status,
                row.crm_type,
                round(row.crm_coverage_percent * 100, 2),
                row.crm_details.mode,
                row.crm_details.label,
                round(row.crm_details.collateral_value, 2),
                round(row.original_rw, 4),
                round(row.final_rw, 4),
                round(row.ead, 2),
                round(row.rwa, 2),
                round(row.capital, 2),
                row.comment or "",
            ]
        )
    bytes_output = BytesIO()
    bytes_output.write(output.getvalue().encode("utf-8-sig"))
    bytes_output.seek(0)
    return bytes_output


def export_expositions_to_json() -> dict[str, Any]:
    """Exporte les expositions en format JSON."""

    rows = list_expositions()
    return {
        "export_date": datetime.now().isoformat(),
        "total_count": len(rows),
        "expositions": [
            {
                "id": row.id,
                "analysis_date": row.analysis_date.isoformat(),
                "counterparty": {
                    "name": row.counterparty.name,
                    "country": row.counterparty.country,
                    "category": row.counterparty.category,
                    "rating": row.counterparty.rating,
                },
                "gross_amount": round(row.gross_amount, 2),
                "currency": row.currency,
                "status": row.status,
                "crm": {
                    "type": row.crm_type,
                    "coverage_percent": round(row.crm_coverage_percent * 100, 2),
                    "mode": row.crm_details.mode,
                    "label": row.crm_details.label,
                    "collateral_value": round(row.crm_details.collateral_value, 2),
                },
                "calculations": {
                    "original_rw": round(row.original_rw, 4),
                    "final_rw": round(row.final_rw, 4),
                    "ead": round(row.ead, 2),
                    "rwa": round(row.rwa, 2),
                    "capital": round(row.capital, 2),
                },
                "comment": row.comment,
            }
            for row in rows
        ],
    }


def build_expositions_excel_export() -> bytes:
    """Construit l'export Excel complet base sur le modele RWA."""

    return export_service.export_excel_workbook_bytes()


def export_to_excel() -> dict[str, str | int]:
    """Exporte les expositions dans un classeur Excel dédié."""

    export_path = export_service.export_excel_workbook()
    rows = list_expositions()
    return {
        "status": "success",
        "exported_count": len(rows),
        "file": str(export_path),
        "timestamp": datetime.now().isoformat(),
    }


def _normalize_import_header(header: str) -> str:
    normalized = (
        header.strip()
        .lower()
        .replace("'", " ")
        .replace("’", " ")
        .replace("é", "e")
        .replace("è", "e")
        .replace("ê", "e")
        .replace("à", "a")
        .replace("ô", "o")
        .replace("-", "_")
        .replace(" ", "_")
    )
    normalized = "_".join(part for part in normalized.split("_") if part)
    aliases = {
        "nom_contrepartie": "contrepartie",
        "client": "contrepartie",
        "country": "pays",
        "date_d_octroi": "grant_date",
        "date_octroi": "grant_date",
        "date_d_echeance": "maturity_date",
        "date_echeance": "maturity_date",
        "categorie_prudentielle": "categorie",
        "category": "categorie",
        "note": "notation",
        "rating": "notation",
        "montant_brut": "montant",
        "montant_nominal": "montant",
        "exposition": "montant",
        "devise_source": "devise",
        "couverture_crm": "couverture",
        "taux_couverture": "couverture",
        "valeur_garantie": "collateral",
        "valeur_collateral": "collateral",
        "garantie": "collateral",
        "type_emetteur_collateral": "type_emetteur",
        "notation_emetteur": "notation_collateral",
        "notation_emetteur_collateral": "notation_collateral",
        "tranche_maturite": "maturite",
        "decote_change": "hfx",
        "taux_decote_change": "hfx",
        "nom_garant": "garant",
        "type_garant": "categorie_garant",
        "notation_du_garant": "notation_garant",
        "position": "placement",
        "perimetre": "placement",
        "type_risque": "engagement_type",
        "engagement": "engagement_type",
        "type_engagement": "engagement_type",
    }
    return aliases.get(normalized, normalized)


def _is_off_balance_placement(value: str) -> bool:
    normalized = value.strip().lower().replace("_", " ")
    return normalized in {"non", "false", "0", "hors bilan", "hb", "off balance", "off balance sheet"}


def _is_truthy_import_flag(value: str) -> bool:
    normalized = value.strip().lower()
    return normalized in {"oui", "yes", "true", "1", "x"}


def _parse_percent(value: str) -> float:
    raw = value.replace("%", "").replace(",", ".").strip()
    if not raw:
        return 0.0
    parsed = float(raw)
    return parsed / 100.0 if parsed > 1 else parsed


def _parse_amount(value: str) -> float:
    raw = value.replace(" ", "").replace(",", ".").strip()
    return float(raw) if raw else 0.0


def _parse_import_date(value: str) -> date:
    if not value:
        return datetime.now().date()
    for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y"):
        try:
            return datetime.strptime(value.strip(), fmt).date()
        except ValueError:
            continue
    return date.fromisoformat(value.strip())


def _parse_optional_import_date(value: str) -> date | None:
    if not value or not value.strip():
        return None
    return _parse_import_date(value)


def import_csv_data(content: str) -> dict[str, int | str | list[str]]:
    """Importe des données CSV/TSV dans SQLite."""

    if not content or not content.strip():
        return {"status": "error", "message": "Donnees vides"}

    lines = [line.strip() for line in content.strip().splitlines() if line.strip()]
    if len(lines) < 2:
        return {"status": "error", "message": "Au moins un en-tete et une ligne de donnees requis"}

    delimiter = "\t" if "\t" in lines[0] else (";" if ";" in lines[0] else ",")
    rows = list(csv.reader(lines, delimiter=delimiter))
    headers = [_normalize_import_header(header) for header in rows[0]]
    required_headers = {"contrepartie", "pays", "categorie", "notation", "montant"}
    if not required_headers.issubset(set(headers)):
        missing = ", ".join(sorted(required_headers - set(headers)))
        return {"status": "error", "message": f"En-tetes requis manquants: {missing}"}

    imported_balance = 0
    imported_off_balance = 0
    errors: list[str] = []
    exposure_records: list[dict[str, Any]] = []
    off_balance_records: list[dict[str, Any]] = []
    reserved_ids = {item.id for item in list_expositions()}
    next_counterparty_index = 0
    for existing_id in reserved_ids:
        if existing_id.startswith("CP"):
            try:
                next_counterparty_index = max(next_counterparty_index, int(existing_id[2:]))
            except ValueError:
                continue

    def next_exposure_id() -> str:
        nonlocal next_counterparty_index
        while True:
            next_counterparty_index += 1
            candidate = f"CP{next_counterparty_index:03d}"
            if candidate not in reserved_ids:
                reserved_ids.add(candidate)
                return candidate

    for row_index, values in enumerate(rows[1:], start=2):
        if not values:
            continue

        def get_value(header: str, default: str = "") -> str:
            try:
                header_index = headers.index(header)
            except ValueError:
                return default
            return values[header_index].strip() if header_index < len(values) else default

        try:
            exposure_id = get_value("id") or None
            analysis_date = _parse_import_date(get_value("date_analyse") or get_value("date"))
            grant_date = _parse_optional_import_date(get_value("grant_date"))
            maturity_date = _parse_optional_import_date(get_value("maturity_date"))
            counterparty_name = get_value("contrepartie")
            country = get_value("pays", "Cote d Ivoire")
            category = get_value("categorie", "Entreprises")
            rating = get_value("notation", "BBB")
            crm_type = get_value("crm", "Aucune")
            currency = get_value("devise", "XOF")
            placement = get_value("placement", "bilan")
            hors_bilan_flag = get_value("hors_bilan")
            bilan_flag = get_value("bilan")
            is_off_balance = (
                _is_off_balance_placement(placement)
                or _is_truthy_import_flag(hors_bilan_flag)
                or (bilan_flag and _is_off_balance_placement(bilan_flag))
                or category.strip().lower() in {"hors bilan", "(l) hors bilan"}
            )
            gross_amount = _parse_amount(get_value("montant", "0"))
            coverage_percent = _parse_percent(get_value("couverture", "0"))
            collateral_value = _parse_amount(get_value("collateral", "0"))
            fx_haircut = _parse_percent(get_value("hfx", "0"))

            if not counterparty_name:
                errors.append(f"Ligne {row_index}: contrepartie manquante")
                continue

            target_exposure_id = exposure_id or next_exposure_id()
            reserved_ids.add(target_exposure_id)

            if is_off_balance:
                support_payload = ExposureCreate(
                    id=target_exposure_id,
                    analysis_date=analysis_date,
                    grant_date=grant_date,
                    maturity_date=maturity_date,
                    counterparty_name=counterparty_name,
                    country=country,
                    country_rating=get_value("notation_pays") or get_value("notation_pays_residence") or "Non noté",
                    category="Entreprises" if category.strip().lower() in {"hors bilan", "(l) hors bilan"} else category,
                    rating=rating,
                    gross_amount=0.0,
                    currency=currency,
                    status="Active",
                    crm_type="Aucune",
                    crm_coverage_percent=0.0,
                    crm_details=ExposureCrmDetails(),
                    comment=get_value("commentaire") or "Support contrepartie hors bilan",
                )
                support_record = build_exposure_record(support_payload, target_exposure_id)
                exposure_records.append(support_record)
                engagement_type = get_value("engagement_type", "Risque eleve")
                ccf = referentiels_service.get_ccf(engagement_type)
                nominal_amount = gross_amount
                ead = round(nominal_amount * ccf, 2)
                risk_weight = referentiels_service.get_risk_weight(
                    str(support_record.get("category_standard", "Entreprises")),
                    rating,
                )
                rwa = round(ead * risk_weight, 2)
                off_balance_records.append(
                    {
                        "id": f"HB_{target_exposure_id}_{row_index:03d}",
                        "analysis_date": analysis_date,
                        "counterparty_id": target_exposure_id,
                        "engagement_type": engagement_type,
                        "nominal_amount": nominal_amount,
                        "ccf": ccf,
                        "ead": ead,
                        "risk_weight": risk_weight,
                        "rwa": rwa,
                        "capital": calculate_capital(rwa),
                        "comment": get_value("commentaire") or "Import CSV hors bilan",
                    }
                )
                imported_off_balance += 1
                continue

            crm_mode = crm_mode_from_type(crm_type)
            crm_details = ExposureCrmDetails(
                mode=crm_mode,
                label=crm_type or "Aucune",
                collateral_value=collateral_value or (gross_amount * coverage_percent if crm_mode == "CRM financee" else 0.0),
                issuer_type=get_value("type_emetteur") or get_value("emetteur"),
                issuer_rating=get_value("notation_collateral") or get_value("notation_emetteur"),
                maturity_bucket=get_value("maturite", "<=1 an"),
                fx_haircut=fx_haircut,
                guarantor_name=get_value("garant"),
                guarantor_category=get_value("categorie_garant"),
                guarantor_rating=get_value("notation_garant"),
                coverage_percent=coverage_percent,
            )
            payload = ExposureCreate(
                id=target_exposure_id,
                analysis_date=analysis_date,
                grant_date=grant_date,
                maturity_date=maturity_date,
                counterparty_name=counterparty_name,
                country=country,
                country_rating=get_value("notation_pays") or get_value("notation_pays_residence") or "Non noté",
                category=category,
                rating=rating,
                gross_amount=gross_amount,
                currency=currency,
                status="Active",
                crm_type=crm_type or "Aucune",
                crm_coverage_percent=coverage_percent,
                crm_details=crm_details,
                comment=get_value("commentaire") or None,
            )
            exposure_records.append(build_exposure_record(payload, target_exposure_id))
            imported_balance += 1
        except Exception as exc:
            errors.append(f"Ligne {row_index}: {exc}")

    backup_path = database_manager.create_backup("before_csv_import")
    if exposure_records or off_balance_records:
        with database_manager.transaction() as connection:
            run_id = connection.execute(
                """
                INSERT INTO import_runs(source_type, source_name, imported_at, total_rows, imported_rows, rejected_rows, status, details_json)
                VALUES (?, ?, ?, ?, ?, ?, 'success', ?)
                """,
                (
                    "csv",
                    "clipboard_or_file.csv",
                    datetime.now().isoformat(),
                    len(rows) - 1,
                    imported_balance + imported_off_balance,
                    len(errors),
                    "{}",
                ),
            ).lastrowid
            exposure_repository.upsert_exposures(exposure_records, connection=connection)
            off_balance_repository.upsert_commitments(off_balance_records, connection=connection)
            connection.execute(
                "UPDATE import_runs SET details_json = ? WHERE id = ?",
                (
                    json.dumps(
                        {"backup_path": str(backup_path) if backup_path else ""},
                        ensure_ascii=False,
                    ),
                    run_id,
                ),
            )

    result: dict[str, int | str | list[str]] = {
        "status": "success",
        "imported": imported_balance + imported_off_balance,
        "imported_balance": imported_balance,
        "imported_off_balance": imported_off_balance,
        "total_lines_processed": len(rows) - 1,
    }
    if backup_path is not None:
        result["backup_path"] = str(backup_path)
    if errors:
        result["errors"] = len(errors)
        result["error_details"] = errors
    return result
