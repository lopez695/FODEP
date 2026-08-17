"""Règles de calcul RWA partagées entre SQLite et les modules métier."""

from __future__ import annotations

from datetime import date
import re
from typing import Any

from app.core.calculations import (
    bucketize_rating,
    calculate_capital,
    convert_currency_amount,
    prudential_rating_label,
)
from app.expositions.models import (
    Counterparty,
    ExposureCreate,
    ExposureCrmDetails,
    ExposureView,
)


def normalize_text(value: str) -> str:
    return (
        value.strip()
        .lower()
        .replace("'", " ")
        .replace("’", " ")
        .replace("-", " ")
        .replace("é", "e")
        .replace("è", "e")
        .replace("ê", "e")
        .replace("à", "a")
        .replace("â", "a")
        .replace("ô", "o")
        .replace("î", "i")
        .replace("ï", "i")
        .replace("ç", "c")
    )


SOVEREIGN_NO_SPECIAL_CASE = "Aucun de ces cas"
SOVEREIGN_LEGACY_SPECIAL_CASE = "Cas préférentiel 0 % (historique)"
SOVEREIGN_ZERO_WEIGHT_SPECIAL_CASES: tuple[str, ...] = (
    "Expositions sur États de l’UEMOA et démembrements libellées et financées en FCFA",
    "Expositions sur BCEAO libellées et financées en FCFA",
    "UEMOA",
    "CEDEAO",
    "UA",
    "UE",
    "ONU",
    "BRI",
    "FMI",
    "BCE",
    "FGD-UMOA",
)
_SOVEREIGN_ZERO_WEIGHT_SPECIAL_CASES_NORMALIZED = {
    normalize_text(item) for item in SOVEREIGN_ZERO_WEIGHT_SPECIAL_CASES
}
_SOVEREIGN_NO_SPECIAL_CASE_NORMALIZED = normalize_text(SOVEREIGN_NO_SPECIAL_CASE)
_SOVEREIGN_LEGACY_SPECIAL_CASE_NORMALIZED = normalize_text(SOVEREIGN_LEGACY_SPECIAL_CASE)


CATEGORY_OPTIONS: tuple[dict[str, str], ...] = (
    {"code": "a", "legacy": "Souverains", "prudential": "Souverains"},
    {"code": "b", "legacy": "Organismes publics", "prudential": "Organismes pub. hors Adm c"},
    {"code": "c", "legacy": "BMD", "prudential": "Expositions sur les BMD"},
    {"code": "d", "legacy": "Banques", "prudential": "Institutions financières"},
    {"code": "e", "legacy": "Entreprises", "prudential": "Entreprises"},
    {"code": "f", "legacy": "Particuliers", "prudential": "Clientèle de détail"},
    {"code": "g", "legacy": "Immobilier residentiel", "prudential": "Prêts garantis par l'immo R"},
    {"code": "h", "legacy": "Immobilier commercial", "prudential": "Prêts garantis par l'immo C"},
    {"code": "i", "legacy": "Creances en souffrance", "prudential": "Créances en souffrance"},
    {"code": "j", "legacy": "Créances à risque élevé", "prudential": "Créances à risque élevé"},
    {"code": "k", "legacy": "Autres actifs", "prudential": "Autres actifs"},
)

_SOVEREIGN_OCE_RW_BY_NOTE: dict[str, float] = {
    "0": 0.0,
    "1": 0.0,
    "2": 0.2,
    "3": 0.5,
    "4": 1.0,
    "5": 1.0,
    "6": 1.0,
    "7": 1.5,
}
PUBLIC_BODY_UEMOA_FCFA_RISK_WEIGHT = 0.2
BANK_INSTITUTION_EQUIVALENT_RULES_CASE = "equivalent_umoa_rules"
BANK_INSTITUTION_WEAK_PRUDENTIAL_CASE = "weak_prudential_case"
BANK_INSTITUTION_ELIGIBLE_CATEGORIES_CASE = "eligible_categories_case"
OTHER_ASSET_CASH_TYPE = "Encaisse"
OTHER_ASSET_CASH_EQUIVALENT_TYPE = (
    "Valeurs assimilées à l’encaisse, y compris l’or"
)
OTHER_ASSET_IMMEDIATE_COLLECTION_TYPE = (
    "Valeurs à l’encaissement avec crédit immédiat"
)
OTHER_ASSET_NON_SIGNIFICANT_PARTICIPATIONS_TYPE = (
    "Participations non significatives non déduites des fonds propres"
)
OTHER_ASSET_TANGIBLE_FIXED_ASSETS_TYPE = "Immobilisations corporelles"
# Distinguer les immobilisations hors exploitation ne change rien à leur
# pondération — 100 %, comme les corporelles — mais c'est la seule façon de
# renseigner l'EP36 du FODEP, dont la limite prudentielle ne vise qu'elles.
OTHER_ASSET_NON_OPERATING_FIXED_ASSETS_TYPE = "Immobilisations hors exploitation"
# Les incorporelles se retranchent des fonds propres de base : l'EP20 les ignore
# (NATURES_DEDUITES_DES_FONDS_PROPRES) et c'est le poste pour memoire IM011 de
# l'EP3M qui les recense. Declarer une exposition sous cette nature est le seul
# moyen de renseigner ce poste, donc l'import doit l'accepter.
OTHER_ASSET_INTANGIBLE_FIXED_ASSETS_TYPE = "Immobilisations incorporelles"
OTHER_ASSET_MISCELLANEOUS_TYPE = "Autres actifs divers"
OTHER_ASSET_EQUITY_COMMITMENTS_TYPE = "Engagements en actions non déduits"
OTHER_ASSET_NON_EQUIVALENT_FINANCIAL_COMPANIES_TYPE = (
    "Expositions sur entreprises financières non soumises à une réglementation équivalente UMOA"
)
OTHER_ASSET_UNDEFINED_TYPE = "Autres éléments d’actifs non définis"
OTHER_ASSET_SIGNIFICANT_PARTICIPATIONS_AND_DTA_TYPE = (
    "Participations significatives et impôts différés actifs non déduits"
)
OTHER_ASSET_NON_COMPLIANT_INSTITUTIONS_TYPE = (
    "Expositions sur établissements non conformes aux ratios de solvabilité"
)
OFF_BALANCE_LOW_RISK_LEVEL = "Risque faible"
OFF_BALANCE_MINOR_RISK_LEVEL = "Risque mineur"
OFF_BALANCE_MEDIUM_RISK_LEVEL = "Risque moyen"
OFF_BALANCE_HIGH_RISK_LEVEL = "Risque élevé"
OFF_BALANCE_VERY_HIGH_RISK_LEVEL = "Risque très élevé"
OTHER_ASSET_TYPE_OPTIONS: tuple[str, ...] = (
    OTHER_ASSET_CASH_TYPE,
    OTHER_ASSET_CASH_EQUIVALENT_TYPE,
    OTHER_ASSET_IMMEDIATE_COLLECTION_TYPE,
    OTHER_ASSET_NON_SIGNIFICANT_PARTICIPATIONS_TYPE,
    OTHER_ASSET_TANGIBLE_FIXED_ASSETS_TYPE,
    OTHER_ASSET_NON_OPERATING_FIXED_ASSETS_TYPE,
    # Meme rang que dans otherAssetTypeOptions du frontend : les deux listes
    # valident la meme colonne, elles doivent offrir les memes choix.
    OTHER_ASSET_INTANGIBLE_FIXED_ASSETS_TYPE,
    OTHER_ASSET_MISCELLANEOUS_TYPE,
    OTHER_ASSET_EQUITY_COMMITMENTS_TYPE,
    OTHER_ASSET_NON_EQUIVALENT_FINANCIAL_COMPANIES_TYPE,
    OTHER_ASSET_UNDEFINED_TYPE,
    OTHER_ASSET_SIGNIFICANT_PARTICIPATIONS_AND_DTA_TYPE,
    OTHER_ASSET_NON_COMPLIANT_INSTITUTIONS_TYPE,
)
OFF_BALANCE_RISK_LEVEL_OPTIONS: tuple[str, ...] = (
    OFF_BALANCE_LOW_RISK_LEVEL,
    OFF_BALANCE_MINOR_RISK_LEVEL,
    OFF_BALANCE_MEDIUM_RISK_LEVEL,
    OFF_BALANCE_HIGH_RISK_LEVEL,
    OFF_BALANCE_VERY_HIGH_RISK_LEVEL,
)


_LETTER_PREFIX_PATTERN = re.compile(r"^\([a-z]\)\s*")


