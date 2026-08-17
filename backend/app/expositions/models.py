"""Modeles du module expositions."""

from datetime import date
from typing import Any

from pydantic import BaseModel, Field


class Counterparty(BaseModel):
    """Represente une contrepartie de portefeuille."""

    id: str = Field(..., description="Identifiant de la contrepartie.")
    name: str = Field(..., description="Nom de la contrepartie.")
    country: str = Field(..., description="Pays de residence.")
    country_rating: str = Field(default="Non noté", description="Notation souveraine du pays de residence.")
    category: str = Field(..., description="Categorie prudentielle.")
    rating: str = Field(..., description="Notation de la contrepartie.")


class ExposureCrmDetails(BaseModel):
    """Represente le detail de la technique de reduction du risque."""

    mode: str = Field(default="Aucune", description="Aucune, CRM financee ou CRM non financee.")
    label: str = Field(default="Aucune", description="Libelle metier de la CRM.")
    collateral_value: float = Field(default=0.0, description="Valeur du collateral avant decote.")
    collateral_currency: str = Field(default="XOF", description="Devise de la surete.")
    collateral_type: str = Field(default="Liquidités dans la même devise", description="Type de surete financee.")
    issuer_type: str = Field(default="", description="Type d'emetteur du collateral.")
    issuer_rating: str = Field(default="", description="Notation du collateral.")
    maturity_bucket: str = Field(default="<=1 an", description="Tranche de maturite du collateral.")
    convertible_main_index: bool = Field(
        default=True,
        description="Indique si l'obligation convertible est incluse dans un indice principal.",
    )
    opcvm_highest_haircut: float = Field(
        default=0.30,
        description="Plus forte decote applicable aux actifs eligibles de l'OPCVM/FI.",
    )
    basket_items: list[dict[str, Any]] = Field(
        default_factory=list,
        description="Composition du panier d'actifs lorsque la surete est un panier.",
    )
    fx_haircut: float = Field(default=0.0, description="Decote de change Hfx appliquee au collateral.")
    exposure_currency: str = Field(default="XOF", description="Devise de l'exposition brute.")
    risk_weight: float = Field(default=0.0, description="Ponderation RW deja determinee.")
    eligible: bool = Field(default=True, description="Indique si la surete est eligible.")
    eligibility_reason: str = Field(default="", description="Motif de non-eligibilite de la surete.")
    he: float = Field(default=0.0, description="Decote appliquee a l'exposition.")
    hc: float = Field(default=0.0, description="Decote appliquee a la surete.")
    hfx: float = Field(default=0.0, description="Decote de change.")
    eva: float = Field(default=0.0, description="Valeur ajustee de l'exposition.")
    cva: float = Field(default=0.0, description="Valeur ajustee de la surete.")
    ead_after_financed_crm: float = Field(
        default=0.0,
        description="Exposition nette apres CRM financee.",
    )
    rwa_final: float = Field(default=0.0, description="RWA final apres CRM financee.")
    crm_gain: float = Field(
        default=0.0,
        description="Reduction d'exposition obtenue grace a la CRM financee.",
    )
    guarantor_name: str = Field(default="", description="Nom du garant.")
    guarantor_category: str = Field(default="", description="Categorie prudentielle du garant.")
    guarantor_rating: str = Field(default="", description="Notation du garant.")
    guarantor_country: str = Field(default="", description="Pays du garant.")
    guarantor_country_rating: str = Field(default="", description="Notation souveraine du pays du garant.")
    guarantor_risk_weight: float = Field(
        default=0.0,
        description="Ponderation prudentielle substituee sur la part couverte.",
    )
    coverage_percent: float = Field(default=0.0, description="Part couverte entre 0 et 1.")


