"""Validation et description du format d'import Excel."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any
import unicodedata


class ExcelImportValidationError(ValueError):
    """Erreur métier retournée si le classeur ne respecte pas le format attendu."""

    def __init__(self, payload: dict[str, Any]) -> None:
        super().__init__(payload.get("message", "Format Excel d'import invalide."))
        self.payload = payload


@dataclass(frozen=True, slots=True)
class ExcelColumnSpec:
    name: str
    value_type: str
    description: str

    def to_dict(self) -> dict[str, str]:
        return {
            "name": self.name,
            "type": self.value_type,
            "description": self.description,
        }


@dataclass(frozen=True, slots=True)
class ExcelSheetSpec:
    name: str
    description: str
    role: str
    required: bool
    required_columns: tuple[ExcelColumnSpec, ...] = ()
    optional_columns: tuple[ExcelColumnSpec, ...] = ()
    required_markers: tuple[str, ...] = ()
    notes: tuple[str, ...] = ()
    header_row: int = 1

    @property
    def import_columns(self) -> tuple[str, ...]:
        return tuple(
            column.name for column in self.required_columns + self.optional_columns
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "description": self.description,
            "role": self.role,
            "required": self.required,
            "header_row": self.header_row,
            "required_columns": [column.to_dict() for column in self.required_columns],
            "optional_columns": [column.to_dict() for column in self.optional_columns],
            "required_markers": list(self.required_markers),
            "notes": list(self.notes),
        }


def _column(name: str, value_type: str, description: str) -> ExcelColumnSpec:
    return ExcelColumnSpec(name=name, value_type=value_type, description=description)


def _normalize_text(value: str) -> str:
    normalized = value.replace("’", "'").replace("`", "'").strip().lower()
    normalized = unicodedata.normalize("NFKD", normalized)
    normalized = "".join(
        character
        for character in normalized
        if not unicodedata.combining(character)
    )
    return " ".join(normalized.split())


IMPORT_SHEET_SPECS: tuple[ExcelSheetSpec, ...] = (
    ExcelSheetSpec(
        name="Template données",
        description="Feuille principale de saisie des expositions au bilan.",
        role="Saisie",
        required=True,
        header_row=1,
        required_columns=(
            _column("Date d'analyse", "date", "Date d'observation de l'exposition"),
            _column("ID_Exposition", "texte", "Identifiant unique de l'exposition"),
            _column("Contrepartie", "texte", "Nom de la contrepartie"),
            _column(
                "Notation_externe_contrepartie",
                "texte",
                "Notation externe de la contrepartie",
            ),
            _column("Pays_contrepartie", "texte", "Pays de résidence"),
            _column(
                "Notation_externe_pays",
                "texte",
                "Notation externe du pays",
            ),
            _column(
                "Catégorie d'exposition",
                "texte",
                "Catégorie prudentielle BCEAO",
            ),
            _column(
                "Montant_exposition_but_au_bilan",
                "nombre",
                "Montant de l'exposition porté au bilan",
            ),
            _column("Devise", "devise", "Devise de l'exposition"),
            _column("Type_CRM", "texte", "Aucune / CRM financee / CRM non financee"),
        ),
        optional_columns=(
            # ── Identification de la contrepartie, exigée par le FODEP ──────
            # Ces cinq colonnes décrivent la contrepartie et non l'exposition :
            # elles se répètent donc sur chacune de ses lignes, et la dernière
            # valeur non vide rencontrée fait foi. Sans elles, l'EP30 reste
            # vide et les états EP38 et EP39 ne trouvent aucun bénéficiaire.
            _column(
                "N_Centrale_risques",
                "texte",
                "Numéro de la contrepartie à la Centrale des risques (EP30)",
            ),
            _column(
                "Secteur_activite",
                "texte",
                "Secteur d'activités de la contrepartie (EP30)",
            ),
            _column(
                "Groupe_clients_lies",
                "texte",
                "Nom du groupe de clients liés ; le groupe est créé s'il n'existe pas",
            ),
            _column(
                "N_Centrale_risques_groupe",
                "texte",
                "Numéro du groupe de clients liés à la Centrale des risques",
            ),
            _column(
                "Categorie_lien",
                "texte",
                "Contrôle de droit / de fait / Dépendance économique",
            ),
            _column(
                "Partie_liee",
                "texte",
                "Qualité au titre des états EP38 et EP39, si la contrepartie en est une",
            ),
            _column("Date d'octroi", "date", "Date d'octroi du concours"),
            _column("Date d'échéance", "date", "Date d'échéance contractuelle"),
            _column(
                "PRÊT TOTAL",
                "nombre",
                "Montant total du prêt ou de l'exposition",
            ),
            _column(
                "Montant d'exposition au HB",
                "nombre",
                "Montant de l'exposition portée hors bilan",
            ),
            _column(
                "Niveau de risque HB",
                "texte",
                "Risque faible / mineur / moyen / élevé / très élevé",
            ),
            _column("Statut", "texte", "Statut de gestion de l'exposition"),
            _column("Provisions", "nombre", "Montant exact des provisions"),
            _column(
                "Jours_impayes",
                "nombre",
                "Nombre de jours d'impayés (créances en souffrance)",
            ),
            _column("Commentaire", "texte", "Commentaire de gestion"),
            _column(
                "Cas_particulier_souverain",
                "texte",
                "Type spécifique d'exposition souveraine (pondération préférentielle)",
            ),
            _column(
                "Souverain_ponderation_pref_nulle",
                "oui/non",
                "Souverain préférentiel à pondération nulle",
            ),
            _column("Souverain_OCE_etabli", "oui/non", "Souverain non noté établi par les OCE"),
            _column("Souverain_note_OCE", "texte", "Note OCE de 0 à 7"),
            _column(
                "Organisme_public_cas_UEMOA_FCFA",
                "oui/non",
                "Organisme public hors administration centrale, libellé et financé en FCFA",
            ),
            _column(
                "Organisme_public_activite_non_publique",
                "oui/non",
                "L'organisme public finance une activité non publique",
            ),
            _column("BMD_cas_haute_qualite", "oui/non", "BMD notation élevée / soutien actionnarial fort"),
            _column("BMD_cas_UEMOA_FCFA", "oui/non", "BMD relevant du cas UEMOA libellé et financé en FCFA"),
            _column(
                "BMD_criteres_UEMOA_respectes",
                "oui/non",
                "BMD UEMOA en FCFA respectant les critères c), d) et e)",
            ),
            _column(
                "BMD_institution_listee_FCFA",
                "oui/non",
                "BMD de la liste BIRD/SFI/BAsD/BAD/BERD/BEI/FEI/BNI/BDC/BIsD/BDCE/AMGI/BOAD",
            ),
            _column("Cas_institution_bancaire", "texte", "Cas prudentiel des institutions bancaires"),
            _column("Type_autre_actif", "texte", "Type d'élément d'actif (catégorie autres actifs)"),
            _column(
                "Clientele_detail_criteres_respectes",
                "oui/non",
                "Critères de classement en clientèle de détail respectés",
            ),
            _column(
                "Immobilier_residentiel_eligible",
                "oui/non",
                "Conditions d'éligibilité de l'immobilier résidentiel respectées",
            ),
            _column(
                "Immobilier_commercial_eligible",
                "oui/non",
                "Conditions d'éligibilité de l'immobilier commercial respectées",
            ),
            _column(
                "Ponderation_initiale_avant_defaut",
                "nombre",
                "Pondération initiale de l'exposition avant défaut",
            ),
            _column(
                "Defaut_pret_immo_residentiel",
                "oui/non",
                "Exposition en défaut = prêt immobilier résidentiel",
            ),
            _column(
                "Defaut_provision_min_20pct",
                "oui/non",
                "Provisions ≥ 20 % de l'encours",
            ),
            _column(
                "Entreprise_depasse_seuil_degradation_BCEAO",
                "oui/non",
                "Portefeuille entreprises dépassant le seuil BCEAO de dégradation",
            ),
            _column(
                "Entreprise_procedure_prudentielle",
                "oui/non",
                "Entreprise faisant l'objet d'une procédure prudentielle",
            ),
            _column(
                "Entreprise_investissement_hors_loi_bancaire",
                "oui/non",
                "Entreprise d'investissement non soumise à la loi bancaire",
            ),
        ),
        notes=(
            "Cette feuille reprend uniquement les données brutes du formulaire "
            "« Ajouter une exposition » ; les résultats prudentiels (pondération, "
            "EAD, RWA, capital) sont recalculés automatiquement à l'import.",
        ),
    ),
    ExcelSheetSpec(
        name="CRM_non_financee",
        description="Détails des garanties et protections non financées.",
        role="Saisie",
        required=True,
        header_row=1,
        required_columns=(
            _column("ID_Exposition", "texte", "Identifiant de l'exposition"),
            _column("Nom du garant", "texte", "Nom du garant"),
            _column("Catégorie du garant", "texte", "Catégorie prudentielle du garant"),
            _column("Note_garant", "texte", "Notation du garant"),
            _column("Pays_garant", "texte", "Pays du garant"),
            _column("Note_pays_garant", "texte", "Notation externe du pays du garant"),
            _column("Part couverte", "nombre", "Montant couvert par la garantie"),
        ),
        notes=(
            "La pondération du garant, la pondération du pays du garant et le "
            "RWA associé sont recalculés automatiquement, pas saisis.",
        ),
    ),
    ExcelSheetSpec(
        name="CRM_financée",
        description="Détails des sûretés financées associées aux expositions.",
        role="Saisie",
        required=True,
        header_row=1,
        required_columns=(
            _column("ID_Exposition", "texte", "Identifiant de l'exposition"),
            _column("Valeur_Collatéral", "nombre", "Valeur du collatéral"),
            _column("Type_emetteur", "texte", "Type d'émetteur"),
            _column("Notation", "texte", "Notation du collatéral"),
            _column("Bloc", "texte", "Libellé métier de la CRM"),
            _column("Maturite", "texte", "Tranche de maturité"),
        ),
        optional_columns=(
            _column("Devise_Collatéral", "devise", "Devise de la sûreté (défaut : devise de l'exposition)"),
            _column(
                "Type_Collatéral",
                "texte",
                "Type de sûreté financée (défaut : Liquidités dans la même devise)",
            ),
            _column(
                "Obligation_convertible_indice_principal",
                "oui/non",
                "Obligation convertible incluse dans un indice principal",
            ),
            _column(
                "Decote_OPCVM_max",
                "nombre",
                "Plus forte décote applicable aux actifs éligibles de l'OPCVM (défaut : 0,30)",
            ),
        ),
        notes=(
            "Les décotes (HE, HC, Hfx) et les valeurs ajustées (Eva, Cva) sont "
            "recalculées automatiquement, pas saisies.",
        ),
    ),
)


def build_excel_import_spec() -> dict[str, Any]:
    required_names = [spec.name for spec in IMPORT_SHEET_SPECS if spec.required]
    return {
        "accepted_extensions": [".xlsx"],
        "sheets": [spec.to_dict() for spec in IMPORT_SHEET_SPECS],
        "required_sheet_names": required_names,
        "optional_sheet_names": [],
        "notes": [
            "Le modèle téléchargé reprend le classeur complet utilisé par l'outil.",
            "Toutes les feuilles du modèle sont requises et doivent être conservées.",
            "Les noms de feuilles, l'ordre des colonnes de saisie et les libellés doivent être respectés exactement.",
            "Les feuilles de référence et de paramétrage ne doivent pas être supprimées ni renommées.",
            "Le fichier Excel reste uniquement une source d'entrée et n'est jamais réécrit pendant l'import.",
        ],
    }


def read_sheet_headers(sheet, row_index: int = 1) -> list[str]:
    header_row = next(
        sheet.iter_rows(min_row=row_index, max_row=row_index, values_only=True),
        (),
    )
    return [str(value).strip() if value is not None else "" for value in header_row]


def _collect_sheet_markers(
    sheet,
    *,
    max_rows: int = 40,
    max_columns: int = 30,
) -> list[str]:
    markers: list[str] = []
    for row in sheet.iter_rows(
        min_row=1,
        max_row=max_rows,
        min_col=1,
        max_col=max_columns,
        values_only=True,
    ):
        for value in row:
            if value is None:
                continue
            text = str(value).strip()
            if text:
                markers.append(_normalize_text(text))
    return markers


def _has_marker(expected_marker: str, available_markers: list[str]) -> bool:
    normalized_expected = _normalize_text(expected_marker)
    return any(
        normalized_expected in marker or marker in normalized_expected
        for marker in available_markers
    )


def inspect_workbook_structure(workbook) -> dict[str, Any]:
    workbook_sheets = set(workbook.sheetnames)
    sheet_reports: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []

    for spec in IMPORT_SHEET_SPECS:
        exists = spec.name in workbook_sheets
        headers = (
            read_sheet_headers(workbook[spec.name], row_index=spec.header_row)
            if exists and spec.required_columns
            else []
        )
        missing_required_columns = [
            column.name for column in spec.required_columns if column.name not in headers
        ]
        available_markers = (
            _collect_sheet_markers(workbook[spec.name])
            if exists and spec.required_markers
            else []
        )
        missing_required_markers = [
            marker
            for marker in spec.required_markers
            if not _has_marker(marker, available_markers)
        ]

        if spec.required and not exists:
            errors.append(
                {
                    "sheet": spec.name,
                    "row": None,
                    "column": None,
                    "message": "Feuille requise manquante.",
                }
            )
        elif exists and missing_required_columns:
            for column_name in missing_required_columns:
                errors.append(
                    {
                        "sheet": spec.name,
                        "row": spec.header_row,
                        "column": column_name,
                        "message": "Colonne requise manquante.",
                    }
                )
        elif exists and missing_required_markers:
            for marker_name in missing_required_markers:
                errors.append(
                    {
                        "sheet": spec.name,
                        "row": None,
                        "column": None,
                        "message": f"Repère requis manquant: {marker_name}.",
                    }
                )

        sheet_reports.append(
            {
                "name": spec.name,
                "description": spec.description,
                "role": spec.role,
                "required": spec.required,
                "header_row": spec.header_row,
                "available_columns": headers,
                "required_columns": [column.to_dict() for column in spec.required_columns],
                "optional_columns": [],
                "required_markers": list(spec.required_markers),
                "missing_required_columns": missing_required_columns,
                "missing_optional_columns": [],
                "missing_required_markers": missing_required_markers,
                "notes": list(spec.notes),
                "exists": exists,
            }
        )

    return {
        "valid": not errors,
        "sheet_count": len(workbook.sheetnames),
        "detected_sheets": list(workbook.sheetnames),
        "sheets": sheet_reports,
        "errors": errors,
    }