def resolve_category(category: str) -> dict[str, str]:
    normalized = normalize_text(category)
    # Tolère un éventuel préfixe lettre historique ("(a) ", "(b) "...) : les
    # exports/expositions enregistrés avant le retrait des préfixes des
    # libellés de catégorie (voir CATEGORY_OPTIONS) continuent ainsi à être
    # reconnus correctement, sans nécessiter de migration des données.
    normalized_unprefixed = _LETTER_PREFIX_PATTERN.sub("", normalized)
    for option in CATEGORY_OPTIONS:
        candidates = {normalize_text(option["legacy"]), normalize_text(option["prudential"])}
        if normalized in candidates or normalized_unprefixed in candidates:
            return option
        if option["code"] == "j" and normalized == normalize_text("Risque eleve"):
            return option
    return CATEGORY_OPTIONS[4]


def lookup_sovereign_oce_risk_weight(note: str) -> float:
    return _SOVEREIGN_OCE_RW_BY_NOTE.get(str(note or "").strip(), 1.0)


def has_public_body_preferential_uemoa_case(
    public_body_uemoa_fcfa_case: bool | None,
    public_body_non_public_activity: bool | None,
) -> bool:
    return public_body_uemoa_fcfa_case is True and public_body_non_public_activity is False


def has_public_body_enterprise_override(
    public_body_uemoa_fcfa_case: bool | None,
    public_body_non_public_activity: bool | None,
) -> bool:
    return public_body_uemoa_fcfa_case is True and public_body_non_public_activity is True


def has_bmd_priority_zero_weight_case(
    bmd_high_quality_case: bool | None,
    bmd_uemoa_fcfa_case: bool | None,
    bmd_uemoa_criteria_satisfied: bool | None,
    bmd_listed_institution_fcfa_case: bool | None,
) -> bool:
    return (
        bmd_high_quality_case is True
        or (bmd_uemoa_fcfa_case is True and bmd_uemoa_criteria_satisfied is True)
        or bmd_listed_institution_fcfa_case is True
    )


def coerce_bank_institution_case(value: str | None) -> str | None:
    raw = str(value or "").strip()
    if not raw:
        return None
    normalized = normalize_text(raw)
    if normalized == normalize_text(BANK_INSTITUTION_EQUIVALENT_RULES_CASE):
        return BANK_INSTITUTION_EQUIVALENT_RULES_CASE
    if normalized == normalize_text(BANK_INSTITUTION_WEAK_PRUDENTIAL_CASE):
        return BANK_INSTITUTION_WEAK_PRUDENTIAL_CASE
    if normalized == normalize_text(BANK_INSTITUTION_ELIGIBLE_CATEGORIES_CASE):
        return BANK_INSTITUTION_ELIGIBLE_CATEGORIES_CASE
    if "equival" in normalized and "umoa" in normalized:
        return BANK_INSTITUTION_EQUIVALENT_RULES_CASE
    if (
        "degrad" in normalized
        or "solvabil" in normalized
        or "fonds propres" in normalized
    ):
        return BANK_INSTITUTION_WEAK_PRUDENTIAL_CASE
    if "categor" in normalized and "banc" in normalized:
        return BANK_INSTITUTION_ELIGIBLE_CATEGORIES_CASE
    return None


def coerce_other_asset_type(
    value: str | None, *, fallback_to_undefined: bool = False
) -> str | None:
    raw = str(value or "").strip()
    if raw:
        normalized = normalize_text(raw)
        for option in OTHER_ASSET_TYPE_OPTIONS:
            if normalized == normalize_text(option):
                return option
        if normalized == normalize_text("Autres actifs"):
            return OTHER_ASSET_UNDEFINED_TYPE
    return OTHER_ASSET_UNDEFINED_TYPE if fallback_to_undefined else None


def lookup_other_asset_risk_weight(other_asset_type: str | None) -> float:
    resolved = coerce_other_asset_type(
        other_asset_type,
        fallback_to_undefined=True,
    )
    if resolved in {
        OTHER_ASSET_CASH_TYPE,
        OTHER_ASSET_CASH_EQUIVALENT_TYPE,
    }:
        return 0.0
    if resolved == OTHER_ASSET_IMMEDIATE_COLLECTION_TYPE:
        return 0.2
    # Les incorporelles se retranchent des fonds propres de base. Les ponderer
    # en plus les compterait deux fois : une fois en moins du numerateur du
    # ratio, une fois en plus de son denominateur. L'EP20 du FODEP ne leur donne
    # aucune ligne pour cette raison — le calcul interne doit dire la meme chose
    # que l'etat transmis.
    if resolved == OTHER_ASSET_INTANGIBLE_FIXED_ASSETS_TYPE:
        return 0.0
    if resolved in {
        OTHER_ASSET_SIGNIFICANT_PARTICIPATIONS_AND_DTA_TYPE,
        OTHER_ASSET_NON_COMPLIANT_INSTITUTIONS_TYPE,
    }:
        return 2.5
    return 1.0


def lookup_country_rating_risk_weight(country_rating: str) -> float:
    bucket = bucketize_rating(country_rating)
    if bucket == "AAA/AA":
        return 0.0
    if bucket == "A":
        return 0.2
    if bucket == "BBB":
        return 0.5
    if bucket == "BB/B":
        return 1.0
    if bucket == "< B-":
        return 1.5
    return 1.0


def should_apply_unrated_counterparty_country_floor(category_code: str) -> bool:
    # Le dispositif prudentiel (§134) ne prévoit ce plancher que pour les
    # entreprises non notées : leur pondération ne peut être plus favorable
    # que celle de l'État du siège. Les autres catégories ont leur propre
    # pondération « non noté » (BMD 50 %, IF 50 %/20 %, détail 75 %,
    # immobilier 35 %/75 %...) qui ne doit pas être écrasée.
    return category_code == "e"


def apply_unrated_counterparty_country_floor(
    risk_weight: float,
    rating: str,
    *,
    category_code: str,
    country_rating: str | None = None,
) -> float:
    if not should_apply_unrated_counterparty_country_floor(category_code):
        return risk_weight
    if bucketize_rating(rating) != "Non noté":
        return risk_weight
    country_weight = lookup_country_rating_risk_weight(country_rating or "Non noté")
    return max(risk_weight, country_weight)


def infer_off_balance_risk_level_from_factor(factor: float | None) -> str | None:
    if factor is None:
        return None
    epsilon = 0.0001
    if abs(factor - 0.1) <= epsilon:
        return OFF_BALANCE_LOW_RISK_LEVEL
    if abs(factor - 0.2) <= epsilon:
        return OFF_BALANCE_MINOR_RISK_LEVEL
    if abs(factor - 0.5) <= epsilon:
        return OFF_BALANCE_MEDIUM_RISK_LEVEL
    if abs(factor - 0.75) <= epsilon:
        return OFF_BALANCE_HIGH_RISK_LEVEL
    if abs(factor - 1.0) <= epsilon:
        return OFF_BALANCE_VERY_HIGH_RISK_LEVEL
    return None


def coerce_off_balance_risk_level(
    value: str | None,
    *,
    fallback_to_very_high: bool = False,
    factor_hint: float | None = None,
) -> str | None:
    raw = str(value or "").strip()
    if raw:
        normalized = normalize_text(raw)
        for option in OFF_BALANCE_RISK_LEVEL_OPTIONS:
            if normalized == normalize_text(option):
                return option
    inferred = infer_off_balance_risk_level_from_factor(factor_hint)
    if inferred is not None:
        return inferred
    return OFF_BALANCE_VERY_HIGH_RISK_LEVEL if fallback_to_very_high else None


def lookup_off_balance_fcec(off_balance_risk_level: str | None) -> float:
    resolved = coerce_off_balance_risk_level(
        off_balance_risk_level,
        fallback_to_very_high=True,
    )
    if resolved == OFF_BALANCE_LOW_RISK_LEVEL:
        return 0.1
    if resolved == OFF_BALANCE_MINOR_RISK_LEVEL:
        return 0.2
    if resolved == OFF_BALANCE_MEDIUM_RISK_LEVEL:
        return 0.5
    if resolved == OFF_BALANCE_HIGH_RISK_LEVEL:
        return 0.75
    return 1.0


def compute_initial_maturity_months(
    grant_date: date | None, maturity_date: date | None
) -> int:
    if grant_date is None or maturity_date is None:
        return 4
    months = (maturity_date.year - grant_date.year) * 12 + (
        maturity_date.month - grant_date.month
    )
    if maturity_date.day < grant_date.day:
        months -= 1
    return max(months, 0)


def resolve_coherent_grant_date(
    grant_date: date | None,
    maturity_date: date | None,
    analysis_date: date | None = None,
) -> date | None:
    """Retourne la date d'octroi seulement si elle est cohérente.

    Une date d'octroi postérieure à l'échéance ou à la date d'analyse traduit
    une erreur de saisie ou d'import : la maturité initiale qui en découlerait
    serait fausse (et pourrait accorder à tort le traitement court terme
    préférentiel des institutions financières). Dans ce cas, l'octroi est
    ignoré : la maturité initiale devient indéterminée et le calcul retombe
    sur le traitement long terme, prudent.
    """

    if grant_date is None:
        return None
    if maturity_date is not None and grant_date > maturity_date:
        return None
    if analysis_date is not None and grant_date > analysis_date:
        return None
    return grant_date