class ExposureCreate(BaseModel):
    """Represente la saisie d'une exposition au bilan."""

    id: str | None = Field(default=None, description="Identifiant optionnel de l'exposition.")
    analysis_date: date = Field(..., description="Date d'analyse.")
    grant_date: date | None = Field(default=None, description="Date d'octroi.")
    maturity_date: date | None = Field(default=None, description="Date d'echeance.")
    counterparty_name: str = Field(..., description="Nom de la contrepartie.")
    country: str = Field(..., description="Pays de la contrepartie.")
    country_rating: str = Field(default="Non noté", description="Notation souveraine du pays de residence.")
    category: str = Field(..., description="Categorie d'exposition.")
    rating: str = Field(..., description="Notation de la contrepartie.")
    gross_amount: float = Field(..., description="Montant brut de l'exposition.")
    loan_total_amount: float | None = Field(
        default=None,
        description="Montant total du prêt ou de l'exposition.",
    )
    on_balance_exposure_amount: float | None = Field(
        default=None,
        description="Montant de l'exposition au bilan.",
    )
    initial_on_balance_amount: float | None = Field(
        default=None,
        description=(
            "Encours bilan d'origine, avant amortissement par les versements. "
            "Sert de base immuable au suivi des remboursements ; par défaut "
            "égal à l'encours bilan à la création."
        ),
    )
    off_balance_exposure_amount: float | None = Field(
        default=None,
        description="Montant de l'exposition hors bilan.",
    )
    provisions_amount: float | None = Field(
        default=None,
        description="Montant exact des provisions pour la ligne.",
    )
    jours_impayes: int = Field(
        default=0,
        description="Nombre de jours d'impayés.",
    )
    currency: str = Field(default="XOF", description="Devise source de l'exposition.")
    status: str = Field(default="Active", description="Statut de gestion de l'exposition.")
    declassement_manuel: bool = Field(
        default=False,
        description="Déclassement manuel anticipé en créance douteuse (géré côté serveur).",
    )
    declassement_motif: str | None = Field(
        default=None,
        description="Motif du déclassement manuel.",
    )
    declassement_le: str | None = Field(
        default=None,
        description="Horodatage du déclassement manuel.",
    )
    sovereign_special_case: str = Field(
        default="",
        description="Type specifique d'exposition souveraine beneficant prioritairement d'une ponderation nulle.",
    )
    sovereign_preferential_zero_weight: bool = Field(
        default=False,
        description="Indique si l'exposition souveraine beneficiaire du traitement preferentiel a une ponderation nulle.",
    )
    sovereign_oce_established: bool = Field(
        default=False,
        description="Indique si le souverain non note est etabli par les OCE.",
    )
    sovereign_oce_note: str = Field(
        default="",
        description="Note OCE de 0 a 7 lorsqu'elle est applicable.",
    )
    public_body_uemoa_fcfa_case: bool | None = Field(
        default=None,
        description="Indique si l'organisme public hors administration centrale releve du cas UEMOA libelle et finance en FCFA.",
    )
    public_body_non_public_activity: bool | None = Field(
        default=None,
        description="Indique si l'organisme public finance une activite non publique lorsqu'il releve du cas UEMOA en FCFA.",
    )
    bmd_high_quality_case: bool | None = Field(
        default=None,
        description="Indique si la BMD repond au cas prioritaire avec notation elevee, soutien actionnarial fort et gestion prudente.",
    )
    bmd_uemoa_fcfa_case: bool | None = Field(
        default=None,
        description="Indique si la BMD releve du cas UEMOA libelle et finance en FCFA.",
    )
    bmd_uemoa_criteria_satisfied: bool | None = Field(
        default=None,
        description="Indique si la BMD UEMOA en FCFA respecte les criteres c), d) et e).",
    )
    bmd_listed_institution_fcfa_case: bool | None = Field(
        default=None,
        description="Indique si la BMD releve de la liste BIRD/SFI/BAsD/BAD/BERD/BEI/FEI/BNI/BDC/BIsD/BDCE/AMGI/BOAD libellee et financee en FCFA.",
    )
    bank_institution_case: str | None = Field(
        default=None,
        description="Cas prudentiel selectionne pour les institutions bancaires.",
    )
    other_asset_type: str | None = Field(
        default=None,
        description="Type d'element d'actif selectionne pour la categorie autres actifs.",
    )
    off_balance_risk_level: str | None = Field(
        default=None,
        description="Niveau de risque selectionne pour la categorie hors bilan.",
    )
    retail_eligibility_criteria_satisfied: bool | None = Field(
        default=None,
        description="Indique si l'exposition respecte les criteres de classement en clientele de detail.",
    )
    residential_mortgage_eligible: bool | None = Field(
        default=None,
        description="Indique si l'exposition respecte les conditions d'eligibilite des prets garantis par l'immobilier residentiel.",
    )
    commercial_real_estate_eligible: bool | None = Field(
        default=None,
        description="Indique si l'exposition respecte les conditions d'eligibilite de l'immobilier commercial.",
    )
    defaulted_exposure_initial_risk_weight: float | None = Field(
        default=None,
        description="Ponderation initiale de l'exposition avant défaut.",
    )
    defaulted_exposure_residential_mortgage_in_default: bool | None = Field(
        default=None,
        description="Indique si l'exposition en défaut est un prêt immobilier résidentiel.",
    )
    defaulted_exposure_provision_at_least_twenty_percent: bool | None = Field(
        default=None,
        description="Indique si le niveau de provisions atteint au moins 20 % de l'encours.",
    )
    enterprise_exceeds_bceao_degradation_threshold: bool | None = Field(
        default=None,
        description="Indique si le portefeuille entreprises depasse le seuil BCEAO de degradation sur deux trimestres consecutifs.",
    )
    enterprise_prudential_procedure: bool | None = Field(
        default=None,
        description="Indique si l'entreprise fait l'objet d'une procedure prudentielle.",
    )
    enterprise_investment_firm_without_banking_law: bool | None = Field(
        default=None,
        description="Indique s'il s'agit d'une entreprise d'investissement non soumise a la loi bancaire.",
    )
    crm_type: str = Field(default="Aucune", description="Type de CRM associe.")
    crm_coverage_percent: float = Field(default=0.0, description="Part de couverture entre 0 et 1.")
    crm_details: ExposureCrmDetails = Field(default_factory=ExposureCrmDetails)
    comment: str | None = Field(default=None, description="Commentaire de gestion.")


