"""Modeles du module dashboard."""

from pydantic import BaseModel, Field

class DashboardMetric(BaseModel):
    """Represente une carte de KPI du dashboard."""
    key: str = Field(..., description="Cle technique du KPI.")
    label: str = Field(..., description="Libelle metier du KPI.")
    value: float = Field(..., description="Valeur principale du KPI.")
    variation: str = Field(..., description="Variation courte affichee sur la carte.")
    trend: list[float] = Field(..., description="Serie courte pour le mini graphique.")

class DistributionEntry(BaseModel):
    """Represente une repartition simple pour un graphique."""
    label: str = Field(..., description="Libelle de la categorie.")
    amount: float = Field(..., description="Montant du bucket.")
    percentage: float = Field(..., description="Part du bucket dans le total.")

class PortfolioRow(BaseModel):
    """Represente une ligne de synthese du portefeuille."""
    id: str
    analysis_date: str
    counterparty: str
    country: str
    category: str
    rating: str
    crm_type: str
    gross_amount: float
    on_balance_exposure_amount: float = 0.0
    off_balance_exposure_amount: float = 0.0
    ead: float
    rwa: float
    capital: float
    # Detail de la technique d'attenuation, en XOF comme le reste de la ligne.
    # Sans ces champs, le detail par CRM ne peut montrer ni la surete retenue,
    # ni le garant, ni l'effet reel de la garantie sur l'exigence.
    # Echelon prudentiel deduit de la notation : il designe la ligne de grille
    # qui fixe la ponderation, il ne remplace pas la note de la contrepartie.
    rating_band: str = ""
    guarantor_rating_band: str = ""
    crm_label: str = ""
    crm_coverage_percent: float = 0.0
    collateral_type: str = ""
    collateral_value: float = 0.0
    collateral_value_after_haircut: float = 0.0
    collateral_haircut: float = 0.0
    crm_eligible: bool = True
    crm_ineligibility_reason: str = ""
    guarantor_name: str = ""
    guarantor_category: str = ""
    guarantor_rating: str = ""
    guarantor_risk_weight: float = 0.0
    original_risk_weight: float = 0.0
    final_risk_weight: float = 0.0
    rwa_before_crm: float = 0.0

class TopExposure(BaseModel):
    counterparty: str
    sector: str
    country: str
    rating: str
    exposure_amount: float
    net_exposure: float
    rwa_amount: float
    fp_ratio: float
    status: str

class DashboardProjectionPoint(BaseModel):
    """Represente un point de projection de maturite."""
    label: str
    value: float

class FondsPropresDetail(BaseModel):
    """Details des fonds propres."""
    capital_ordinaire: float = 0.0
    reserves: float = 0.0
    resultats_report: float = 0.0
    resultat_eligible: float = 0.0
    deductions_prud_cet1: float = 0.0
    # Exces des limites prudentielles franchies, retranche du CET1 ci-dessous.
    # Ce n'est pas une saisie : il se mesure sur les participations, les
    # immobilisations et les concours aux parties liees, rapportes aux fonds
    # propres de l'exercice precedent. Le porter a part de
    # `deductions_prud_cet1` evite de faire passer un calcul pour un montant
    # saisi, et permet a l'ecran de dire d'ou vient la baisse.
    deduction_limites: float = 0.0
    # Les quatre lignes de l'EP03 qui composent la deduction ci-dessus, sous
    # leur code DISPRU : PA149, IM006, IM010, PR004.
    deduction_limites_detail: dict[str, float] = {}
    # Exercice sur lequel les limites ont ete mesurees, ou None si aucun
    # exercice anterieur n'est enregistre : la deduction est alors nulle faute
    # de denominateur, ce qui n'est pas un respect constate.
    exercice_limites: int | None = None
    cet1: float = 0.0
    instruments_at1: float = 0.0
    primes_emission_at1: float = 0.0
    deductions_prud_at1: float = 0.0
    at1: float = 0.0
    tier1: float = 0.0
    dettes_subordonnees_t2: float = 0.0
    provisions_generales_t2: float = 0.0
    deductions_prud_t2: float = 0.0
    tier2: float = 0.0
    total_fp: float = 0.0
    # Exercice auquel se rattachent ces fonds propres.
    exercice: int | None = None
    # Les exercices deja saisis, du plus recent au plus ancien. Les limites des
    # EP35 a EP38 se mesurent sur les fonds propres de l'exercice PRECEDENT :
    # c'est cet historique qui fournit leur denominateur.
    historique: list["FondsPropresExercice"] = []


class FondsPropresExercice(BaseModel):
    """Un exercice de l'historique des fonds propres, poste par poste.

    Les onze postes saisis autant que les agregats : la page de detail les
    compare d'un exercice a l'autre, et un ecart de total ne se lit que si on
    voit lequel des postes a bouge.
    """

    exercice: int
    # CET1
    capital_ordinaire: float = 0.0
    reserves: float = 0.0
    resultats_report: float = 0.0
    resultat_eligible: float = 0.0
    deductions_prud_cet1: float = 0.0
    # Exces des limites prudentielles franchies, retranche du CET1. Il n'est
    # porte que sur l'exercice courant : l'assiette des limites -- les
    # participations, les immobilisations, les concours aux parties liees --
    # n'est pas conservee a la cloture des exercices anterieurs.
    deduction_limites: float = 0.0
    cet1: float = 0.0
    # AT1
    instruments_at1: float = 0.0
    primes_emission_at1: float = 0.0
    deductions_prud_at1: float = 0.0
    at1: float = 0.0
    tier1: float = 0.0
    # Tier 2
    dettes_subordonnees_t2: float = 0.0
    provisions_generales_t2: float = 0.0
    deductions_prud_t2: float = 0.0
    tier2: float = 0.0
    total_fp: float = 0.0
    modifie_le: str = ""


class FondsPropresUpdate(BaseModel):
    """Model de mise a jour manuelle des fonds propres.

    L'exercice est OBLIGATOIRE. Il a d'abord ete facultatif, l'annee en cours
    servant de defaut : un client qui ne l'envoyait pas -- une interface restee
    sur une version anterieure -- ecrasait alors silencieusement l'exercice
    courant avec les chiffres d'un autre. C'est arrive deux fois sur les fonds
    propres declares. Mieux vaut un refus franc qu'une donnee remplacee sans
    que personne ne le voie.
    """

    exercice: int = Field(..., ge=2000, le=2100)
    capital_ordinaire: float
    reserves: float
    resultats_report: float
    resultat_eligible: float
    deductions_prud_cet1: float
    instruments_at1: float
    primes_emission_at1: float
    deductions_prud_at1: float
    dettes_subordonnees_t2: float
    provisions_generales_t2: float
    deductions_prud_t2: float

class DashboardSnapshot(BaseModel):
    """Represente le contenu complet du dashboard."""
    metrics: list[DashboardMetric]
    fonds_propres: FondsPropresDetail
    valuation_date: str
    category_distribution: list[DistributionEntry]
    rwa_category_distribution: list[DistributionEntry]
    rwa_type_distribution: list[DistributionEntry]
    country_distribution: list[DistributionEntry]
    crm_distribution: list[DistributionEntry]
    rating_distribution: list[DistributionEntry]
    rwa_projection: list[DashboardProjectionPoint]
    portfolio_overview: list[PortfolioRow]
    top10_exposures: list[TopExposure]
    grands_risques: list[TopExposure]