def has_short_initial_maturity(
    grant_date: date | None, maturity_date: date | None
) -> bool:
    return compute_initial_maturity_months(grant_date, maturity_date) <= 3


def lookup_bank_institution_risk_weight(
    rating: str, *, is_short_initial_maturity: bool
) -> float:
    bucket = bucketize_rating(rating)
    if is_short_initial_maturity:
        if bucket in {"AAA/AA", "A", "BBB"}:
            return 0.2
        if bucket == "BB/B":
            return 0.5
        if bucket == "< B-":
            return 1.5
        return 0.2
    if bucket == "AAA/AA":
        return 0.2
    if bucket in {"A", "BBB"}:
        return 0.5
    if bucket == "BB/B":
        return 1.0
    if bucket == "< B-":
        return 1.5
    return 0.5


def lookup_enterprise_risk_weight(
    rating: str,
    *,
    enterprise_exceeds_bceao_degradation_threshold: bool = False,
    enterprise_prudential_procedure: bool = False,
) -> float:
    if (
        enterprise_exceeds_bceao_degradation_threshold
        or enterprise_prudential_procedure
    ):
        return 1.5
    normalized = str(rating or "").strip().upper()
    if normalized in {"AAA", "AA+", "AA", "AA-"}:
        return 0.2
    if normalized in {"A+", "A", "A-"}:
        return 0.5
    if normalized in {"BBB+", "BBB", "BBB-", "BB+", "BB", "BB-"}:
        return 1.0
    if normalized in {"< BB-", "B+", "B", "B-", "< B-"}:
        return 1.5
    return 1.0


def lookup_residential_mortgage_risk_weight(
    residential_mortgage_eligible: bool | None,
) -> float:
    return 0.35 if residential_mortgage_eligible is True else 1.0


def lookup_commercial_real_estate_risk_weight(
    commercial_real_estate_eligible: bool | None,
) -> float:
    return 0.75 if commercial_real_estate_eligible is True else 1.0


STATUT_PRUDENTIEL_SAINE = "saine"
STATUT_PRUDENTIEL_IMPAYEE = "impayee"
STATUT_PRUDENTIEL_DOUTEUSE = "douteuse"
JOURS_IMPAYES_SEUIL_SOUFFRANCE = 90


def resolve_statut_prudentiel(
    *,
    jours_impayes: int,
    declassement_manuel: bool,
    category_code: str | None = None,
) -> str:
    """Statut de vie de l'exposition : saine, impayée (< 90 j) ou douteuse."""

    # Une ligne classée d'emblée en « créances en souffrance » (catégorie i)
    # est douteuse par construction, même sans historique d'impayés saisi :
    # l'annoncer « saine » contredirait la pondération qu'elle subit déjà.
    if category_code == "i":
        return STATUT_PRUDENTIEL_DOUTEUSE
    if declassement_manuel:
        return STATUT_PRUDENTIEL_DOUTEUSE
    if jours_impayes >= JOURS_IMPAYES_SEUIL_SOUFFRANCE:
        return STATUT_PRUDENTIEL_DOUTEUSE
    if jours_impayes > 0:
        return STATUT_PRUDENTIEL_IMPAYEE
    return STATUT_PRUDENTIEL_SAINE


def resolve_defaulted_provision_threshold(payload: "ExposureCreate") -> bool | None:
    """Provisions >= 20 % de l'encours ; None quand le niveau est inconnu."""

    if payload.defaulted_exposure_provision_at_least_twenty_percent is not None:
        return payload.defaulted_exposure_provision_at_least_twenty_percent
    provisions = payload.provisions_amount
    if provisions is None:
        return None
    # Le taux de provisionnement se mesure sur l'encours effectivement porté au
    # bilan, pas sur l'engagement total : inclure la part hors bilan non tirée
    # diluerait artificiellement l'effort de provisionnement et maintiendrait
    # la ligne à 150 % alors qu'elle est couverte à plus de 20 %.
    base = float(
        payload.on_balance_exposure_amount
        if payload.on_balance_exposure_amount is not None
        else (payload.gross_amount or 0.0)
    )
    if base <= 0:
        return None
    return float(provisions) >= 0.20 * base


def lookup_defaulted_exposure_risk_weight(
    initial_risk_weight: float | None,
    *,
    is_residential_mortgage_in_default: bool | None,
    provision_at_least_twenty_percent: bool | None,
) -> float:
    resolved_initial_risk_weight = max(0.0, min(float(initial_risk_weight or 1.0), 2.5))
    if resolved_initial_risk_weight > 1.0:
        return resolved_initial_risk_weight
    if is_residential_mortgage_in_default is True:
        return 1.0
    if provision_at_least_twenty_percent is True:
        return 1.0
    # Provisions inférieures à 20 % de l'encours, ou niveau de provisionnement
    # non renseigné : le dispositif impose 150 % ; l'hypothèse prudente
    # s'applique tant que l'effort de provisionnement n'est pas démontré.
    return 1.5


def normalize_sovereign_special_case(
    value: str | None, *, fallback_to_legacy: bool = False
) -> str:
    raw = str(value or "").strip()
    if not raw:
        return (
            SOVEREIGN_LEGACY_SPECIAL_CASE
            if fallback_to_legacy
            else SOVEREIGN_NO_SPECIAL_CASE
        )
    normalized = normalize_text(raw)
    if normalized == _SOVEREIGN_LEGACY_SPECIAL_CASE_NORMALIZED:
        return SOVEREIGN_LEGACY_SPECIAL_CASE
    if normalized == _SOVEREIGN_NO_SPECIAL_CASE_NORMALIZED:
        return SOVEREIGN_NO_SPECIAL_CASE
    for item in SOVEREIGN_ZERO_WEIGHT_SPECIAL_CASES:
        if normalized == normalize_text(item):
            return item
    return (
        SOVEREIGN_LEGACY_SPECIAL_CASE
        if fallback_to_legacy
        else SOVEREIGN_NO_SPECIAL_CASE
    )


def has_sovereign_priority_zero_weight_case(
    sovereign_special_case: str | None,
    *,
    sovereign_preferential_zero_weight: bool = False,
) -> bool:
    normalized = normalize_text(str(sovereign_special_case or ""))
    return (
        normalized in _SOVEREIGN_ZERO_WEIGHT_SPECIAL_CASES_NORMALIZED
        or normalized == _SOVEREIGN_LEGACY_SPECIAL_CASE_NORMALIZED
        or sovereign_preferential_zero_weight
    )


