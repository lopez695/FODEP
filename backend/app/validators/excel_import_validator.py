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
                "Regime_prudentiel_specifique",
                "texte",
                "Régime ou traitement prudentiel spécifique au sens des circulaires BCEAO",
            ),
            _column(
                "Cas_particulier_souverain",
                "texte",
                "Type spécifique d'exposition souveraine (pondération préférentielle)",
            ),
            _column("Souverain_note_OCE", "texte", "Note OCE de 0 à 7"),
            _column("Type_autre_actif", "texte", "Type d'élément d'actif (catégorie autres actifs)"),
            _column(
                "Ponderation_initiale_avant_defaut",
                "nombre",
                "Pondération initiale de l'exposition avant défaut",
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


# ═══════════════════════════════════════════════════════════════════════════
# Exigences conditionnelles
# ═══════════════════════════════════════════════════════════════════════════
#
# Une colonne « optionnelle » ne l'est que parce qu'elle ne concerne pas toutes
# les categories. Laissee vide la ou elle s'applique, elle ne fait pas echouer
# l'import : elle fausse le calcul, en silence.
#
# Mesure sur un portefeuille de 1 500 expositions, chaque colonne videe tour a
# tour, ecart sur le RWA total :
#
#     PRET TOTAL                          -9,21 %
#     Type_autre_actif                    +3,80 %
#     Provisions                          +3,64 %
#     Niveau de risque HB                 +3,41 %
#     Montant d'exposition au HB          -1,25 %
#     Ponderation_initiale_avant_defaut   -0,53 %
#     Regime_prudentiel_specifique        -0,33 %
#
# Toutes videes ensemble, le RWA declare passait de 686,97 a 785,66 milliards
# -- +14,4 % -- sans un rejet ni un avertissement.

COLONNE_CATEGORIE = "Catégorie d'exposition"
COLONNE_MONTANT_HB = "Montant d'exposition au HB"
COLONNE_NIVEAU_HB = "Niveau de risque HB"

# Colonnes exigees selon la categorie prudentielle de la ligne, avec ce que
# leur absence coute au calcul.
EXIGENCES_PAR_CATEGORIE: dict[str, tuple[tuple[str, str], ...]] = {
    "Prêts garantis par l'immo R": (
        ("PRÊT TOTAL", "la quotite de financement, qui decide de la ponderation"),
    ),
    "Prêts garantis par l'immo C": (
        ("PRÊT TOTAL", "la quotite de financement, qui decide de la ponderation"),
    ),
    "Autres actifs": (
        ("Type_autre_actif", "la nature de l'actif, qui porte sa ponderation"),
    ),
    "Créances en souffrance": (
        ("Jours_impayes", "l'anciennete de l'impaye"),
        (
            "Ponderation_initiale_avant_defaut",
            "la ponderation d'origine, base du traitement du defaut",
        ),
    ),
}

# Exigées sur toute ligne (vide par défaut car le régime prudentiel spécifique
# vaut "Standard" lorsqu'il est laissé vide).
EXIGENCES_TOUTES_LIGNES: tuple[tuple[str, str], ...] = ()

# Identification de la contrepartie : exigée une fois par contrepartie.
# Le numéro à la Centrale des risques et le secteur d'activité sont exigés.
# En revanche, l'appartenance à un groupe ou la qualité de partie liée ne
# concernent pas toutes les contreparties (laissées vides pour un client indépendant).
EXIGENCES_PAR_CONTREPARTIE: tuple[tuple[str, str, bool], ...] = (
    ("N_Centrale_risques", "l'identifiant de la contrepartie sur l'EP29 et l'EP32", False),
    ("Secteur_activite", "le secteur declare sur l'EP29 et l'EP30", False),
)

# Une contrepartie hors groupe n'a rien d'honnete a porter dans les trois
# colonnes de groupe. « Repondre » a l'exigence, c'est alors le dire : ces
# mentions valent reponse, au meme titre qu'un nom de groupe.
MENTIONS_SANS_OBJET = frozenset(
    {"neant", "néant", "sans objet", "non applicable", "n/a", "na", "-", "aucun", "aucune"}
)


def _renseignee(valeur: Any) -> bool:
    return valeur is not None and str(valeur).strip() != ""


def _repondue(valeur: Any, *, neant_accepte: bool) -> bool:
    """Une case a laquelle le declarant a repondu.

    « Neant » est une reponse la ou l'absence est un fait declarable -- pas de
    groupe, pas de qualite de partie liee. Ailleurs, c'est une case vide
    deguisee, et la regle la refuse comme telle.
    """

    if not _renseignee(valeur):
        return False
    if neant_accepte:
        return True
    return str(valeur).strip().casefold() not in MENTIONS_SANS_OBJET


def controler_exigences_conditionnelles(
    lignes: list[tuple[int, dict[str, Any]]],
) -> list[dict[str, Any]]:
    """Releve les cases exigees par le contexte de la ligne et restees vides.

    `lignes` porte des couples (numero de ligne dans le classeur, valeurs) :
    designer un manque par sa ligne Excel est la seule facon utile de le dire au
    declarant.

    Retourne une liste de manques, chacun portant la ligne du classeur, la
    colonne, et ce que son absence coute. Vide, le classeur est complet.
    """

    manques: list[dict[str, Any]] = []
    vues: set[str] = set()

    for index, ligne in lignes:
        categorie = str(ligne.get(COLONNE_CATEGORIE) or "").strip()
        identifiant = str(ligne.get("ID_Exposition") or "").strip()

        exigences = list(EXIGENCES_TOUTES_LIGNES)
        exigences.extend(EXIGENCES_PAR_CATEGORIE.get(categorie, ()))

        # Le hors bilan se declare par paire : un montant sans niveau de risque
        # n'a pas de facteur de conversion, un niveau sans montant ne s'applique
        # a rien.
        if _renseignee(ligne.get(COLONNE_MONTANT_HB)) and not _renseignee(
            ligne.get(COLONNE_NIVEAU_HB)
        ):
            exigences.append(
                (COLONNE_NIVEAU_HB, "le facteur de conversion de l'engagement hors bilan")
            )
        if _renseignee(ligne.get(COLONNE_NIVEAU_HB)) and not _renseignee(
            ligne.get(COLONNE_MONTANT_HB)
        ):
            exigences.append(
                (COLONNE_MONTANT_HB, "le montant auquel appliquer le niveau de risque")
            )

        for colonne, consequence in exigences:
            if not _renseignee(ligne.get(colonne)):
                manques.append(
                    {
                        "ligne": index,
                        "id_exposition": identifiant,
                        "colonne": colonne,
                        "portee": categorie or "toutes catégories",
                        "consequence": consequence,
                    }
                )

        # Identification : relevee une fois par contrepartie. Une contrepartie
        # etalee sur plusieurs lignes peut n'en renseigner qu'une.
        contrepartie = str(ligne.get("Contrepartie") or "").strip()
        if contrepartie and contrepartie not in vues:
            vues.add(contrepartie)
            siennes = [
                autre
                for _, autre in lignes
                if str(autre.get("Contrepartie") or "").strip() == contrepartie
            ]
            for colonne, consequence, neant_accepte in EXIGENCES_PAR_CONTREPARTIE:
                if not any(
                    _repondue(autre.get(colonne), neant_accepte=neant_accepte)
                    for autre in siennes
                ):
                    manques.append(
                        {
                            "ligne": index,
                            "id_exposition": identifiant,
                            "colonne": colonne,
                            "portee": f"contrepartie « {contrepartie} »",
                            "consequence": consequence,
                        }
                    )

    return manques
