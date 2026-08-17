"""Modèles Pydantic du module Risque Opérationnel."""

from pydantic import BaseModel, Field


# ─── Incidents ────────────────────────────────────────────────────────────────

class IncidentCreate(BaseModel):
    date_occurrence: str = Field(..., description="JJ/MM/AAAA")
    description: str
    ligne_metier: str
    type_evenement: str
    cause_racine: str = ""
    perte_brute: float = 0.0
    perte_recuperee: float = 0.0
    statut: str = "Ouvert"


class IncidentUpdate(BaseModel):
    date_occurrence: str | None = None
    description: str | None = None
    ligne_metier: str | None = None
    type_evenement: str | None = None
    cause_racine: str | None = None
    perte_brute: float | None = None
    perte_recuperee: float | None = None
    statut: str | None = None


class IncidentView(BaseModel):
    id: str
    reference: str
    date_occurrence: str
    description: str
    ligne_metier: str
    type_evenement: str
    cause_racine: str
    perte_brute: float
    perte_recuperee: float
    perte_nette: float
    statut: str
    significatif: bool
    cree_le: str
    modifie_le: str


# ─── KRI ──────────────────────────────────────────────────────────────────────

class KriDefinition(BaseModel):
    id: str
    nom: str
    unite: str
    formule: str
    seuil_alerte: float
    seuil_critique: float
    sens: str
    frequence: str


class KriValeurCreate(BaseModel):
    kri_id: str
    date_mesure: str
    valeur: float
    commentaire: str = ""


class KriValeurView(BaseModel):
    id: str
    kri_id: str
    date_mesure: str
    valeur: float
    commentaire: str
    cree_le: str


class KriView(BaseModel):
    definition: KriDefinition
    derniere_valeur: float | None
    derniere_date: str | None
    statut: str
    historique: list[KriValeurView]


class KriModuleData(BaseModel):
    kri_list: list[KriView]
    kri_hors_seuil: int


# ─── Risques ──────────────────────────────────────────────────────────────────

class RisqueCreate(BaseModel):
    nom: str
    categorie: str
    ligne_metier: str
    probabilite: int = Field(ge=1, le=5)
    impact: int = Field(ge=1, le=5)
    controle_existant: str = ""
    efficacite_controle: int = Field(default=3, ge=1, le=5)
    plan_action_ref: str = ""


class RisqueUpdate(BaseModel):
    nom: str | None = None
    categorie: str | None = None
    ligne_metier: str | None = None
    probabilite: int | None = None
    impact: int | None = None
    controle_existant: str | None = None
    efficacite_controle: int | None = None
    plan_action_ref: str | None = None


class RisqueView(BaseModel):
    id: str
    nom: str
    categorie: str
    ligne_metier: str
    probabilite: int
    impact: int
    niveau_brut: int
    controle_existant: str
    efficacite_controle: int
    niveau_residuel: float
    niveau_label: str
    plan_action_ref: str
    cree_le: str
    modifie_le: str


# ─── Contrôles internes ───────────────────────────────────────────────────────

class ControleCreate(BaseModel):
    perimetre: str
    type_controle: str
    frequence: str
    date_dernier_test: str = ""
    resultat: str = "En cours"
    points_conformes: int = 0
    points_controles: int = 0
    non_conformites: str = ""
    validateur: str = ""


class ControleUpdate(BaseModel):
    perimetre: str | None = None
    type_controle: str | None = None
    frequence: str | None = None
    date_dernier_test: str | None = None
    resultat: str | None = None
    points_conformes: int | None = None
    points_controles: int | None = None
    non_conformites: str | None = None
    validateur: str | None = None


class ControleView(BaseModel):
    id: str
    reference: str
    perimetre: str
    type_controle: str
    frequence: str
    date_dernier_test: str
    prochaine_date: str
    resultat: str
    taux_conformite: float
    points_conformes: int
    points_controles: int
    non_conformites: str
    validateur: str
    cree_le: str
    modifie_le: str


# ─── Plans d'actions ──────────────────────────────────────────────────────────

class PlanCreate(BaseModel):
    titre: str
    description: str = ""
    type_action: str = "Corrective"
    source: str = "Incident"
    source_ref: str = ""
    responsable: str = ""
    date_debut: str = ""
    date_echeance: str = ""
    priorite: str = "Moyenne"
    statut: str = "A faire"
    avancement: int = 0


class PlanUpdate(BaseModel):
    titre: str | None = None
    description: str | None = None
    type_action: str | None = None
    source: str | None = None
    source_ref: str | None = None
    responsable: str | None = None
    date_debut: str | None = None
    date_echeance: str | None = None
    priorite: str | None = None
    statut: str | None = None
    avancement: int | None = None