class ExposureView(BaseModel):
    """Represente une exposition enrichie avec les calculs RWA."""

    id: str
    analysis_date: date
    grant_date: date | None = None
    maturity_date: date | None = None
    counterparty: Counterparty
    gross_amount: float
    loan_total_amount: float | None = None
    on_balance_exposure_amount: float | None = None
    initial_on_balance_amount: float | None = None
    off_balance_exposure_amount: float | None = None
    provisions_amount: float | None = None
    jours_impayes: int = 0
    exposure_maturity_months: int | None = None
    residual_maturity_months: int | None = None
    country_risk_weight: float | None = None
    ead_bilan_amount: float | None = None
    ead_hb_amount: float | None = None
    ead_hb_ccf_amount: float | None = None
    ead_total_amount: float | None = None
    rwa_eb_amount: float | None = None
    rwa_hb_amount: float | None = None
    currency: str = "XOF"
    status: str = "Active"
    statut_prudentiel: str = "saine"
    declassement_manuel: bool = False
    declassement_motif: str | None = None
    declassement_le: str | None = None
    sovereign_special_case: str = ""
    sovereign_preferential_zero_weight: bool = False
    sovereign_oce_established: bool = False
    sovereign_oce_note: str = ""
    public_body_uemoa_fcfa_case: bool | None = None
    public_body_non_public_activity: bool | None = None
    bmd_high_quality_case: bool | None = None
    bmd_uemoa_fcfa_case: bool | None = None
    bmd_uemoa_criteria_satisfied: bool | None = None
    bmd_listed_institution_fcfa_case: bool | None = None
    bank_institution_case: str | None = None
    other_asset_type: str | None = None
    off_balance_risk_level: str | None = None
    retail_eligibility_criteria_satisfied: bool | None = None
    residential_mortgage_eligible: bool | None = None
    commercial_real_estate_eligible: bool | None = None
    defaulted_exposure_initial_risk_weight: float | None = None
    defaulted_exposure_residential_mortgage_in_default: bool | None = None
    defaulted_exposure_provision_at_least_twenty_percent: bool | None = None
    enterprise_exceeds_bceao_degradation_threshold: bool | None = None
    enterprise_prudential_procedure: bool | None = None
    enterprise_investment_firm_without_banking_law: bool | None = None
    crm_type: str
    crm_coverage_percent: float
    crm_details: ExposureCrmDetails = Field(default_factory=ExposureCrmDetails)
    actual_reimbursements: dict[str, float] = Field(default_factory=dict)
    original_rw: float
    final_rw: float
    ead: float
    rwa: float
    capital: float
    comment: str | None = None


class ExposureSummary(BaseModel):
    """Represente les agregats de portefeuille des expositions."""

    total_expositions: float
    total_ead: float
    total_rwa: float
    total_capital: float
