"""Acces centralise aux donnees Excel avec cache et overlays session."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
import json
from pathlib import Path
import re
from threading import Lock
from typing import Any
import unicodedata

from openpyxl import load_workbook

from app.core.runtime_paths import (
    app_data_root,
    default_excel_source_path,
    ensure_seed_data_file,
    exports_dir,
    is_packaged_runtime,
)
from app.expositions.models import ExposureCreate, ExposureCrmDetails
from database.services.rwa_calculation_service import build_exposure_record


def _resolve_excel_source_path() -> Path:
    if is_packaged_runtime():
        return default_excel_source_path()

    desktop_candidates = (
        Path.home() / "OneDrive" / "Desktop",
        Path.home() / "Desktop",
    )
    workbook_candidates: list[Path] = []
    for desktop in desktop_candidates:
        if not desktop.exists():
            continue
        workbook_candidates.extend(
            path for path in desktop.glob("BASE_CALCUL_RWA*.xlsx") if path.is_file()
        )
    if workbook_candidates:
        return max(workbook_candidates, key=lambda path: path.stat().st_mtime)
    return default_excel_source_path()


EXCEL_SOURCE_PATH = _resolve_excel_source_path()
APP_DATA_PATH = app_data_root()
EXPOSURE_METADATA_PATH = ensure_seed_data_file("exposure_metadata.json")
EXPOSURE_EXPORTS_PATH = exports_dir()
# Modèle épuré : uniquement les feuilles de saisie qui contiennent des
# données brutes réellement utilisées par le moteur de calcul. Les feuilles
# de référence/paramétrage (LISTE, (a)...(k), Mapping des pondérations,
# Ref_Ponderation) ont été retirées : leur contenu n'était jamais lu par les
# calculs (uniquement vérifié comme "présent" à l'import), donc elles ne
# faisaient qu'alourdir le fichier sans utilité pour l'utilisateur.
EXPECTED_SHEETS = (
    "Template données",
    "CRM_non_financee",
    "CRM_financée",
)
# Doit rester identique, colonne par colonne, à la spec du validateur
# (IMPORT_SHEET_SPECS dans app/validators/excel_import_validator.py) — sinon
# un modèle généré ici puis réimporté tel quel est rejeté par le validateur
# pour "colonnes requises manquantes".
#
# Chaque colonne ci-dessous correspond à une donnée brute que l'utilisateur
# saisit réellement (les mêmes informations que le formulaire "Ajouter une
# exposition"). Aucune colonne calculée (pondération finale, EAD, RWA,
# capital, maturités déduites, etc.) n'est demandée : ces valeurs sont
# recalculées automatiquement par le même moteur de calcul prudentiel que la
# saisie manuelle (voir excel_import_service._parse_workbook).
EXPECTED_COLUMNS_BY_SHEET: dict[str, tuple[str, ...]] = {
    "Template données": (
        "Date d'analyse",
        "ID_Exposition",
        "Contrepartie",
        "Notation_externe_contrepartie",
        "Pays_contrepartie",
        "Notation_externe_pays",
        "Catégorie d'exposition",
        "Montant_exposition_but_au_bilan",
        "Devise",
        "Type_CRM",
    ),
    "CRM_non_financee": (
        "ID_Exposition",
        "Nom du garant",
        "Catégorie du garant",
        "Note_garant",
        "Pays_garant",
        "Note_pays_garant",
        "Part couverte",
    ),
    "CRM_financée": (
        "ID_Exposition",
        "Valeur_Collatéral",
        "Type_emetteur",
        "Notation",
        "Bloc",
        "Maturite",
    ),
}
# Colonnes optionnelles : données brutes également utilisées par le moteur de
# calcul, mais qui ne s'appliquent qu'à certaines catégories d'exposition ou
# certains cas particuliers (mêmes options que le formulaire "Ajouter une
# exposition"). Elles peuvent rester vides si elles ne concernent pas la
# ligne.
OPTIONAL_COLUMNS_BY_SHEET: dict[str, tuple[str, ...]] = {
    "Template données": (
        "Date d'octroi",
        "Date d'échéance",
        "PRÊT TOTAL",
        "Montant d'exposition au HB",
        "Niveau de risque HB",
        "Statut",
        "Provisions",
        "Jours_impayes",
        "Commentaire",
        "Cas_particulier_souverain",
        "Souverain_ponderation_pref_nulle",
        "Souverain_OCE_etabli",
        "Souverain_note_OCE",
        "Organisme_public_cas_UEMOA_FCFA",
        "Organisme_public_activite_non_publique",
        "BMD_cas_haute_qualite",
        "BMD_cas_UEMOA_FCFA",
        "BMD_criteres_UEMOA_respectes",
        "BMD_institution_listee_FCFA",
        "Cas_institution_bancaire",
        "Type_autre_actif",
        "Clientele_detail_criteres_respectes",
        "Immobilier_residentiel_eligible",
        "Immobilier_commercial_eligible",
        "Ponderation_initiale_avant_defaut",
        "Defaut_pret_immo_residentiel",
        "Defaut_provision_min_20pct",
        "Entreprise_depasse_seuil_degradation_BCEAO",
        "Entreprise_procedure_prudentielle",
        "Entreprise_investissement_hors_loi_bancaire",
    ),
    "CRM_financée": (
        "Devise_Collatéral",
        "Type_Collatéral",
        "Obligation_convertible_indice_principal",
        "Decote_OPCVM_max",
    ),
}


class ExcelImportValidationError(ValueError):
    """Erreur metier retournee si la structure du fichier Excel est invalide."""

    def __init__(self, payload: dict[str, Any]) -> None:
        super().__init__(payload.get("message", "Invalid Excel workbook structure."))
        self.payload = payload


def _normalize_apostrophes(value: str) -> str:
    return value.replace("’", "'").replace("`", "'")


def _normalize_for_key(value: str) -> str:
    normalized = _normalize_apostrophes(value.strip().lower())
    normalized = unicodedata.normalize("NFKD", normalized)
    normalized = "".join(char for char in normalized if not unicodedata.combining(char))
    return " ".join(normalized.split())


def _as_clean_text(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _as_float(value: Any) -> float:
    if value is None:
        return 0.0
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if not text:
        return 0.0
    lowered = _normalize_for_key(text)
    if lowered in {"non eligible", "n/a", "na", "none"}:
        return 0.0
    compact = text.replace("\u202f", "").replace(" ", "").replace(",", ".")
    try:
        return float(compact)
    except ValueError:
        return 0.0


def _as_optional_float(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if not text:
        return None
    lowered = _normalize_for_key(text)
    if lowered in {"nd", "non eligible", "n/a", "na", "none"}:
        return None
    compact = text.replace("\u202f", "").replace(" ", "").replace(",", ".")
    try:
        return float(compact)
    except ValueError:
        return None


def _as_optional_bool(value: Any) -> bool | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    text = _normalize_for_key(str(value))
    if not text:
        return None
    if text in {"oui", "yes", "true", "vrai", "1", "x"}:
        return True
    if text in {"non", "no", "false", "faux", "0"}:
        return False
    return None


def _as_date(value: Any) -> date:
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, str) and value.strip():
        candidate = value.strip().split(" ")[0]
        try:
            return date.fromisoformat(candidate)
        except ValueError:
            return date.today()
    return date.today()


def _as_optional_date(value: Any) -> date | None:
    if value in (None, ""):
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, str) and value.strip():
        candidate = value.strip().split(" ")[0]
        for parser in (
            date.fromisoformat,
            lambda raw: datetime.strptime(raw, "%d/%m/%Y").date(),
            lambda raw: datetime.strptime(raw, "%d-%m-%Y").date(),
        ):
            try:
                return parser(candidate)
            except ValueError:
                continue
    return None


def _dashboard_category_from_raw(raw: str) -> str:
    cleaned = re.sub(r"^\([^)]+\)\s*", "", raw.strip())
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned or "Non renseigné"


def _standard_category_from_raw(raw: str) -> str:
    lowered = _normalize_for_key(raw)
    if lowered.startswith("(a)") or lowered.startswith("(b)"):
        return "Souverains"
    if lowered.startswith("(c)") or lowered.startswith("(d)"):
        return "Banques"
    if lowered.startswith("(e)") or lowered.startswith("(i)") or lowered.startswith("(j)") or lowered.startswith("(k)"):
        return "Entreprises"
    if lowered.startswith("(f)") or lowered.startswith("(g)") or lowered.startswith("(h)"):
        return "Particuliers"
    if lowered.startswith("(l)"):
        return "Entreprises"
    return "Entreprises"


def _normalize_country_display(country: str) -> str:
    lowered = _normalize_for_key(country)
    if lowered in {"cote d'ivoire", "cote d ivoire"}:
        return "Côte d'Ivoire"
    if lowered == "senegal":
        return "Sénégal"
    if lowered == "benin":
        return "Bénin"
    if lowered == "guinee-bissau":
        return "Guinée-Bissau"
    return country.strip()


def _crm_mode_from_type(crm_type: str) -> str:
    normalized = _normalize_for_key(crm_type)
    if not normalized or normalized in {"aucune", "sans crm", "non eligible"}:
        return "Aucune"
    if "non financ" in normalized or "garantie" in normalized or "assurance" in normalized:
        return "CRM non financee"
    if "cash" in normalized or "collateral" in normalized or "financee" in normalized:
        return "CRM financee"
    return "CRM non financee"


def _months_between(start: date | None, end: date | None) -> int | None:
    if start is None or end is None:
        return None
    months = (end.year - start.year) * 12 + (end.month - start.month)
    if end.day < start.day:
        months -= 1
    return max(months, 0)


def _as_yes_no(value: bool) -> str:
    return "Oui" if value else "Non"


@dataclass(slots=True)
class ExcelWorkbookCache:
    """Cache parse du classeur Excel source."""

    template_rows: list[dict[str, Any]]
    hb_rows: list[dict[str, Any]]
    crm_non_fin_rows: list[dict[str, Any]]
    crm_fin_rows: list[dict[str, Any]]
    ref_rows: list[list[Any]]


@dataclass(slots=True)
class SessionOverlay:
    """Donnees ajoutees en session, sans ecriture sur le classeur."""

    exposures: list[dict[str, Any]] = field(default_factory=list)
    off_balance: list[dict[str, Any]] = field(default_factory=list)
    crm: list[dict[str, Any]] = field(default_factory=list)
    reports: list[dict[str, Any]] = field(default_factory=list)


class ExcelRepository:
    """Fournit les lignes metier reconstruites depuis le fichier Excel."""

    def __init__(
        self,
        path: Path = EXCEL_SOURCE_PATH,
        metadata_path: Path = EXPOSURE_METADATA_PATH,
        exports_path: Path = EXPOSURE_EXPORTS_PATH,
    ) -> None:
        self._path = path
        self._metadata_path = metadata_path
        self._exports_path = exports_path
        self._lock = Lock()
        self._cached_mtime: float | None = None
        self._cache: ExcelWorkbookCache | None = None
        self._overlay = SessionOverlay()

    @property
    def source_path(self) -> Path:
        return self._path

    def _sheet_headers(self, workbook, sheet_name: str) -> list[str]:
        sheet = workbook[sheet_name]
        headers: list[str] = []
        for index in range(1, sheet.max_column + 1):
            value = sheet.cell(row=1, column=index).value
            text = _as_clean_text(value)
            headers.append(text or "")
        return headers

    def _collect_sheet_markers(self, workbook, sheet_name: str, max_columns: int = 23, max_rows: int = 25) -> set[str]:
        sheet = workbook[sheet_name]
        markers: set[str] = set()
        for row_index in range(1, min(sheet.max_row, max_rows) + 1):
            for column_index in range(1, min(sheet.max_column, max_columns) + 1):
                value = sheet.cell(row=row_index, column=column_index).value
                text = _as_clean_text(value)
                if text:
                    markers.add(_normalize_for_key(text))
        return markers

    def _validate_workbook_structure(self, workbook) -> None:
        workbook_sheets = set(workbook.sheetnames)
        missing_sheets = [sheet for sheet in EXPECTED_SHEETS if sheet not in workbook_sheets]
        missing_columns_by_sheet: dict[str, list[str]] = {}
        available_columns_by_sheet: dict[str, list[str]] = {}
        missing_indicators_by_sheet: dict[str, list[str]] = {}
        sheet_diagnostics: dict[str, list[str]] = {}

        for sheet_name, required_columns in EXPECTED_COLUMNS_BY_SHEET.items():
            if sheet_name not in workbook_sheets:
                continue
            available_columns = [header for header in self._sheet_headers(workbook, sheet_name) if header]
            available_columns_by_sheet[sheet_name] = available_columns
            missing_columns = [column for column in required_columns if column not in available_columns]
            if missing_columns:
                missing_columns_by_sheet[sheet_name] = missing_columns

        if missing_sheets or missing_columns_by_sheet or missing_indicators_by_sheet or sheet_diagnostics:
            payload: dict[str, Any] = {
                "error_code": "excel_structure_invalid",
                "message": "Le fichier Excel importé ne correspond pas au format attendu.",
                "expected_sheets": list(EXPECTED_SHEETS),
                "available_sheets": list(workbook.sheetnames),
                "sheet_columns": {sheet: list(columns) for sheet, columns in EXPECTED_COLUMNS_BY_SHEET.items()},
                "optional_columns": {sheet: list(columns) for sheet, columns in OPTIONAL_COLUMNS_BY_SHEET.items()},
            }
            if missing_sheets:
                payload["missing_sheets"] = missing_sheets
            if missing_columns_by_sheet:
                payload["missing_columns_by_sheet"] = missing_columns_by_sheet
            if available_columns_by_sheet:
                payload["available_columns_by_sheet"] = available_columns_by_sheet
            if missing_indicators_by_sheet:
                payload["missing_indicators_by_sheet"] = missing_indicators_by_sheet
            if sheet_diagnostics:
                payload["sheet_diagnostics"] = sheet_diagnostics
            raise ExcelImportValidationError(payload)

    def _read_sheet_rows(self, workbook, sheet_name: str) -> list[dict[str, Any]]:
        sheet = workbook[sheet_name]
        header = [sheet.cell(row=1, column=index).value for index in range(1, sheet.max_column + 1)]
        headers = [str(item).strip() if item is not None else "" for item in header]
        rows: list[dict[str, Any]] = []
        for row_index in range(2, sheet.max_row + 1):
            values = [sheet.cell(row=row_index, column=index).value for index in range(1, sheet.max_column + 1)]
            if not any(value not in (None, "") for value in values):
                continue
            row: dict[str, Any] = {}
            for index, value in enumerate(values):
                key = headers[index]
                if not key:
                    key = f"col_{index + 1}"
                row[key] = value
            rows.append(row)
        return rows

    def _read_ref_rows(self, workbook) -> list[list[Any]]:
        sheet = workbook["Ref_Ponderation"]
        rows: list[list[Any]] = []
        for row_index in range(1, sheet.max_row + 1):
            values = [sheet.cell(row=row_index, column=index).value for index in range(1, 24)]
            if any(value not in (None, "") for value in values):
                rows.append(values)
        return rows

    def _build_cache_from_workbook(self, workbook) -> ExcelWorkbookCache:
        self._validate_workbook_structure(workbook)
        # "Traitement_HB" et "Ref_Ponderation" ne font plus partie du modèle
        # épuré (voir EXPECTED_SHEETS) ; on les lit uniquement si un classeur
        # historique (avant nettoyage) les contient encore, pour ne pas
        # casser ce chemin de code legacy (list_exposures / upsert), qui
        # n'est plus utilisé par le pipeline d'import actif mais reste dans
        # ce fichier.
        hb_rows = (
            self._read_sheet_rows(workbook, "Traitement_HB")
            if "Traitement_HB" in workbook.sheetnames
            else []
        )
        ref_rows = (
            self._read_ref_rows(workbook) if "Ref_Ponderation" in workbook.sheetnames else []
        )
        return ExcelWorkbookCache(
            template_rows=self._read_sheet_rows(workbook, "Template données"),
            hb_rows=hb_rows,
            crm_non_fin_rows=self._read_sheet_rows(workbook, "CRM_non_financee"),
            crm_fin_rows=self._read_sheet_rows(workbook, "CRM_financée"),
            ref_rows=ref_rows,
        )

    def _build_cache_for_path(self, path: Path) -> ExcelWorkbookCache:
        workbook = load_workbook(path, data_only=True, read_only=True)
        try:
            return self._build_cache_from_workbook(workbook)
        finally:
            workbook.close()

    def _index_exposure_template_fields(
        self,
        template_rows: list[dict[str, Any]],
    ) -> dict[str, dict[str, Any]]:
        indexed: dict[str, dict[str, Any]] = {}
        for row in template_rows:
            exposure_id = _as_clean_text(row.get("ID_Exposition")) or ""
            if not exposure_id:
                continue
            indexed[exposure_id] = {
                "grant_date": _as_optional_date(row.get("Date d'octroi")),
                "maturity_date": _as_optional_date(row.get("Date d'échéance")),
                "country_rating": _as_clean_text(row.get("Notation_externe_pays"))
                or "Non noté",
                "provisions_amount": _as_optional_float(row.get("Provisions")),
            }
        return indexed

    def _load_template_rows_without_full_validation(self) -> list[dict[str, Any]]:
        workbook = load_workbook(self._path, data_only=True, read_only=True)
        try:
            if "Template données" not in workbook.sheetnames:
                raise ExcelImportValidationError(
                    {
                        "error_code": "excel_structure_invalid",
                        "message": "Le fichier Excel importé ne correspond pas au format attendu.",
                        "missing_sheets": ["Template données"],
                        "available_sheets": list(workbook.sheetnames),
                    }
                )

            available_columns = [
                header
                for header in self._sheet_headers(workbook, "Template données")
                if header
            ]
            if "ID_Exposition" not in available_columns:
                raise ExcelImportValidationError(
                    {
                        "error_code": "excel_structure_invalid",
                        "message": "Le fichier Excel importé ne correspond pas au format attendu.",
                        "missing_columns_by_sheet": {
                            "Template données": ["ID_Exposition"],
                        },
                        "available_columns_by_sheet": {
                            "Template données": available_columns,
                        },
                        "available_sheets": list(workbook.sheetnames),
                    }
                )

            return self._read_sheet_rows(workbook, "Template données")
        finally:
            workbook.close()

    def _load_cache(self) -> ExcelWorkbookCache:
        with self._lock:
            mtime = self._path.stat().st_mtime
            if self._cache is not None and self._cached_mtime == mtime:
                return self._cache
            cache = self._build_cache_for_path(self._path)
            self._cached_mtime = mtime
            self._cache = cache
            return cache

    def _empty_metadata(self) -> dict[str, dict[str, dict[str, Any]]]:
        return {
            "exposures": {},
            "off_balance": {},
        }

    def _load_metadata_unlocked(self) -> dict[str, dict[str, dict[str, Any]]]:
        if not self._metadata_path.exists():
            return self._empty_metadata()
        try:
            payload = json.loads(self._metadata_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return self._empty_metadata()
        metadata = self._empty_metadata()
        exposures = payload.get("exposures")
        off_balance = payload.get("off_balance")
        if isinstance(exposures, dict):
            metadata["exposures"] = {
                str(key): dict(value) for key, value in exposures.items() if isinstance(value, dict)
            }
        if isinstance(off_balance, dict):
            metadata["off_balance"] = {
                str(key): dict(value) for key, value in off_balance.items() if isinstance(value, dict)
            }
        return metadata

    def _save_metadata_unlocked(self, payload: dict[str, dict[str, dict[str, Any]]]) -> None:
        self._metadata_path.parent.mkdir(parents=True, exist_ok=True)
        self._metadata_path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2, default=str),
            encoding="utf-8",
        )

    def _invalidate_cache_unlocked(self) -> None:
        self._cached_mtime = None
        self._cache = None

    def _sheet_header_index(self, sheet) -> dict[str, int]:
        headers: dict[str, int] = {}
        for column_index in range(1, sheet.max_column + 1):
            value = _as_clean_text(sheet.cell(row=1, column=column_index).value)
            if value:
                headers[value] = column_index
        return headers

    def _find_row_index_by_id(self, sheet, header_index: dict[str, int], exposure_id: str) -> int | None:
        id_column = header_index.get("ID_Exposition")
        if id_column is None:
            return None
        for row_index in range(2, sheet.max_row + 1):
            current_id = _as_clean_text(sheet.cell(row=row_index, column=id_column).value)
            if current_id == exposure_id:
                return row_index
        return None

    def _set_row_values(
        self,
        sheet,
        header_index: dict[str, int],
        row_index: int,
        values: dict[str, Any],
    ) -> None:
        for header, value in values.items():
            column_index = header_index.get(header)
            if column_index is None:
                continue
            sheet.cell(row=row_index, column=column_index, value=value)

    def _delete_rows_by_id(self, sheet, header_index: dict[str, int], exposure_id: str) -> None:
        id_column = header_index.get("ID_Exposition")
        if id_column is None:
            return
        for row_index in range(sheet.max_row, 1, -1):
            current_id = _as_clean_text(sheet.cell(row=row_index, column=id_column).value)
            if current_id == exposure_id:
                sheet.delete_rows(row_index, 1)

    def _append_row(self, sheet, header_index: dict[str, int], values: dict[str, Any]) -> int:
        row_index = sheet.max_row + 1
        self._set_row_values(sheet, header_index, row_index, values)
        return row_index

    def _delete_rows_by_ids(
        self,
        sheet,
        header_index: dict[str, int],
        exposure_ids: set[str],
    ) -> set[str]:
        id_column = header_index.get("ID_Exposition")
        if id_column is None or not exposure_ids:
            return set()
        deleted_ids: set[str] = set()
        for row_index in range(sheet.max_row, 1, -1):
            current_id = _as_clean_text(sheet.cell(row=row_index, column=id_column).value)
            if current_id in exposure_ids:
                deleted_ids.add(current_id)
                sheet.delete_rows(row_index, 1)
        return deleted_ids

    def _row_index_by_id(self, sheet, header_index: dict[str, int]) -> dict[str, int]:
        id_column = header_index.get("ID_Exposition")
        if id_column is None:
            return {}
        indexed: dict[str, int] = {}
        for row_index in range(2, sheet.max_row + 1):
            current_id = _as_clean_text(sheet.cell(row=row_index, column=id_column).value)
            if current_id:
                indexed[current_id] = row_index
        return indexed

    def _upsert_exposure_unlocked(
        self,
        item: dict[str, Any],
        *,
        metadata: dict[str, dict[str, dict[str, Any]]],
        template_sheet,
        crm_non_fin_sheet,
        crm_fin_sheet,
        template_headers: dict[str, int],
        crm_non_fin_headers: dict[str, int],
        crm_fin_headers: dict[str, int],
        template_row_index: dict[str, int] | None = None,
    ) -> None:
        exposure_id = str(item["id"])
        template_row = (
            template_row_index.get(exposure_id)
            if template_row_index is not None
            else self._find_row_index_by_id(template_sheet, template_headers, exposure_id)
        )
        row_values = {
            "Date d'analyse": item["analysis_date"],
            "ID_Exposition": exposure_id,
            "Date d'octroi": item.get("grant_date"),
            "Date d'échéance": item.get("maturity_date"),
            "Maturité de l'exposition": item.get("exposure_maturity_months")
            or _months_between(item.get("grant_date"), item.get("maturity_date")),
            "Maturité résiduelle": item.get("residual_maturity_months")
            or _months_between(item.get("analysis_date"), item.get("maturity_date")),
            "Contrepartie": item["counterparty_name"],
            "Notation_externe_contrepartie": item["rating"],
            "Pays_contrepartie": item["country"],
            "Notation_externe_pays": item.get("country_rating", "Non noté"),
            "Pondération_pays": item.get("country_risk_weight"),
            "Catégorie d'exposition": item["category_raw"],
            "Pondération (RW)": item["final_rw"],
            "PRÊT TOTAL": item.get("loan_total_amount", item["gross_amount"]),
            "Montant_exposition_but_au_bilan": item.get(
                "on_balance_exposure_amount",
                item["gross_amount"],
            ),
            "Montant d'exposition au HB": item.get("off_balance_exposure_amount", 0.0),
            "Devise": item.get("currency", "XOF"),
            "CRM_existe": "OUI" if item.get("crm_exists", False) else "NON",
            "Type_CRM": item["crm_type"],
            "EAD_bilan": item.get("ead_bilan_amount", item["ead"]),
            "EAD_HB": item.get("ead_hb_amount"),
            "EAD_HB_ccf": item.get("ead_hb_ccf_amount"),
            "EAD_Total": item.get("ead_total_amount", item["ead"]),
            "RWA_EB": item.get("rwa_eb_amount"),
            "RWA_HB": item.get("rwa_hb_amount"),
            "RWA_crédit": item["rwa"],
            "Capital_min_reg": item["capital"],
        }
        if template_row is None:
            template_row = self._append_row(template_sheet, template_headers, row_values)
            if template_row_index is not None:
                template_row_index[exposure_id] = template_row
        else:
            self._set_row_values(template_sheet, template_headers, template_row, row_values)

        self._delete_rows_by_id(crm_non_fin_sheet, crm_non_fin_headers, exposure_id)
        self._delete_rows_by_id(crm_fin_sheet, crm_fin_headers, exposure_id)

        crm_details = dict(item.get("crm_details", {}))
        crm_mode = _crm_mode_from_type(str(crm_details.get("mode") or item.get("crm_type") or "Aucune"))
        coverage = _as_float(item.get("crm_coverage_percent"))
        if crm_mode == "CRM non financee":
            guarantor_rw = _as_float(item.get("guarantor_rw"))
            covered_amount = round(_as_float(item["gross_amount"]) * coverage, 2)
            non_covered_ratio = max(0.0, round(1.0 - coverage, 4))
            self._append_row(
                crm_non_fin_sheet,
                crm_non_fin_headers,
                {
                    "ID_Exposition": exposure_id,
                    "Nom du garant": crm_details.get("guarantor_name") or "",
                    "Note_garant": crm_details.get("guarantor_rating") or "",
                    "Pays_garant": crm_details.get("guarantor_country") or "",
                    "Note_pays_garant": crm_details.get("guarantor_country_rating") or "",
                    "Pondération_pays_garant": crm_details.get("guarantor_country_rw") or "",
                    "Catégorie du garant": crm_details.get("guarantor_category") or "",
                    "Pondération du garant": guarantor_rw,
                    "% Exp_couverte": coverage,
                    "%Exp_Nn_couverte": non_covered_ratio,
                    "Part couverte": covered_amount,
                    "Part non couverte": round(_as_float(item["gross_amount"]) - covered_amount, 2),
                    "RWA_non_fin": item["rwa"],
                },
            )
        elif crm_mode == "CRM financee":
            self._append_row(
                crm_fin_sheet,
                crm_fin_headers,
                {
                    "ID_Exposition": exposure_id,
                    "Valeur_Collatéral": crm_details.get("collateral_value") or 0.0,
                    "Type_emetteur": crm_details.get("issuer_type") or "",
                    "Notation": crm_details.get("issuer_rating") or "",
                    "Bloc": crm_details.get("label") or item["crm_type"],
                    "Maturite": crm_details.get("maturity_bucket") or "<=1 an",
                    "HE": crm_details.get("haircut") or 0.0,
                    "HC": crm_details.get("haircut") or 0.0,
                    "Hfx": crm_details.get("fx_haircut") or 0.0,
                    "Eva": item["gross_amount"],
                    "Cva": item["ead"],
                },
            )

        metadata["exposures"][exposure_id] = {
            "currency": item.get("currency", "XOF"),
            "status": item.get("status", "Active"),
            "comment": item.get("comment") or "",
            "crm_coverage_percent": coverage,
            "crm_details": crm_details,
            "original_rw": item.get("original_rw", 0.0),
            "final_rw": item.get("final_rw", 0.0),
            "ead": item.get("ead", 0.0),
            "rwa": item.get("rwa", 0.0),
            "capital": item.get("capital", 0.0),
        }

    def _append_off_balance_unlocked(
        self,
        item: dict[str, Any],
        *,
        metadata: dict[str, dict[str, dict[str, Any]]],
        sheet,
        headers: dict[str, int],
    ) -> str:
        row_index = self._append_row(
            sheet,
            headers,
            {
                "ID_Exposition": item["counterparty_id"],
                "Catégorie Hors bilan": item["engagement_type"],
                "Facteur_conversion (CCF)": item["ccf"],
                "EAD_HB_ccf": item.get("ead"),
            },
        )
        commitment_id = f"HB{row_index - 1:03d}"
        metadata["off_balance"][commitment_id] = {
            "comment": item.get("comment") or "",
        }
        return commitment_id

    def _metadata_for_exposure(self, exposure_id: str) -> dict[str, Any]:
        with self._lock:
            metadata = self._load_metadata_unlocked()
            return dict(metadata["exposures"].get(exposure_id, {}))

    def _crm_non_fin_by_rows(self, rows: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
        indexed: dict[str, dict[str, Any]] = {}
        for row in rows:
            exposure_id = _as_clean_text(row.get("ID_Exposition"))
            if exposure_id:
                indexed[exposure_id] = row
        return indexed

    def _crm_fin_by_rows(self, rows: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
        indexed: dict[str, dict[str, Any]] = {}
        for row in rows:
            exposure_id = _as_clean_text(row.get("ID_Exposition"))
            if exposure_id:
                indexed[exposure_id] = row
        return indexed

    def _find_template_by_id(self, exposure_id: str) -> dict[str, Any] | None:
        for row in self._load_cache().template_rows:
            current_id = _as_clean_text(row.get("ID_Exposition"))
            if current_id == exposure_id:
                return row
        return None

    def _build_exposure_from_template(
        self,
        row: dict[str, Any],
        *,
        exposure_metadata: dict[str, Any] | None = None,
        crm_non_fin_row: dict[str, Any] | None = None,
        crm_fin_row: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Construit un enregistrement d'exposition complet à partir d'une
        ligne brute du modèle Excel épuré.

        Contrairement à l'ancienne version, aucune colonne calculée
        (pondération finale, EAD, RWA, capital...) n'est lue depuis le
        fichier : seules les données brutes sont extraites, puis le même
        moteur de calcul prudentiel que la saisie manuelle
        (`build_exposure_record` / `compute_metrics` dans
        `rwa_calculation_service.py`) est invoqué pour obtenir des résultats
        strictement identiques, que l'exposition vienne du formulaire ou
        d'un import Excel.
        """
        exposure_id = _as_clean_text(row.get("ID_Exposition")) or ""
        raw_category = _as_clean_text(row.get("Catégorie d'exposition")) or "Entreprises"
        country = _normalize_country_display(_as_clean_text(row.get("Pays_contrepartie")) or "")
        country_rating = _as_clean_text(row.get("Notation_externe_pays")) or "Non noté"
        rating = _as_clean_text(row.get("Notation_externe_contrepartie")) or "Non noté"
        grant_date = _as_optional_date(row.get("Date d'octroi"))
        maturity_date = _as_optional_date(row.get("Date d'échéance"))
        crm_type = _as_clean_text(row.get("Type_CRM")) or "Aucune"
        currency = _as_clean_text(row.get("Devise")) or "XOF"

        loan_total_amount = _as_optional_float(row.get("PRÊT TOTAL"))
        on_balance_exposure_amount = _as_optional_float(row.get("Montant_exposition_but_au_bilan"))
        off_balance_exposure_amount = _as_optional_float(row.get("Montant d'exposition au HB"))
        gross_amount = (
            on_balance_exposure_amount
            if on_balance_exposure_amount is not None
            else (loan_total_amount or 0.0)
        )

        crm_mode = _crm_mode_from_type(crm_type)
        crm_details_kwargs: dict[str, Any] = {"mode": crm_mode, "label": crm_type}
        coverage_percent = 0.0
        if crm_mode == "CRM non financee" and crm_non_fin_row is not None:
            covered_amount = _as_float(crm_non_fin_row.get("Part couverte"))
            coverage_base = gross_amount or 0.0
            coverage_percent = 0.0 if coverage_base <= 0 else min(covered_amount / coverage_base, 1.0)
            crm_details_kwargs.update(
                {
                    "guarantor_name": _as_clean_text(crm_non_fin_row.get("Nom du garant")) or "",
                    "guarantor_category": _as_clean_text(crm_non_fin_row.get("Catégorie du garant")) or "",
                    "guarantor_rating": _as_clean_text(crm_non_fin_row.get("Note_garant")) or "",
                    "guarantor_country": _as_clean_text(crm_non_fin_row.get("Pays_garant")) or "",
                    "guarantor_country_rating": _as_clean_text(crm_non_fin_row.get("Note_pays_garant")) or "",
                    "coverage_percent": coverage_percent,
                }
            )
        elif crm_mode == "CRM financee" and crm_fin_row is not None:
            crm_details_kwargs.update(
                {
                    "collateral_value": _as_float(crm_fin_row.get("Valeur_Collatéral")),
                    "collateral_currency": _as_clean_text(crm_fin_row.get("Devise_Collatéral")) or currency,
                    "collateral_type": _as_clean_text(crm_fin_row.get("Type_Collatéral"))
                    or "Liquidités dans la même devise",
                    "issuer_type": _as_clean_text(crm_fin_row.get("Type_emetteur")) or "",
                    "issuer_rating": _as_clean_text(crm_fin_row.get("Notation")) or "",
                    "maturity_bucket": _as_clean_text(crm_fin_row.get("Maturite")) or "<=1 an",
                    "label": _as_clean_text(crm_fin_row.get("Bloc")) or crm_type,
                    "convertible_main_index": _as_optional_bool(
                        crm_fin_row.get("Obligation_convertible_indice_principal")
                    )
                    if _as_optional_bool(crm_fin_row.get("Obligation_convertible_indice_principal")) is not None
                    else True,
                    "opcvm_highest_haircut": (
                        _as_optional_float(crm_fin_row.get("Decote_OPCVM_max"))
                        if _as_optional_float(crm_fin_row.get("Decote_OPCVM_max")) is not None
                        else 0.30
                    ),
                }
            )

        payload = ExposureCreate(
            id=exposure_id or None,
            analysis_date=_as_date(row.get("Date d'analyse")),
            grant_date=grant_date,
            maturity_date=maturity_date,
            counterparty_name=_as_clean_text(row.get("Contrepartie")) or exposure_id,
            country=country,
            country_rating=country_rating,
            category=raw_category,
            rating=rating,
            gross_amount=gross_amount,
            loan_total_amount=loan_total_amount,
            on_balance_exposure_amount=on_balance_exposure_amount,
            off_balance_exposure_amount=off_balance_exposure_amount,
            provisions_amount=_as_optional_float(row.get("Provisions")),
            jours_impayes=int(_as_optional_float(row.get("Jours_impayes")) or 0),
            currency=currency,
            status=_as_clean_text(row.get("Statut")) or "Active",
            sovereign_special_case=_as_clean_text(row.get("Cas_particulier_souverain")) or "",
            sovereign_preferential_zero_weight=_as_optional_bool(
                row.get("Souverain_ponderation_pref_nulle")
            )
            or False,
            sovereign_oce_established=_as_optional_bool(row.get("Souverain_OCE_etabli")) or False,
            sovereign_oce_note=_as_clean_text(row.get("Souverain_note_OCE")) or "",
            public_body_uemoa_fcfa_case=_as_optional_bool(row.get("Organisme_public_cas_UEMOA_FCFA")),
            public_body_non_public_activity=_as_optional_bool(
                row.get("Organisme_public_activite_non_publique")
            ),
            bmd_high_quality_case=_as_optional_bool(row.get("BMD_cas_haute_qualite")),
            bmd_uemoa_fcfa_case=_as_optional_bool(row.get("BMD_cas_UEMOA_FCFA")),
            bmd_uemoa_criteria_satisfied=_as_optional_bool(row.get("BMD_criteres_UEMOA_respectes")),
            bmd_listed_institution_fcfa_case=_as_optional_bool(row.get("BMD_institution_listee_FCFA")),
            bank_institution_case=_as_clean_text(row.get("Cas_institution_bancaire")),
            other_asset_type=_as_clean_text(row.get("Type_autre_actif")),
            off_balance_risk_level=_as_clean_text(row.get("Niveau de risque HB")),
            retail_eligibility_criteria_satisfied=_as_optional_bool(
                row.get("Clientele_detail_criteres_respectes")
            ),
            residential_mortgage_eligible=_as_optional_bool(row.get("Immobilier_residentiel_eligible")),
            commercial_real_estate_eligible=_as_optional_bool(row.get("Immobilier_commercial_eligible")),
            defaulted_exposure_initial_risk_weight=_as_optional_float(
                row.get("Ponderation_initiale_avant_defaut")
            ),
            defaulted_exposure_residential_mortgage_in_default=_as_optional_bool(
                row.get("Defaut_pret_immo_residentiel")
            ),
            defaulted_exposure_provision_at_least_twenty_percent=_as_optional_bool(
                row.get("Defaut_provision_min_20pct")
            ),
            enterprise_exceeds_bceao_degradation_threshold=_as_optional_bool(
                row.get("Entreprise_depasse_seuil_degradation_BCEAO")
            ),
            enterprise_prudential_procedure=_as_optional_bool(row.get("Entreprise_procedure_prudentielle")),
            enterprise_investment_firm_without_banking_law=_as_optional_bool(
                row.get("Entreprise_investissement_hors_loi_bancaire")
            ),
            crm_type=crm_type,
            crm_coverage_percent=coverage_percent,
            crm_details=ExposureCrmDetails(**crm_details_kwargs),
            comment=_as_clean_text(row.get("Commentaire")),
        )

        return build_exposure_record(payload, exposure_id or "")

    def exposure_template_fields_by_id(self) -> dict[str, dict[str, Any]]:
        return self._index_exposure_template_fields(self._load_cache().template_rows)

    def exposure_template_fields_by_id_relaxed(self) -> dict[str, dict[str, Any]]:
        template_rows = self._load_template_rows_without_full_validation()
        return self._index_exposure_template_fields(template_rows)

    def list_exposures(self) -> list[dict[str, Any]]:
        cache = self._load_cache()
        with self._lock:
            metadata = self._load_metadata_unlocked()["exposures"]
        crm_non_fin = self._crm_non_fin_by_rows(cache.crm_non_fin_rows)
        crm_fin = self._crm_fin_by_rows(cache.crm_fin_rows)
        base = [
            self._build_exposure_from_template(
                row,
                exposure_metadata=metadata.get(_as_clean_text(row.get("ID_Exposition")) or "", {}),
                crm_non_fin_row=crm_non_fin.get(_as_clean_text(row.get("ID_Exposition")) or ""),
                crm_fin_row=crm_fin.get(_as_clean_text(row.get("ID_Exposition")) or ""),
            )
            for row in cache.template_rows
            if not _normalize_for_key(_as_clean_text(row.get("Catégorie d'exposition")) or "").startswith("(l) hors bilan")
        ]
        return base + [item.copy() for item in self._overlay.exposures]


excel_repository = ExcelRepository()