class PlanView(BaseModel):
    id: str
    reference: str
    titre: str
    description: str
    type_action: str
    source: str
    source_ref: str
    responsable: str
    date_debut: str
    date_echeance: str
    jours_restants: int
    priorite: str
    statut: str
    avancement: int
    en_retard: bool
    cree_le: str
    modifie_le: str


# ─── Historique ───────────────────────────────────────────────────────────────

class IncidentImportItem(BaseModel):
    date_occurrence: str
    description: str
    ligne_metier: str
    type_evenement: str
    cause_racine: str = ""
    perte_brute: float = 0.0
    perte_recuperee: float = 0.0
    statut: str = "Ouvert"


class IncidentBulkImportRequest(BaseModel):
    incidents: list[IncidentImportItem]
    mode: str = "merge"  # "merge" | "replace"


class IncidentImportResult(BaseModel):
    imported: int
    skipped: int
    errors: list[str]


class HistoriqueView(BaseModel):
    id: int
    date_evenement: str
    utilisateur: str
    menu: str
    type_action: str
    element: str
    ancienne_valeur: str
    nouvelle_valeur: str
    commentaire: str


# ─── Dashboard ────────────────────────────────────────────────────────────────

class DashboardWidget1(BaseModel):
    exigence_fonds_propres: float
    apr_risque_op: float
    statut_reglementaire: str


class DashboardWidget2(BaseModel):
    total_incidents_mois: int
    pertes_nettes_mois: float
    incidents_non_clos: int
    evolution_pertes_pct: float | None


class DashboardWidget3(BaseModel):
    actions_en_retard: int
    controles_non_conformes: int
    kri_hors_seuil: int


class EvolutionPoint(BaseModel):
    mois: str
    perte_brute: float
    perte_nette: float


class RepartitionItem(BaseModel):
    label: str
    valeur: int


class DashboardData(BaseModel):
    widget1: DashboardWidget1
    widget2: DashboardWidget2
    widget3: DashboardWidget3
    evolution_pertes: list[EvolutionPoint]
    repartition_ligne_metier: list[RepartitionItem]
    repartition_type: list[RepartitionItem]


# ─── BIC — Approche Standard CRR3 (Art. 315-321) ─────────────────────────────

class OpRiskInput(BaseModel):
    annee: int
    interets_percus: float = 0.0
    interets_verses: float = 0.0
    revenus_leasing: float = 0.0
    dividendes_percus: float = 0.0
    autres_produits_exploitation: float = 0.0
    autres_charges_exploitation: float = 0.0
    commissions_percues: float = 0.0
    commissions_versees: float = 0.0
    resultat_portefeuille_negociation: float = 0.0
    resultat_portefeuille_bancaire: float = 0.0
    tresorerie_et_banques_centrales: float = 0.0
    creances_etablissements_credit: float = 0.0
    creances_clientele: float = 0.0
    provisions: float = 0.0
    pnb: float = 0.0


class OpRiskInputUpdate(BaseModel):
    interets_percus: float | None = None
    interets_verses: float | None = None
    revenus_leasing: float | None = None
    dividendes_percus: float | None = None
    autres_produits_exploitation: float | None = None
    autres_charges_exploitation: float | None = None
    commissions_percues: float | None = None
    commissions_versees: float | None = None
    resultat_portefeuille_negociation: float | None = None
    resultat_portefeuille_bancaire: float | None = None
    tresorerie_et_banques_centrales: float | None = None
    creances_etablissements_credit: float | None = None
    creances_clientele: float | None = None
    provisions: float | None = None
    pnb: float | None = None


class OpRiskParametres(BaseModel):
    seuil_ildc: float
    coef_tranche1: float
    coef_tranche2: float
    coef_tranche3: float
    seuil1_fcfa: float
    seuil2_fcfa: float
    multiplicateur_rea: float
    taux_conversion_eur_fcfa: float


class OpRiskParametresUpdate(BaseModel):
    seuil_ildc: float | None = None
    coef_tranche1: float | None = None
    coef_tranche2: float | None = None
    coef_tranche3: float | None = None
    seuil1_fcfa: float | None = None
    seuil2_fcfa: float | None = None
    multiplicateur_rea: float | None = None
    taux_conversion_eur_fcfa: float | None = None


class OpRiskIldcDetail(BaseModel):
    ic: float
    ac: float
    plafond_ildc: float
    plafond_actif: bool
    dividendes: float
    ildc: float


class OpRiskScDetail(BaseModel):
    oi: float
    oe: float
    fi: float
    fe: float
    sc: float


class OpRiskFcDetail(BaseModel):
    tc: float
    bc: float
    fc: float