def lookup_prudential_risk_weight(
    category_code: str,
    rating: str,
    *,
    country_rating: str | None = None,
    sovereign_special_case: str = "",
    sovereign_preferential_zero_weight: bool = False,
    sovereign_oce_established: bool = False,
    sovereign_oce_note: str = "",
    public_body_uemoa_fcfa_case: bool | None = None,
    public_body_non_public_activity: bool | None = None,
    bmd_high_quality_case: bool | None = None,
    bmd_uemoa_fcfa_case: bool | None = None,
    bmd_uemoa_criteria_satisfied: bool | None = None,
    bmd_listed_institution_fcfa_case: bool | None = None,
    bank_institution_case: str | None = None,
    other_asset_type: str | None = None,
    off_balance_risk_level: str | None = None,
    retail_eligibility_criteria_satisfied: bool | None = None,
    residential_mortgage_eligible: bool | None = None,
    commercial_real_estate_eligible: bool | None = None,
    defaulted_exposure_initial_risk_weight: float | None = None,
    defaulted_exposure_residential_mortgage_in_default: bool | None = None,
    defaulted_exposure_provision_at_least_twenty_percent: bool | None = None,
    enterprise_exceeds_bceao_degradation_threshold: bool | None = None,
    enterprise_prudential_procedure: bool | None = None,
    enterprise_investment_firm_without_banking_law: bool | None = None,
    grant_date: date | None = None,
    maturity_date: date | None = None,
) -> float:
    bucket = bucketize_rating(rating)
    def finalize(risk_weight: float) -> float:
        return apply_unrated_counterparty_country_floor(
            risk_weight,
            rating,
            category_code=category_code,
            country_rating=country_rating,
        )

    if category_code == "a" and has_sovereign_priority_zero_weight_case(
        sovereign_special_case,
        sovereign_preferential_zero_weight=sovereign_preferential_zero_weight,
    ):
        return finalize(0.0)
    if category_code == "a" and bucket == "Non noté" and sovereign_oce_established:
        return finalize(lookup_sovereign_oce_risk_weight(sovereign_oce_note))
    if category_code == "b" and has_public_body_preferential_uemoa_case(
        public_body_uemoa_fcfa_case,
        public_body_non_public_activity,
    ):
        return finalize(PUBLIC_BODY_UEMOA_FCFA_RISK_WEIGHT)
    if category_code == "b" and has_public_body_enterprise_override(
        public_body_uemoa_fcfa_case,
        public_body_non_public_activity,
    ):
        return lookup_prudential_risk_weight(
            "e",
            rating,
            country_rating=country_rating,
        )
    if category_code == "c" and has_bmd_priority_zero_weight_case(
        bmd_high_quality_case,
        bmd_uemoa_fcfa_case,
        bmd_uemoa_criteria_satisfied,
        bmd_listed_institution_fcfa_case,
    ):
        return finalize(0.0)
    if category_code == "d":
        resolved_bank_case = coerce_bank_institution_case(bank_institution_case)
        if resolved_bank_case == BANK_INSTITUTION_EQUIVALENT_RULES_CASE:
            return finalize(1.0)
        if resolved_bank_case == BANK_INSTITUTION_WEAK_PRUDENTIAL_CASE:
            return finalize(2.5)
        # Cas général (grilles T6/T7 du dispositif) : la pondération dépend de
        # la notation ET de la maturité initiale (seuil de 3 mois), y compris
        # pour les non notées (50 % à plus de 3 mois, 20 % à 3 mois ou moins).
        return finalize(lookup_bank_institution_risk_weight(
            rating,
            is_short_initial_maturity=has_short_initial_maturity(
                grant_date, maturity_date
            ),
        ))
    if category_code == "e":
        return finalize(lookup_enterprise_risk_weight(
            rating,
            enterprise_exceeds_bceao_degradation_threshold=
                enterprise_exceeds_bceao_degradation_threshold is True,
            enterprise_prudential_procedure=
                enterprise_prudential_procedure is True,
        ))
    if category_code == "f":
        if retail_eligibility_criteria_satisfied is False:
            return lookup_prudential_risk_weight(
                "e",
                rating,
                country_rating=country_rating,
                enterprise_exceeds_bceao_degradation_threshold=
                    enterprise_exceeds_bceao_degradation_threshold,
                enterprise_prudential_procedure=
                    enterprise_prudential_procedure,
                enterprise_investment_firm_without_banking_law=
                    enterprise_investment_firm_without_banking_law,
                grant_date=grant_date,
                maturity_date=maturity_date,
            )
        return finalize(0.75)
    if category_code == "k":
        return finalize(lookup_other_asset_risk_weight(other_asset_type))
    if category_code == "g":
        return finalize(
            lookup_residential_mortgage_risk_weight(
                residential_mortgage_eligible
            )
        )
    if category_code == "h":
        if commercial_real_estate_eligible is False:
            return lookup_prudential_risk_weight(
                "e",
                rating,
                country_rating=country_rating,
                enterprise_exceeds_bceao_degradation_threshold=
                    enterprise_exceeds_bceao_degradation_threshold,
                enterprise_prudential_procedure=
                    enterprise_prudential_procedure,
                enterprise_investment_firm_without_banking_law=
                    enterprise_investment_firm_without_banking_law,
                grant_date=grant_date,
                maturity_date=maturity_date,
            )
        return finalize(
            lookup_commercial_real_estate_risk_weight(
                commercial_real_estate_eligible
            )
        )
    if category_code == "i":
        return finalize(lookup_defaulted_exposure_risk_weight(
            defaulted_exposure_initial_risk_weight,
            is_residential_mortgage_in_default=
                defaulted_exposure_residential_mortgage_in_default,
            provision_at_least_twenty_percent=
                defaulted_exposure_provision_at_least_twenty_percent,
        ))
    if category_code == "j":
        return finalize(1.5)
    if category_code == "k":
        return finalize(1.0)
    lookup = {
        "a": {"AAA/AA": 0.0, "A": 0.2, "BBB": 0.5, "BB/B": 1.0, "< B-": 1.5, "Non noté": 1.0},
        "b": {"AAA/AA": 0.2, "A": 0.5, "BBB": 1.0, "BB/B": 1.0, "< B-": 1.5, "Non noté": 1.0},
        "c": {"AAA/AA": 0.2, "A": 0.5, "BBB": 0.5, "BB/B": 1.0, "< B-": 1.5, "Non noté": 0.5},
        "d": {"AAA/AA": 0.2, "A": 0.5, "BBB": 0.5, "BB/B": 1.0, "< B-": 1.5, "Non noté": 1.0},
    }
    return finalize(lookup.get(category_code, lookup["d"]).get(bucket, 1.0))


def normalize_maturity_bucket(value: str) -> str:
    normalized = normalize_text(value).replace(" ", "")
    if normalized in {"<=1an", "<=1ans"}:
        return "<=1 an"
    if normalized in {"1a3ans", "1-3ans"}:
        return "1-3 ans"
    if normalized in {"3a5ans", "3-5ans", "1a5ans", "1-5ans"}:
        return "3-5 ans"
    if normalized == "5-10ans":
        return "5-10 ans"
    if normalized in {">10ans", ">5ans"}:
        return ">10 ans"
    return value or "<=1 an"


def normalize_financed_crm_currency(currency: str) -> str:
    normalized = str(currency or "").strip().upper()
    if normalized in {"XOF", "XAF", "FCFA"}:
        return "FCFA"
    return normalized


def normalize_financed_crm_rating(rating: str) -> str:
    normalized = str(rating or "").strip().upper()
    if normalized in {"NON NOTE", "NON NOTÉ"}:
        return "NON NOTE"
    return normalized


def is_financed_crm_debt_collateral(collateral_type: str) -> bool:
    return collateral_type in {
        "Titre de dette souverain",
        "Titre non noté émis par un État de l UMOA",
        "Titre de dette émis par un autre émetteur",
        "Titre garanti par un agent agréé par la BRVM",
        "Titre bancaire non noté",
    }


def lookup_financed_crm_hfx(exposure_currency: str, collateral_currency: str) -> float:
    exposure = normalize_financed_crm_currency(exposure_currency)
    collateral = normalize_financed_crm_currency(collateral_currency)
    if exposure == collateral:
        return 0.0
    if (exposure == "FCFA" and collateral == "EUR") or (
        exposure == "EUR" and collateral == "FCFA"
    ):
        return 0.0
    # Décote réglementaire pour asymétrie de devises (approche globale) : 8 %.
    return 0.08


def _lookup_financed_crm_debt_haircut(
    *,
    collateral_type: str,
    issuer_type: str,
    rating: str,
    maturity_bucket: str,
) -> float:
    sovereign = "souverain" in normalize_text(issuer_type)
    bucket = normalize_maturity_bucket(maturity_bucket)
    normalized_rating = normalize_financed_crm_rating(rating)

    if collateral_type == "Titre non noté émis par un État de l UMOA":
        if bucket == "<=1 an":
            return 0.005 if sovereign else 0.01
        if bucket == "1-3 ans":
            return 0.02 if sovereign else 0.03
        if bucket == "3-5 ans":
            return 0.02 if sovereign else 0.04
        if bucket == "5-10 ans":
            return 0.04 if sovereign else 0.06
        return 0.04 if sovereign else 0.12

    if collateral_type in {
        "Titre garanti par un agent agréé par la BRVM",
        "Titre bancaire non noté",
    }:
        if bucket == "<=1 an":
            return 0.01 if sovereign else 0.02
        if bucket == "1-3 ans":
            return 0.03 if sovereign else 0.04
        if bucket == "3-5 ans":
            return 0.03 if sovereign else 0.06
        if bucket == "5-10 ans":
            return 0.06 if sovereign else 0.12
        return 0.06 if sovereign else 0.20

    if normalized_rating in {"AAA", "AA+", "AA", "AA-"}:
        if bucket == "<=1 an":
            return 0.005 if sovereign else 0.01
        if bucket == "1-3 ans":
            return 0.02 if sovereign else 0.03
        if bucket == "3-5 ans":
            return 0.02 if sovereign else 0.04
        if bucket == "5-10 ans":
            return 0.04 if sovereign else 0.06
        return 0.04 if sovereign else 0.12

    if normalized_rating in {"A+", "A", "A-", "BBB+", "BBB", "BBB-"}:
        if bucket == "<=1 an":
            return 0.01 if sovereign else 0.02
        if bucket == "1-3 ans":
            return 0.03 if sovereign else 0.04
        if bucket == "3-5 ans":
            return 0.03 if sovereign else 0.06
        if bucket == "5-10 ans":
            return 0.06 if sovereign else 0.12
        return 0.06 if sovereign else 0.20

    if normalized_rating in {"BB+", "BB", "BB-"} and sovereign:
        return 0.15
    return 0.0