class OpRiskBiDetail(BaseModel):
    bi: float
    tranche_active: int
    bic: float
    marge_avant_tranche_suivante: float | None


class OpRiskCalculResult(BaseModel):
    annees: list[int]
    inputs: list[OpRiskInput]
    params: OpRiskParametres
    ildc_detail: OpRiskIldcDetail
    sc_detail: OpRiskScDetail
    fc_detail: OpRiskFcDetail
    bi_detail: OpRiskBiDetail
    ofr_crr3: float
    rea_crr3: float
    ofr_bia: float
    rea_bia: float
    ecart: float
    donnees_insuffisantes: bool


# ─── BLOC A1 — AIB (Approche Indicateur de Base) ─────────────────────────────

class PnbAnnuelCreate(BaseModel):
    produit_brut_total: float
    source_document: str = ""


class PnbAnnuelView(BaseModel):
    annee: int
    produit_brut_total: float
    pnb_positif: bool
    pnb_retenu_aib: float
    source_document: str
    modifie_le: str


class ParametresAib(BaseModel):
    alpha: float
    multiplicateur_rwa: float
    ratio_solvabilite_min: float


class ParametresAibUpdate(BaseModel):
    alpha: float | None = None
    multiplicateur_rwa: float | None = None
    ratio_solvabilite_min: float | None = None


class AibCalculResult(BaseModel):
    annees_saisies: list[PnbAnnuelView]
    n: int
    somme_pnb_positifs: float
    pnb_moyen: float
    alpha: float
    k_ib: float
    apr_aib: float
    capital_min_aib: float
    donnees_insuffisantes: bool


# ─── BLOC A2 — AS (Approche Standard) ────────────────────────────────────────

class PnbParLigneCreate(BaseModel):
    produit_brut_ligne: float


class PnbParLigneView(BaseModel):
    annee: int
    ligne_metier: str
    produit_brut_ligne: float
    beta: float
    k_ligne: float


class BetaLigneView(BaseModel):
    ligne_metier: str
    beta: float
    description: str


class BetaLigneUpdate(BaseModel):
    beta: float


class ParametresAs(BaseModel):
    as_autorisee: bool
    date_autorisation: str
    reference_autorisation: str
    multiplicateur_rwa: float
    ratio_solvabilite_min: float


class ParametresAsUpdate(BaseModel):
    as_autorisee: bool | None = None
    date_autorisation: str | None = None
    reference_autorisation: str | None = None
    multiplicateur_rwa: float | None = None
    ratio_solvabilite_min: float | None = None


class AsLigneDetail(BaseModel):
    ligne_metier: str
    pnb: float
    beta: float
    k_ligne: float


class AsAnneeDetail(BaseModel):
    annee: int
    lignes: list[AsLigneDetail]
    k_total: float
    k_retenu: float
    # False quand aucun PNB par ligne n'a été saisi pour cet exercice :
    # l'année est affichée mais exclue du calcul K_AS.
    renseignee: bool = True


class AsCalculResult(BaseModel):
    as_autorisee: bool
    detail_par_annee: list[AsAnneeDetail]
    k_as: float
    apr_as: float
    capital_min_as: float
    donnees_insuffisantes: bool


# ─── Seuils de reporting Pilier 2 ────────────────────────────────────────────

class ParametresSeuils(BaseModel):
    seuil_reporting_interne: float
    seuil_reporting_direction: float
    seuil_reporting_conseil: float


class ParametresSeuilsUpdate(BaseModel):
    seuil_reporting_interne: float | None = None
    seuil_reporting_direction: float | None = None
    seuil_reporting_conseil: float | None = None


# ─── Synthèse comparative ─────────────────────────────────────────────────────

class SyntheseLigne(BaseModel):
    methode: str
    k: float
    apr: float
    capital_min: float
    disponible: bool


class SyntheseResult(BaseModel):
    lignes: list[SyntheseLigne]
    ecart_bic_vs_aib: float | None
    ratio_couverture: float | None


# ─── Décision de pilotage — Analyse et reporting (dispositif UEMOA) ──────────

class DecisionCritere(BaseModel):
    code: str
    libelle: str
    reference_reglementaire: str
    statut: str  # "conforme" | "attention" | "critique"
    poids: int
    valeur_observee: str
    seuil_reference: str
    commentaire: str


class DecisionPilotageResult(BaseModel):
    date_analyse: str
    niveau_global: str  # "Maîtrisé" | "Sous surveillance" | "Vigilance renforcée" | "Critique"
    score_global: int
    score_max: int
    organe_reporting: str
    organe_reporting_motif: str
    criteres: list[DecisionCritere]
    recommandations: list[str]
    synthese: str