def _evaluate_single_financed_collateral(
    *,
    exposure_currency: str,
    collateral_value: float,
    collateral_currency: str,
    collateral_type: str,
    issuer_type: str,
    rating: str,
    maturity_bucket: str,
    convertible_main_index: bool,
    opcvm_highest_haircut: float,
) -> dict[str, Any]:
    if collateral_value <= 0:
        return {
            "eligible": False,
            "reason": "Valeur de sûreté non renseignée.",
            "value": 0.0,
            "hc": 0.0,
            "hfx": 0.0,
            "cva": 0.0,
        }

    if collateral_type == "Autre sûreté non éligible":
        return {
            "eligible": False,
            "reason": "Cette sûreté n est pas reconnue par le dispositif prudentiel.",
            "value": collateral_value,
            "hc": 0.0,
            "hfx": 0.0,
            "cva": 0.0,
        }

    normalized_rating = normalize_financed_crm_rating(rating)
    eligible = True
    reason = ""
    hc = 0.0

    if collateral_type in {
        "Liquidités dans la même devise",
        "Liquidités dans une devise différente",
    }:
        hc = 0.0
    elif collateral_type in {
        "Or",
        "Action de l indice BRVM 10",
        "Action d un indice principal reconnu",
    }:
        hc = 0.20
    elif collateral_type == "Autre action cotée à la BRVM ou sur une bourse reconnue":
        hc = 0.30
    elif collateral_type == "Obligation convertible en action":
        hc = 0.20 if convertible_main_index else 0.30
    elif collateral_type == "OPCVM / FI":
        hc = max(0.0, float(opcvm_highest_haircut or 0.30))
    elif collateral_type in {
        "Titre non noté émis par un État de l UMOA",
        "Titre garanti par un agent agréé par la BRVM",
        "Titre bancaire non noté",
    }:
        hc = _lookup_financed_crm_debt_haircut(
            collateral_type=collateral_type,
            issuer_type=issuer_type,
            rating=rating,
            maturity_bucket=maturity_bucket,
        )
    elif collateral_type in {
        "Titre de dette souverain",
        "Titre de dette émis par un autre émetteur",
    }:
        if normalized_rating == "NON NOTE":
            eligible = False
            reason = "La notation de la sûreté doit être renseignée pour ce titre de dette."
        elif normalized_rating == "< B-":
            eligible = False
            reason = "Les titres en dessous de BB- ne sont pas éligibles."
        elif normalized_rating in {"BB+", "BB", "BB-"} and "souverain" not in normalize_text(issuer_type):
            eligible = False
            reason = "Un autre émetteur noté BB+ à BB- n est pas éligible à la CRM financée."
        else:
            hc = _lookup_financed_crm_debt_haircut(
                collateral_type=collateral_type,
                issuer_type=issuer_type,
                rating=rating,
                maturity_bucket=maturity_bucket,
            )
    else:
        eligible = False
        reason = "Cette sûreté n est pas éligible à la réduction réglementaire."

    collateral_value_in_exposure_currency = max(
        0.0,
        convert_currency_amount(
            collateral_value,
            from_currency=collateral_currency,
            to_currency=exposure_currency,
        ),
    )
    hfx = lookup_financed_crm_hfx(exposure_currency, collateral_currency)
    cva = (
        max(
            collateral_value_in_exposure_currency * max(0.0, 1.0 - hc - hfx),
            0.0,
        )
        if eligible
        else 0.0
    )
    return {
        "eligible": eligible,
        "reason": reason,
        "value": collateral_value_in_exposure_currency,
        "hc": hc,
        "hfx": hfx,
        "cva": cva,
    }


def compute_financed_crm_details(
    payload: ExposureCreate,
    *,
    risk_weight: float,
    crm_details: dict[str, Any],
    on_balance_exposure_amount: float,
    ead_hb_ccf_before_crm: float,
) -> dict[str, Any]:
    exposure_currency = str(crm_details.get("exposure_currency") or payload.currency or "XOF")
    collateral_value = float(crm_details.get("collateral_value", 0.0) or 0.0)
    collateral_currency = str(crm_details.get("collateral_currency") or exposure_currency)
    collateral_type = str(
        crm_details.get("collateral_type") or "Liquidités dans la même devise"
    )
    issuer_type = str(crm_details.get("issuer_type") or "autre émetteur")
    issuer_rating = str(crm_details.get("issuer_rating") or "Non noté")
    maturity_bucket = str(crm_details.get("maturity_bucket") or "<=1 an")
    convertible_main_index = bool(crm_details.get("convertible_main_index", True))
    opcvm_highest_haircut = float(
        crm_details.get("opcvm_highest_haircut", 0.30) or 0.30
    )
    basket_items = list(crm_details.get("basket_items") or [])

    # Valeur ajustée de l'exposition : VAE = E × (1 + De). La décote
    # d'exposition De est nulle pour les prêts classiques (elle ne joue que
    # pour les titres prêtés dans les opérations assimilables aux pensions).
    he = 0.0
    eva_eb = max(0.0, on_balance_exposure_amount) * (1 + he)
    eva_hb = max(0.0, ead_hb_ccf_before_crm) * (1 + he)
    eva = eva_eb + eva_hb

    if collateral_type == "Panier d actifs" and basket_items:
        total_value = 0.0
        total_cva = 0.0
        weighted_hc = 0.0
        weighted_hfx = 0.0
        ineligible_reasons: list[str] = []
        for item in basket_items:
            row = dict(item or {})
            item_value = float(row.get("value", 0.0) or 0.0)
            outcome = _evaluate_single_financed_collateral(
                exposure_currency=exposure_currency,
                collateral_value=item_value,
                collateral_currency=str(row.get("currency") or collateral_currency),
                collateral_type=str(row.get("collateral_type") or "Liquidités dans la même devise"),
                issuer_type=str(row.get("issuer_role") or "autre émetteur"),
                rating=str(row.get("rating") or "Non noté"),
                maturity_bucket=str(row.get("residual_maturity_bucket") or "<=1 an"),
                convertible_main_index=bool(row.get("convertible_main_index", True)),
                opcvm_highest_haircut=float(
                    row.get("opcvm_highest_haircut", 0.30) or 0.30
                ),
            )
            total_value += float(outcome["value"])
            total_cva += float(outcome["cva"])
            weighted_hc += float(outcome["value"]) * float(outcome["hc"])
            weighted_hfx += float(outcome["value"]) * float(outcome["hfx"])
            if not outcome["eligible"] and outcome["reason"]:
                ineligible_reasons.append(str(outcome["reason"]))
        denominator = total_value if total_value > 0 else 1.0
        eligible = total_cva > 0
        eligibility_reason = "" if eligible else (
            ineligible_reasons[0] if ineligible_reasons else "Aucun actif éligible dans le panier."
        )
        hc = weighted_hc / denominator
        hfx = weighted_hfx / denominator
        cva = total_cva if eligible else 0.0
        collateral_value = total_value
    else:
        outcome = _evaluate_single_financed_collateral(
            exposure_currency=exposure_currency,
            collateral_value=collateral_value,
            collateral_currency=collateral_currency,
            collateral_type=collateral_type,
            issuer_type=issuer_type,
            rating=issuer_rating,
            maturity_bucket=maturity_bucket,
            convertible_main_index=convertible_main_index,
            opcvm_highest_haircut=opcvm_highest_haircut,
        )
        eligible = bool(outcome["eligible"])
        eligibility_reason = str(outcome["reason"] or "")
        hc = float(outcome["hc"])
        hfx = float(outcome["hfx"])
        cva = float(outcome["cva"]) if eligible else 0.0

    if eligible:
        # E* = max(0 ; VAE − VAS) : la valeur ajustée de la sûreté est déduite
        # UNE SEULE FOIS de l'exposition totale (bilan + hors bilan), puis le
        # solde est réparti au prorata des composantes pour l'affichage.
        ead_total_after_crm = max(0.0, eva - cva)
        allocation_ratio = ead_total_after_crm / eva if eva > 0 else 0.0
        ead_bilan_amount = eva_eb * allocation_ratio
        ead_hb_ccf_amount = eva_hb * allocation_ratio
    else:
        ead_bilan_amount = max(0.0, on_balance_exposure_amount)
        ead_hb_ccf_amount = max(0.0, ead_hb_ccf_before_crm)
    ead_before_crm = max(0.0, on_balance_exposure_amount) + max(
        0.0, ead_hb_ccf_before_crm
    )
    ead_after_financed_crm = ead_bilan_amount + ead_hb_ccf_amount
    rwa_eb_amount = ead_bilan_amount * risk_weight
    rwa_hb_amount = ead_hb_ccf_amount * risk_weight
    rwa_final = rwa_eb_amount + rwa_hb_amount
    crm_gain = max(0.0, ead_before_crm - ead_after_financed_crm)
    coverage_percent = clamp_ratio(crm_gain / ead_before_crm) if ead_before_crm > 0 else 0.0

    return {
        "mode": "CRM financee",
        "label": crm_details.get("label") or payload.crm_type,
        "collateral_value": collateral_value,
        "collateral_currency": collateral_currency,
        "collateral_type": collateral_type,
        "issuer_type": issuer_type,
        "issuer_rating": issuer_rating,
        "maturity_bucket": normalize_maturity_bucket(maturity_bucket),
        "convertible_main_index": convertible_main_index,
        "opcvm_highest_haircut": opcvm_highest_haircut,
        "basket_items": basket_items,
        "fx_haircut": hfx,
        "exposure_currency": exposure_currency,
        "risk_weight": risk_weight,
        "eligible": eligible,
        "eligibility_reason": eligibility_reason,
        "he": he,
        "hc": hc,
        "hfx": hfx,
        "eva_eb": eva_eb,
        "eva_hb": eva_hb,
        "eva": eva,
        "cva": cva,
        "ead_bilan_amount": ead_bilan_amount,
        "ead_hb_ccf_amount": ead_hb_ccf_amount,
        "ead_after_financed_crm": ead_after_financed_crm,
        "rwa_eb_amount": rwa_eb_amount,
        "rwa_hb_amount": rwa_hb_amount,
        "rwa_final": rwa_final,
        "crm_gain": crm_gain,
        "coverage_percent": coverage_percent,
    }


def crm_mode_from_type(crm_type: str) -> str:
    normalized = normalize_text(crm_type)
    if not normalized or normalized in {"aucune", "sans crm"}:
        return "Aucune"
    if "non financ" in normalized or "garantie" in normalized or "assurance" in normalized:
        return "CRM non financee"
    if "cash" in normalized or "collateral" in normalized or "financee" in normalized:
        return "CRM financee"
    return "CRM non financee"


def normalize_exposure_category_label(category: str) -> str:
    return resolve_category(category)["prudential"]


def normalize_exposure_rating_label(rating: str) -> str:
    """Echelon de notation tel qu'il doit apparaitre a l'ecran.

    Les tableaux de bord affichaient le bucket interne ("BB/B", "AAA/AA") :
    ce vocabulaire de code n'existe dans aucun texte prudentiel et n'a rien a
    faire sous les yeux d'un lecteur.
    """

    return prudential_rating_label(rating)


def normalize_exposure_crm_mode(crm_type: str, crm_details: Any | None = None) -> str:
    if crm_details is None:
        return crm_mode_from_type(crm_type)
    details = model_dump(crm_details)
    mode = str(details.get("mode") or "").strip()
    return mode or crm_mode_from_type(crm_type)


def model_dump(model: Any) -> dict[str, Any]:
    if hasattr(model, "model_dump"):
        return dict(model.model_dump())
    if hasattr(model, "dict"):
        return dict(model.dict())
    return dict(model)


def clamp_ratio(value: float) -> float:
    return max(0.0, min(value, 1.0))


def resolve_exposure_components(
    payload: ExposureCreate,
    *,
    category_code: str,
) -> dict[str, float | str | None]:
    gross_amount = float(payload.gross_amount or 0.0)
    loan_total_amount = (
        float(payload.loan_total_amount)
        if payload.loan_total_amount is not None
        else gross_amount
    )
    on_balance_exposure_amount = (
        float(payload.on_balance_exposure_amount)
        if payload.on_balance_exposure_amount is not None
        else gross_amount
    )
    # Encours bilan d'origine : base immuable du suivi des remboursements. Les
    # lignes antérieures au suivi n'en ont pas ; il est alors initialisé à
    # l'encours bilan courant (aucun versement encore enregistré).
    initial_on_balance_amount = max(
        float(
            payload.initial_on_balance_amount
            if payload.initial_on_balance_amount is not None
            else on_balance_exposure_amount
        ),
        on_balance_exposure_amount,
    )
    off_balance_exposure_amount = (
        float(payload.off_balance_exposure_amount)
        if payload.off_balance_exposure_amount is not None
        else max(loan_total_amount - on_balance_exposure_amount, 0.0)
    )
    resolved_off_balance_risk_level = coerce_off_balance_risk_level(
        payload.off_balance_risk_level,
        fallback_to_very_high=off_balance_exposure_amount > 0,
    )
    off_balance_fcec = (
        lookup_off_balance_fcec(resolved_off_balance_risk_level)
        if off_balance_exposure_amount > 0
        else 0.0
    )
    ead_hb_ccf_before_crm = off_balance_exposure_amount * off_balance_fcec
    # Le dispositif prudentiel pondère l'exposition nette de provisions : le
    # provisionnement a déjà absorbé la perte, la pondérer une seconde fois
    # exigerait des fonds propres contre un risque déjà couvert. La notice
    # FODEP le rappelle pour les états EP09 à EP20 (« toutes les expositions
    # nettes de provisions », § 8.6.2). Le montant brut reste déclaré à part :
    # c'est lui que l'EP09 porte en « expositions brutes », en regard de la
    # colonne des provisions.
    provisions_amount = max(0.0, float(payload.provisions_amount or 0.0))
    on_balance_exposure_net_amount = max(
        0.0, on_balance_exposure_amount - provisions_amount
    )
    return {
        "loan_total_amount": loan_total_amount,
        "on_balance_exposure_amount": max(0.0, on_balance_exposure_amount),
        "on_balance_exposure_net_amount": on_balance_exposure_net_amount,
        "provisions_amount": provisions_amount,
        "initial_on_balance_amount": max(0.0, initial_on_balance_amount),
        "off_balance_exposure_amount": max(0.0, off_balance_exposure_amount),
        "resolved_off_balance_risk_level": resolved_off_balance_risk_level,
        "off_balance_fcec": off_balance_fcec,
        "ead_hb_ccf_before_crm": max(0.0, ead_hb_ccf_before_crm),
    }


def crm_details_payload(payload: ExposureCreate) -> dict[str, Any]:
    crm_details = model_dump(payload.crm_details)
    crm_mode = crm_details.get("mode") or crm_mode_from_type(payload.crm_type)
    crm_details["mode"] = crm_mode
    crm_details["label"] = crm_details.get("label") or payload.crm_type
    crm_details["maturity_bucket"] = normalize_maturity_bucket(str(crm_details.get("maturity_bucket") or "<=1 an"))
    crm_details["coverage_percent"] = clamp_ratio(
        float(crm_details.get("coverage_percent", payload.crm_coverage_percent or 0.0))
    )
    crm_details["collateral_currency"] = str(
        crm_details.get("collateral_currency") or payload.currency or "XOF"
    )
    crm_details["collateral_type"] = str(
        crm_details.get("collateral_type") or "Liquidités dans la même devise"
    )
    # La devise de l'exposition fait foi. Le detail CRM porte « XOF » par
    # defaut du modele : conservee sur une ligne en EUR ou en USD, elle faisait
    # convertir la surete vers le XOF alors que l'exposition restait dans sa
    # devise, si bien qu'un collateral de 173 400 EUR effacait une exposition
    # du meme ordre (EAD et RWA ramenes a zero).
    crm_details["exposure_currency"] = str(
        payload.currency or crm_details.get("exposure_currency") or "XOF"
    )
    if crm_mode == "CRM non financee":
        country_rating = str(crm_details.get("guarantor_country_rating") or "")
        crm_details["guarantor_country_rw"] = (
            lookup_prudential_risk_weight("a", country_rating)
            if country_rating
            else 0.0
        )
    return crm_details


def compute_metrics(payload: ExposureCreate, category_code: str, crm_details: dict[str, Any]) -> dict[str, float]:
    exposure_components = resolve_exposure_components(
        payload,
        category_code=category_code,
    )
    # Assiette de l'EAD : l'encours bilan net de provisions (voir
    # resolve_exposure_components). Le brut reste disponible dans les
    # composantes pour la déclaration et l'affichage.
    on_balance_exposure_amount = float(
        exposure_components["on_balance_exposure_net_amount"] or 0.0
    )
    ead_hb_ccf_before_crm = float(
        exposure_components["ead_hb_ccf_before_crm"] or 0.0
    )
    original_rw = lookup_prudential_risk_weight(
        category_code,
        payload.rating,
        country_rating=payload.country_rating,
        sovereign_special_case=payload.sovereign_special_case,
        sovereign_preferential_zero_weight=payload.sovereign_preferential_zero_weight,
        sovereign_oce_established=payload.sovereign_oce_established,
        sovereign_oce_note=payload.sovereign_oce_note,
        public_body_uemoa_fcfa_case=payload.public_body_uemoa_fcfa_case,
        public_body_non_public_activity=payload.public_body_non_public_activity,
        bmd_high_quality_case=payload.bmd_high_quality_case,
        bmd_uemoa_fcfa_case=payload.bmd_uemoa_fcfa_case,
        bmd_uemoa_criteria_satisfied=payload.bmd_uemoa_criteria_satisfied,
        bmd_listed_institution_fcfa_case=payload.bmd_listed_institution_fcfa_case,
        bank_institution_case=payload.bank_institution_case,
        other_asset_type=payload.other_asset_type,
        off_balance_risk_level=payload.off_balance_risk_level,
        retail_eligibility_criteria_satisfied=
            payload.retail_eligibility_criteria_satisfied,
        residential_mortgage_eligible=payload.residential_mortgage_eligible,
        commercial_real_estate_eligible=payload.commercial_real_estate_eligible,
        defaulted_exposure_initial_risk_weight=
            payload.defaulted_exposure_initial_risk_weight,
        defaulted_exposure_residential_mortgage_in_default=
            payload.defaulted_exposure_residential_mortgage_in_default,
        defaulted_exposure_provision_at_least_twenty_percent=
            payload.defaulted_exposure_provision_at_least_twenty_percent,
        enterprise_exceeds_bceao_degradation_threshold=
            payload.enterprise_exceeds_bceao_degradation_threshold,
        enterprise_prudential_procedure=payload.enterprise_prudential_procedure,
        enterprise_investment_firm_without_banking_law=
            payload.enterprise_investment_firm_without_banking_law,
        grant_date=resolve_coherent_grant_date(
            payload.grant_date, payload.maturity_date, payload.analysis_date
        ),
        maturity_date=payload.maturity_date,
    )
    statut_prudentiel = resolve_statut_prudentiel(
        jours_impayes=int(payload.jours_impayes or 0),
        declassement_manuel=bool(payload.declassement_manuel),
        category_code=category_code,
    )
    if statut_prudentiel == STATUT_PRUDENTIEL_DOUTEUSE and category_code != "i":
        # Exposition déclassée (>= 90 j d'impayés ou déclassement manuel) :
        # pondérée comme une créance en souffrance sans perdre sa catégorie
        # d'origine (code g = prêt garanti par l'immobilier résidentiel).
        original_rw = lookup_defaulted_exposure_risk_weight(
            original_rw,
            is_residential_mortgage_in_default=category_code == "g",
            provision_at_least_twenty_percent=
                resolve_defaulted_provision_threshold(payload),
        )
    final_rw = original_rw
    ead_bilan_amount = on_balance_exposure_amount
    ead_hb_ccf_amount = ead_hb_ccf_before_crm
    ead = ead_bilan_amount + ead_hb_ccf_amount
    rwa_eb_amount = 0.0
    rwa_hb_amount = 0.0
    effective_coverage = 0.0
    guarantor_rw = 0.0
    haircut = 0.0

    if crm_details["mode"] == "CRM financee":
        financed_details = compute_financed_crm_details(
            payload,
            risk_weight=original_rw,
            crm_details=crm_details,
            on_balance_exposure_amount=on_balance_exposure_amount,
            ead_hb_ccf_before_crm=ead_hb_ccf_before_crm,
        )
        crm_details.update(financed_details)
        effective_coverage = float(financed_details["coverage_percent"])
        haircut = float(financed_details["hc"])
        ead_bilan_amount = float(financed_details["ead_bilan_amount"])
        ead_hb_ccf_amount = float(financed_details["ead_hb_ccf_amount"])
        ead = float(financed_details["ead_after_financed_crm"])
        rwa_eb_amount = float(financed_details["rwa_eb_amount"])
        rwa_hb_amount = float(financed_details["rwa_hb_amount"])
        final_rw = original_rw
    elif crm_details["mode"] == "CRM non financee":
        effective_coverage = clamp_ratio(float(crm_details.get("coverage_percent", payload.crm_coverage_percent)))
        guarantor_category = resolve_category(str(crm_details.get("guarantor_category") or "Souverains"))
        guarantor_rating = str(crm_details.get("guarantor_rating") or payload.rating)
        guarantor_rw = lookup_prudential_risk_weight(guarantor_category["code"], guarantor_rating)
        covered_ead = ead * effective_coverage
        uncovered_ead = max(0.0, ead - covered_ead)
        rwa_apres_substitution = (uncovered_ead * original_rw) + (
            covered_ead * guarantor_rw
        )
        # Une technique d'attenuation ne peut pas rendre l'exigence plus lourde
        # que la meme exposition non garantie : la reconnaissance de la
        # protection est une faculte, aucune banque ne declare une garantie qui
        # la penalise. Quand le garant est ponderé plus lourdement que le
        # debiteur, la substitution n'est donc pas retenue — la garantie reste
        # tracee, sans effet sur le RWA.
        rwa = min(rwa_apres_substitution, ead * original_rw)
        final_rw = 0.0 if ead == 0 else max(0.0, rwa / ead)
        rwa_eb_amount = ead_bilan_amount * final_rw
        rwa_hb_amount = ead_hb_ccf_amount * final_rw
    else:
        rwa_eb_amount = ead_bilan_amount * final_rw
        rwa_hb_amount = ead_hb_ccf_amount * final_rw

    rwa = round(rwa_eb_amount + rwa_hb_amount, 2)
    capital = calculate_capital(rwa)
    return {
        "original_rw": round(original_rw, 4),
        "final_rw": round(final_rw, 4),
        "ead": round(ead, 2),
        "ead_bilan_amount": round(ead_bilan_amount, 2),
        "ead_hb_ccf_amount": round(ead_hb_ccf_amount, 2),
        "ead_total_amount": round(ead, 2),
        "rwa_eb_amount": round(rwa_eb_amount, 2),
        "rwa_hb_amount": round(rwa_hb_amount, 2),
        "rwa": rwa,
        "capital": capital,
        "effective_coverage": round(effective_coverage, 4),
        "guarantor_rw": round(guarantor_rw, 4),
        "haircut": round(haircut, 4),
    }


def build_exposure_record(payload: ExposureCreate, exposure_id: str) -> dict[str, Any]:
    category = resolve_category(payload.category)
    crm_details = crm_details_payload(payload)
    exposure_components = resolve_exposure_components(
        payload,
        category_code=category["code"],
    )
    metrics = compute_metrics(payload, category["code"], crm_details)
    crm_details["coverage_percent"] = metrics["effective_coverage"]
    crm_details["haircut"] = metrics["haircut"]
    crm_details["guarantor_risk_weight"] = metrics["guarantor_rw"]
    coherent_grant_date = resolve_coherent_grant_date(
        payload.grant_date, payload.maturity_date, payload.analysis_date
    )
    # Maturité initiale affichée uniquement quand les dates sont cohérentes :
    # un octroi postérieur à l'échéance ou à la date d'analyse produirait une
    # maturité fausse (ex. « 0 mois » avec une maturité résiduelle positive).
    exposure_maturity_months = (
        compute_initial_maturity_months(coherent_grant_date, payload.maturity_date)
        if coherent_grant_date is not None and payload.maturity_date is not None
        else None
    )
    residual_maturity_months = (
        compute_initial_maturity_months(payload.analysis_date, payload.maturity_date)
        if payload.maturity_date is not None
        else None
    )
    country_risk_weight = lookup_country_rating_risk_weight(payload.country_rating)
    source_fields = {
        "loan_total_amount": exposure_components["loan_total_amount"],
        "on_balance_exposure_amount": exposure_components["on_balance_exposure_amount"],
        "initial_on_balance_amount": exposure_components["initial_on_balance_amount"],
        "off_balance_exposure_amount": exposure_components["off_balance_exposure_amount"],
        "provisions_amount": payload.provisions_amount,
        "exposure_maturity_months": exposure_maturity_months,
        "residual_maturity_months": residual_maturity_months,
        "country_risk_weight": country_risk_weight,
        "ead_bilan_amount": metrics["ead_bilan_amount"],
        "ead_hb_amount": exposure_components["off_balance_exposure_amount"],
        "ead_hb_ccf_amount": metrics["ead_hb_ccf_amount"],
        "ead_total_amount": metrics["ead_total_amount"],
        "rwa_eb_amount": metrics["rwa_eb_amount"],
        "rwa_hb_amount": metrics["rwa_hb_amount"],
    }
    if crm_details["mode"] == "CRM financee":
        crm_details["risk_weight"] = metrics["original_rw"]
        crm_details["rwa_final"] = metrics["rwa"]
        crm_details["ead_after_financed_crm"] = metrics["ead"]
        crm_details["eva_eb"] = crm_details.get("eva_eb", 0.0)
        crm_details["eva_hb"] = crm_details.get("eva_hb", 0.0)
    return {
        "id": exposure_id,
        # Discriminant utilisé par exposure_repository._upsert_type_subtables
        # pour router la ligne vers l'une des 12 sous-tables de type
        # prudentiel (exposition_souveraine, exposition_bmd, ...). Sans ce
        # champ, le routage retombe sur category_raw (ex : "Souverains"),
        # qui ne correspond à aucun des codes lettre attendus ("a".."k") et
        # ne route donc jamais vers aucune sous-table.
        "prudential_type": category["code"],
        "analysis_date": payload.analysis_date,
        "grant_date": payload.grant_date,
        "maturity_date": payload.maturity_date,
        "counterparty_name": payload.counterparty_name,
        "country": payload.country,
        "country_rating": payload.country_rating,
        "category_raw": category["prudential"],
        "category_dashboard": category["legacy"],
        "category_standard": category["legacy"],
        "rating": payload.rating,
        "gross_amount": payload.gross_amount,
        **source_fields,
        "source_fields": source_fields,
        "currency": payload.currency or "XOF",
        "status": payload.status or "Active",
        "jours_impayes": int(payload.jours_impayes or 0),
        "statut_prudentiel": resolve_statut_prudentiel(
            jours_impayes=int(payload.jours_impayes or 0),
            declassement_manuel=bool(payload.declassement_manuel),
            category_code=category["code"],
        ),
        "declassement_manuel": bool(payload.declassement_manuel),
        "declassement_motif": payload.declassement_motif,
        "declassement_le": payload.declassement_le,
        "sovereign_special_case": normalize_sovereign_special_case(
            payload.sovereign_special_case,
            fallback_to_legacy=payload.sovereign_preferential_zero_weight,
        ),
        "sovereign_preferential_zero_weight": payload.sovereign_preferential_zero_weight,
        "sovereign_oce_established": payload.sovereign_oce_established,
        "sovereign_oce_note": payload.sovereign_oce_note or "",
        "public_body_uemoa_fcfa_case": payload.public_body_uemoa_fcfa_case,
        "public_body_non_public_activity": payload.public_body_non_public_activity,
        "bmd_high_quality_case": payload.bmd_high_quality_case,
        "bmd_uemoa_fcfa_case": payload.bmd_uemoa_fcfa_case,
        "bmd_uemoa_criteria_satisfied": payload.bmd_uemoa_criteria_satisfied,
        "bmd_listed_institution_fcfa_case": payload.bmd_listed_institution_fcfa_case,
        "bank_institution_case": coerce_bank_institution_case(
            payload.bank_institution_case
        ),
        "other_asset_type": coerce_other_asset_type(
            payload.other_asset_type,
            fallback_to_undefined=category["code"] == "k",
        ),
        "off_balance_risk_level": exposure_components["resolved_off_balance_risk_level"],
        "retail_eligibility_criteria_satisfied":
            payload.retail_eligibility_criteria_satisfied,
        "residential_mortgage_eligible": payload.residential_mortgage_eligible,
        "commercial_real_estate_eligible":
            payload.commercial_real_estate_eligible,
        "defaulted_exposure_initial_risk_weight":
            payload.defaulted_exposure_initial_risk_weight,
        "defaulted_exposure_residential_mortgage_in_default":
            payload.defaulted_exposure_residential_mortgage_in_default,
        "defaulted_exposure_provision_at_least_twenty_percent":
            payload.defaulted_exposure_provision_at_least_twenty_percent,
        "enterprise_exceeds_bceao_degradation_threshold":
            payload.enterprise_exceeds_bceao_degradation_threshold,
        "enterprise_prudential_procedure": payload.enterprise_prudential_procedure,
        "enterprise_investment_firm_without_banking_law":
            payload.enterprise_investment_firm_without_banking_law,
        "crm_exists": metrics["effective_coverage"] > 0.0 or crm_details["mode"] != "Aucune",
        "crm_type": payload.crm_type,
        "crm_mode": crm_details["mode"],
        "crm_label": crm_details["label"],
        "crm_coverage_percent": metrics["effective_coverage"],
        "crm_details": crm_details,
        "guarantor_rw": metrics["guarantor_rw"],
        "original_rw": metrics["original_rw"],
        "final_rw": metrics["final_rw"],
        "ead": metrics["ead"],
        "rwa": metrics["rwa"],
        "capital": metrics["capital"],
        "comment": payload.comment,
    }


def exposure_record_to_view(record: dict[str, Any]) -> ExposureView:
    crm_details = record.get("crm_details", {})
    category_label = (
        record.get("category_raw") or record.get("category_standard") or "Entreprises"
    )
    category = resolve_category(str(category_label))
    ead_value = float(record["ead"] or 0.0)
    rwa_value = float(record["rwa"] or 0.0)
    applied_rw = float(record.get("final_rw") or 0.0) or float(
        record.get("original_rw") or 0.0
    )
    if ead_value <= 0 and rwa_value > 0 and applied_rw > 0:
        # Données historiques importées sans colonnes EAD : reconstitution via
        # l'identité réglementaire RWA = EAD × pondération.
        ead_value = round(rwa_value / applied_rw, 2)
    counterparty = Counterparty(
        id=record["id"],
        name=record["counterparty_name"],
        country=record["country"],
        country_rating=record.get("country_rating", "Non noté"),
        category=category_label,
        rating=record["rating"],
    )
    return ExposureView(
        id=record["id"],
        analysis_date=record["analysis_date"],
        grant_date=record.get("grant_date"),
        maturity_date=record.get("maturity_date"),
        counterparty=counterparty,
        gross_amount=record["gross_amount"],
        loan_total_amount=record.get("loan_total_amount"),
        on_balance_exposure_amount=record.get("on_balance_exposure_amount"),
        off_balance_exposure_amount=record.get("off_balance_exposure_amount"),
        provisions_amount=record.get("provisions_amount"),
        jours_impayes=int(record.get("jours_impayes") or 0),
        exposure_maturity_months=record.get("exposure_maturity_months"),
        residual_maturity_months=record.get("residual_maturity_months"),
        country_risk_weight=record.get("country_risk_weight"),
        ead_bilan_amount=record.get("ead_bilan_amount"),
        ead_hb_amount=record.get("ead_hb_amount"),
        ead_hb_ccf_amount=record.get("ead_hb_ccf_amount"),
        ead_total_amount=record.get("ead_total_amount"),
        rwa_eb_amount=record.get("rwa_eb_amount"),
        rwa_hb_amount=record.get("rwa_hb_amount"),
        currency=record.get("currency", "XOF"),
        status=record.get("status", "Active"),
        statut_prudentiel=str(
            record.get("statut_prudentiel")
            or resolve_statut_prudentiel(
                jours_impayes=int(record.get("jours_impayes") or 0),
                declassement_manuel=bool(record.get("declassement_manuel")),
            )
        ),
        declassement_manuel=bool(record.get("declassement_manuel")),
        declassement_motif=record.get("declassement_motif"),
        declassement_le=record.get("declassement_le"),
        sovereign_special_case=normalize_sovereign_special_case(
            str(record.get("sovereign_special_case") or ""),
            fallback_to_legacy=bool(
                record.get("sovereign_preferential_zero_weight", False)
            ),
        ),
        sovereign_preferential_zero_weight=bool(
            record.get("sovereign_preferential_zero_weight", False)
        ),
        sovereign_oce_established=bool(record.get("sovereign_oce_established", False)),
        sovereign_oce_note=str(record.get("sovereign_oce_note") or ""),
        public_body_uemoa_fcfa_case=record.get("public_body_uemoa_fcfa_case"),
        public_body_non_public_activity=record.get("public_body_non_public_activity"),
        bmd_high_quality_case=record.get("bmd_high_quality_case"),
        bmd_uemoa_fcfa_case=record.get("bmd_uemoa_fcfa_case"),
        bmd_uemoa_criteria_satisfied=record.get("bmd_uemoa_criteria_satisfied"),
        bmd_listed_institution_fcfa_case=record.get("bmd_listed_institution_fcfa_case"),
        bank_institution_case=coerce_bank_institution_case(
            record.get("bank_institution_case")
        ),
        other_asset_type=record.get("other_asset_type"),
        off_balance_risk_level=coerce_off_balance_risk_level(
            record.get("off_balance_risk_level"),
            factor_hint=float(record.get("final_rw", 0.0) or 0.0),
        ),
        retail_eligibility_criteria_satisfied=record.get(
            "retail_eligibility_criteria_satisfied"
        ),
        residential_mortgage_eligible=record.get(
            "residential_mortgage_eligible"
        ),
        commercial_real_estate_eligible=record.get(
            "commercial_real_estate_eligible"
        ),
        defaulted_exposure_initial_risk_weight=record.get(
            "defaulted_exposure_initial_risk_weight"
        ),
        defaulted_exposure_residential_mortgage_in_default=record.get(
            "defaulted_exposure_residential_mortgage_in_default"
        ),
        defaulted_exposure_provision_at_least_twenty_percent=record.get(
            "defaulted_exposure_provision_at_least_twenty_percent"
        ),
        enterprise_exceeds_bceao_degradation_threshold=record.get(
            "enterprise_exceeds_bceao_degradation_threshold"
        ),
        enterprise_prudential_procedure=record.get(
            "enterprise_prudential_procedure"
        ),
        enterprise_investment_firm_without_banking_law=record.get(
            "enterprise_investment_firm_without_banking_law"
        ),
        crm_type=record["crm_type"],
        crm_coverage_percent=record.get("crm_coverage_percent", 0.0),
        crm_details=ExposureCrmDetails(**crm_details),
        original_rw=record["original_rw"],
        final_rw=record["final_rw"],
        ead=ead_value,
        rwa=rwa_value,
        # Recalcule au taux minimum courant (settings.capital_ratio) pour que le
        # changement de taux s'applique aussi aux expositions déjà persistées.
        capital=calculate_capital(record["rwa"]),
        comment=record.get("comment"),
    )


