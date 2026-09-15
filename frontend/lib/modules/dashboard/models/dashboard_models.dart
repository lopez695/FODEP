import 'dart:math' as math;

// Ce fichier decrit les donnees affichees sur le dashboard.
/// Modèle d'une métrique affichée sur le tableau de bord.
class DashboardMetric {
  const DashboardMetric({
    required this.key,
    required this.label,
    required this.value,
    required this.variation,
    required this.trend,
  });

  final String key;
  final String label;
  final double value;
  final String variation;
  final List<double> trend;

  factory DashboardMetric.fromJson(Map<String, dynamic> json) {
    return DashboardMetric(
      key: json['key'] as String,
      label: json['label'] as String,
      value: (json['value'] as num).toDouble(),
      variation: json['variation'] as String,
      trend: (json['trend'] as List<dynamic>)
          .map((item) => (item as num).toDouble())
          .toList(),
    );
  }
}

/// Modèle d'une ligne de répartition pour un graphique.
class DistributionEntry {
  const DistributionEntry({
    required this.label,
    required this.amount,
    required this.percentage,
    this.count,
  });

  final String label;
  final double amount;
  final double percentage;
  final int? count;

  factory DistributionEntry.fromJson(Map<String, dynamic> json) {
    return DistributionEntry(
      label: json['label'] as String,
      amount: (json['amount'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
      count: (json['count'] as num?)?.toInt(),
    );
  }
}

/// Représente une ligne synthétique du portefeuille.
class PortfolioRow {
  const PortfolioRow({
    required this.id,
    this.analysisDate,
    required this.counterparty,
    required this.country,
    required this.category,
    required this.rating,
    required this.crmType,
    required this.grossAmount,
    double? onBalanceExposureAmount,
    required this.offBalanceExposureAmount,
    required this.ead,
    required this.rwa,
    required this.capital,
    this.ratingBand = '',
    this.guarantorRatingBand = '',
    this.crmLabel = '',
    this.crmCoveragePercent = 0.0,
    this.collateralType = '',
    this.collateralValue = 0.0,
    this.collateralValueAfterHaircut = 0.0,
    this.collateralHaircut = 0.0,
    this.crmEligible = true,
    this.crmIneligibilityReason = '',
    this.guarantorName = '',
    this.guarantorCategory = '',
    this.guarantorRating = '',
    this.guarantorRiskWeight = 0.0,
    this.originalRiskWeight = 0.0,
    this.finalRiskWeight = 0.0,
    double? rwaBeforeCrm,
  })  : _onBalanceExposureAmount = onBalanceExposureAmount,
        _rwaBeforeCrm = rwaBeforeCrm;

  final String id;
  final DateTime? analysisDate;
  final String counterparty;
  final String country;
  final String category;
  final String rating;
  final String crmType;
  final double grossAmount;
  final double? _onBalanceExposureAmount;
  final double offBalanceExposureAmount;
  final double ead;
  final double rwa;
  final double capital;

  /// Échelon prudentiel déduit de la notation : il désigne la ligne de grille
  /// qui fixe la pondération, il ne remplace pas la note de la contrepartie.
  final String ratingBand;
  final String guarantorRatingBand;

  /// Détail de la technique d'atténuation, en XOF comme le reste de la ligne.
  final String crmLabel;
  final double crmCoveragePercent;
  final String collateralType;
  final double collateralValue;
  final double collateralValueAfterHaircut;
  final double collateralHaircut;
  final bool crmEligible;
  final String crmIneligibilityReason;
  final String guarantorName;
  final String guarantorCategory;
  final String guarantorRating;
  final double guarantorRiskWeight;
  final double originalRiskWeight;
  final double finalRiskWeight;
  final double? _rwaBeforeCrm;

  double get onBalanceExposureAmount {
    final value = _onBalanceExposureAmount;
    if (value != null) return value;
    if (offBalanceExposureAmount > grossAmount) {
      return grossAmount;
    }
    return math.max(0.0, grossAmount - offBalanceExposureAmount);
  }

  /// RWA qu'aurait porté la ligne sans sa technique d'atténuation.
  ///
  /// Un backend plus ancien ne sert pas le champ : on retombe alors sur le RWA
  /// retenu, ce qui affiche un effet CRM nul plutôt qu'un gain inventé.
  double get rwaBeforeCrm => _rwaBeforeCrm ?? rwa;

  /// Économie de RWA obtenue par la CRM. Négative quand la garantie dégrade
  /// la pondération (garant plus lourdement pondéré que le débiteur).
  double get crmRwaSaving => rwaBeforeCrm - rwa;

  factory PortfolioRow.fromJson(Map<String, dynamic> json) {
    final grossAmount = (json['gross_amount'] as num).toDouble();
    final rawAnalysisDate = json['analysis_date'] as String?;
    final offBalanceExposureAmount =
        (json['off_balance_exposure_amount'] as num?)?.toDouble() ?? 0.0;
    final onBalanceExposureAmount =
        (json['on_balance_exposure_amount'] as num?)?.toDouble();

    return PortfolioRow(
      id: json['id'] as String,
      analysisDate: rawAnalysisDate == null || rawAnalysisDate.isEmpty
          ? null
          : DateTime.tryParse(rawAnalysisDate),
      counterparty: json['counterparty'] as String,
      country: (json['country'] ?? '') as String,
      category: json['category'] as String,
      rating: json['rating'] as String,
      crmType: (json['crm_type'] ?? 'Aucune') as String,
      grossAmount: grossAmount,
      onBalanceExposureAmount: onBalanceExposureAmount,
      offBalanceExposureAmount: offBalanceExposureAmount,
      ead: (json['ead'] as num).toDouble(),
      rwa: (json['rwa'] as num).toDouble(),
      capital: (json['capital'] as num).toDouble(),
      ratingBand: (json['rating_band'] ?? '') as String,
      guarantorRatingBand: (json['guarantor_rating_band'] ?? '') as String,
      crmLabel: (json['crm_label'] ?? '') as String,
      crmCoveragePercent:
          (json['crm_coverage_percent'] as num?)?.toDouble() ?? 0.0,
      collateralType: (json['collateral_type'] ?? '') as String,
      collateralValue: (json['collateral_value'] as num?)?.toDouble() ?? 0.0,
      collateralValueAfterHaircut:
          (json['collateral_value_after_haircut'] as num?)?.toDouble() ?? 0.0,
      collateralHaircut:
          (json['collateral_haircut'] as num?)?.toDouble() ?? 0.0,
      crmEligible: (json['crm_eligible'] as bool?) ?? true,
      crmIneligibilityReason: (json['crm_ineligibility_reason'] ?? '') as String,
      guarantorName: (json['guarantor_name'] ?? '') as String,
      guarantorCategory: (json['guarantor_category'] ?? '') as String,
      guarantorRating: (json['guarantor_rating'] ?? '') as String,
      guarantorRiskWeight:
          (json['guarantor_risk_weight'] as num?)?.toDouble() ?? 0.0,
      originalRiskWeight:
          (json['original_risk_weight'] as num?)?.toDouble() ?? 0.0,
      finalRiskWeight: (json['final_risk_weight'] as num?)?.toDouble() ?? 0.0,
      rwaBeforeCrm: (json['rwa_before_crm'] as num?)?.toDouble(),
    );
  }
}

/// Point de projection utilisé dans l'échéancier des RWA.
class DashboardProjectionPoint {
  const DashboardProjectionPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;

  factory DashboardProjectionPoint.fromJson(Map<String, dynamic> json) {
    return DashboardProjectionPoint(
      label: json['label'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }
}

/// Un exercice de l'historique des fonds propres, poste par poste.
///
/// Les onze postes saisis autant que les agrégats : la page de détail les
/// compare d'un exercice à l'autre, et un écart de total ne se lit que si on
/// voit lequel des postes a bougé.
class FondsPropresExercice {
  const FondsPropresExercice({
    required this.exercice,
    this.capitalOrdinaire = 0.0,
    this.reserves = 0.0,
    this.resultatsReport = 0.0,
    this.resultatEligible = 0.0,
    this.deductionsPrudCet1 = 0.0,
    this.deductionLimites = 0.0,
    required this.cet1,
    this.instrumentsAt1 = 0.0,
    this.primesEmissionAt1 = 0.0,
    this.deductionsPrudAt1 = 0.0,
    this.at1 = 0.0,
    required this.tier1,
    this.dettesSubordonneesT2 = 0.0,
    this.provisionsGeneralesT2 = 0.0,
    this.deductionsPrudT2 = 0.0,
    this.tier2 = 0.0,
    required this.totalFp,
    this.modifieLe = '',
  });

  final int exercice;
  final double capitalOrdinaire;
  final double reserves;
  final double resultatsReport;
  final double resultatEligible;
  final double deductionsPrudCet1;

  /// Excédent des limites prudentielles franchies, déjà retranché du [cet1].
  ///
  /// Il n'est porté que sur l'exercice courant : l'assiette des limites — les
  /// participations, les immobilisations, les concours aux parties liées —
  /// n'est pas conservée à la clôture des exercices antérieurs.
  final double deductionLimites;

  final double cet1;
  final double instrumentsAt1;
  final double primesEmissionAt1;
  final double deductionsPrudAt1;
  final double at1;
  final double tier1;
  final double dettesSubordonneesT2;
  final double provisionsGeneralesT2;
  final double deductionsPrudT2;
  final double tier2;
  final double totalFp;
  final String modifieLe;

  static double _d(Object? v) => (v as num?)?.toDouble() ?? 0.0;

  factory FondsPropresExercice.fromJson(Map<String, dynamic> json) =>
      FondsPropresExercice(
        exercice: (json['exercice'] as num).toInt(),
        capitalOrdinaire: _d(json['capital_ordinaire']),
        reserves: _d(json['reserves']),
        resultatsReport: _d(json['resultats_report']),
        resultatEligible: _d(json['resultat_eligible']),
        deductionsPrudCet1: _d(json['deductions_prud_cet1']),
        deductionLimites: _d(json['deduction_limites']),
        cet1: _d(json['cet1']),
        instrumentsAt1: _d(json['instruments_at1']),
        primesEmissionAt1: _d(json['primes_emission_at1']),
        deductionsPrudAt1: _d(json['deductions_prud_at1']),
        at1: _d(json['at1']),
        tier1: _d(json['tier1']),
        dettesSubordonneesT2: _d(json['dettes_subordonnees_t2']),
        provisionsGeneralesT2: _d(json['provisions_generales_t2']),
        deductionsPrudT2: _d(json['deductions_prud_t2']),
        tier2: _d(json['tier2']),
        totalFp: _d(json['total_fp']),
        modifieLe: json['modifie_le'] as String? ?? '',
      );

  /// Reprend les fonds propres courants sous la forme d'un exercice.
  ///
  /// Un serveur antérieur à l'historique ne renvoie pas le relevé : la page de
  /// détail retombe alors sur le seul millésime qu'il sait tenir, plutôt que
  /// de s'ouvrir vide.
  factory FondsPropresExercice.depuisDetail(FondsPropresDetail fp) =>
      FondsPropresExercice(
        exercice: fp.exercice ?? DateTime.now().year,
        capitalOrdinaire: fp.capitalOrdinaire,
        reserves: fp.reserves,
        resultatsReport: fp.resultatsReport,
        resultatEligible: fp.resultatEligible,
        deductionsPrudCet1: fp.deductionsPrudCet1,
        deductionLimites: fp.deductionLimites,
        cet1: fp.cet1,
        instrumentsAt1: fp.instrumentsAt1,
        primesEmissionAt1: fp.primesEmissionAt1,
        deductionsPrudAt1: fp.deductionsPrudAt1,
        at1: fp.at1,
        tier1: fp.tier1,
        dettesSubordonneesT2: fp.dettesSubordonneesT2,
        provisionsGeneralesT2: fp.provisionsGeneralesT2,
        deductionsPrudT2: fp.deductionsPrudT2,
        tier2: fp.tier2,
        totalFp: fp.totalFp,
      );
}

class FondsPropresDetail {
  const FondsPropresDetail({
    required this.capitalOrdinaire,
    required this.reserves,
    required this.resultatsReport,
    required this.resultatEligible,
    required this.deductionsPrudCet1,
    this.deductionLimites = 0.0,
    this.deductionLimitesDetail = const {},
    this.exerciceLimites,
    required this.cet1,
    required this.instrumentsAt1,
    required this.primesEmissionAt1,
    required this.deductionsPrudAt1,
    required this.at1,
    required this.tier1,
    required this.dettesSubordonneesT2,
    required this.provisionsGeneralesT2,
    required this.deductionsPrudT2,
    required this.tier2,
    required this.totalFp,
    this.exercice,
    this.historique = const [],
  });

  final double capitalOrdinaire;
  final double reserves;
  final double resultatsReport;
  final double resultatEligible;
  final double deductionsPrudCet1;

  /// Excédent des limites prudentielles franchies, déjà retranché du [cet1].
  ///
  /// Ce n'est pas une saisie : il se mesure sur les participations, les
  /// immobilisations et les concours aux parties liées, rapportés aux fonds
  /// propres de l'exercice précédent. L'écran le porte sur sa propre ligne,
  /// faute de quoi le CET1 semblerait ne pas boucler avec les postes saisis.
  final double deductionLimites;

  /// Les quatre lignes de l'EP03 qui composent [deductionLimites], sous leur
  /// code DISPRU : PA149, IM006, IM010, PR004.
  final Map<String, double> deductionLimitesDetail;

  /// Exercice sur lequel les limites ont été mesurées, ou `null` si aucun
  /// exercice antérieur n'est enregistré — la déduction est alors nulle faute
  /// de dénominateur, ce qui n'est pas un respect constaté.
  final int? exerciceLimites;

  final double cet1;
  final double instrumentsAt1;
  final double primesEmissionAt1;
  final double deductionsPrudAt1;
  final double at1;
  final double tier1;
  final double dettesSubordonneesT2;
  final double provisionsGeneralesT2;
  final double deductionsPrudT2;
  final double tier2;
  final double totalFp;

  /// Exercice auquel se rattachent ces fonds propres.
  final int? exercice;

  /// Les exercices déjà saisis, du plus récent au plus ancien.
  ///
  /// Les limites des EP35 à EP38 se mesurent sur les fonds propres de
  /// l'exercice PRÉCÉDENT : c'est cet historique qui leur fournit leur
  /// dénominateur, et donc le montant de [deductionLimites].
  final List<FondsPropresExercice> historique;

  factory FondsPropresDetail.fromJson(Map<String, dynamic> json) {
    return FondsPropresDetail(
      capitalOrdinaire: (json['capital_ordinaire'] as num?)?.toDouble() ?? 0.0,
      reserves: (json['reserves'] as num?)?.toDouble() ?? 0.0,
      resultatsReport: (json['resultats_report'] as num?)?.toDouble() ?? 0.0,
      resultatEligible: (json['resultat_eligible'] as num?)?.toDouble() ?? 0.0,
      deductionsPrudCet1: (json['deductions_prud_cet1'] as num?)?.toDouble() ?? 0.0,
      deductionLimites: (json['deduction_limites'] as num?)?.toDouble() ?? 0.0,
      deductionLimitesDetail:
          ((json['deduction_limites_detail'] as Map<dynamic, dynamic>?) ??
                  const {})
              .map((cle, valeur) => MapEntry(
                    cle.toString(),
                    (valeur as num?)?.toDouble() ?? 0.0,
                  )),
      exerciceLimites: (json['exercice_limites'] as num?)?.toInt(),
      exercice: (json['exercice'] as num?)?.toInt(),
      historique: ((json['historique'] as List<dynamic>?) ?? const [])
          .map((e) => FondsPropresExercice.fromJson(e as Map<String, dynamic>))
          .toList(),
      cet1: (json['cet1'] as num?)?.toDouble() ?? 0.0,
      instrumentsAt1: (json['instruments_at1'] as num?)?.toDouble() ?? 0.0,
      primesEmissionAt1: (json['primes_emission_at1'] as num?)?.toDouble() ?? 0.0,
      deductionsPrudAt1: (json['deductions_prud_at1'] as num?)?.toDouble() ?? 0.0,
      at1: (json['at1'] as num?)?.toDouble() ?? 0.0,
      tier1: (json['tier1'] as num?)?.toDouble() ?? 0.0,
      dettesSubordonneesT2: (json['dettes_subordonnees_t2'] as num?)?.toDouble() ?? 0.0,
      provisionsGeneralesT2: (json['provisions_generales_t2'] as num?)?.toDouble() ?? 0.0,
      deductionsPrudT2: (json['deductions_prud_t2'] as num?)?.toDouble() ?? 0.0,
      tier2: (json['tier2'] as num?)?.toDouble() ?? 0.0,
      totalFp: (json['total_fp'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FondsPropresUpdate {
  const FondsPropresUpdate({
    required this.exercice,
    required this.capitalOrdinaire,
    required this.reserves,
    required this.resultatsReport,
    required this.resultatEligible,
    required this.deductionsPrudCet1,
    required this.instrumentsAt1,
    required this.primesEmissionAt1,
    required this.deductionsPrudAt1,
    required this.dettesSubordonneesT2,
    required this.provisionsGeneralesT2,
    required this.deductionsPrudT2,
  });

  /// Exercice visé par la saisie. Obligatoire : le serveur refuse une mise à
  /// jour sans lui, plutôt que d'écraser l'exercice courant avec les chiffres
  /// d'un autre.
  final int exercice;
  final double capitalOrdinaire;
  final double reserves;
  final double resultatsReport;
  final double resultatEligible;
  final double deductionsPrudCet1;
  final double instrumentsAt1;
  final double primesEmissionAt1;
  final double deductionsPrudAt1;
  final double dettesSubordonneesT2;
  final double provisionsGeneralesT2;
  final double deductionsPrudT2;

  Map<String, dynamic> toJson() {
    return {
      'exercice': exercice,
      'capital_ordinaire': capitalOrdinaire,
      'reserves': reserves,
      'resultats_report': resultatsReport,
      'resultat_eligible': resultatEligible,
      'deductions_prud_cet1': deductionsPrudCet1,
      'instruments_at1': instrumentsAt1,
      'primes_emission_at1': primesEmissionAt1,
      'deductions_prud_at1': deductionsPrudAt1,
      'dettes_subordonnees_t2': dettesSubordonneesT2,
      'provisions_generales_t2': provisionsGeneralesT2,
      'deductions_prud_t2': deductionsPrudT2,
    };
  }
}

/// Modèle pour une ligne du Top 10 des grands risques (expositions).
class TopExposure {
  const TopExposure({
    required this.counterparty,
    required this.sector,
    required this.country,
    required this.rating,
    required this.exposureAmount,
    required this.netExposure,
    required this.rwaAmount,
    required this.fpRatio,
    required this.status,
  });

  final String counterparty;
  final String sector;
  final String country;
  final String rating;
  final double exposureAmount;
  final double netExposure;
  final double rwaAmount;
  final double fpRatio;
  final String status;

  factory TopExposure.fromJson(Map<String, dynamic> json) {
    return TopExposure(
      counterparty: json['counterparty'] as String? ?? '',
      sector: json['sector'] as String? ?? '',
      country: json['country'] as String? ?? 'Non spécifié',
      rating: json['rating'] as String? ?? '',
      exposureAmount: (json['exposure_amount'] as num?)?.toDouble() ?? 0.0,
      netExposure: (json['net_exposure'] as num?)?.toDouble() ?? 0.0,
      rwaAmount: (json['rwa_amount'] as num?)?.toDouble() ?? 0.0,
      fpRatio: (json['fp_ratio'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'Conforme',
    );
  }
}

/// Agrège toutes les données nécessaires au dashboard.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.metrics,
    this.fondsPropres,
    required this.valuationDate,
    required this.categoryDistribution,
    required this.rwaTypeDistribution,
    required this.rwaCategoryDistribution,
    required this.countryDistribution,
    required this.crmDistribution,
    required this.ratingDistribution,
    required this.rwaProjection,
    required this.portfolioOverview,
    this.top10Exposures = const [],
    this.grandsRisques = const [],
  });

  final List<DashboardMetric> metrics;
  final FondsPropresDetail? fondsPropres;
  final DateTime valuationDate;
  final List<DistributionEntry> categoryDistribution;
  final List<DistributionEntry> rwaTypeDistribution;
  final List<DistributionEntry> rwaCategoryDistribution;
  final List<DistributionEntry> countryDistribution;
  final List<DistributionEntry> crmDistribution;
  final List<DistributionEntry> ratingDistribution;
  final List<DashboardProjectionPoint> rwaProjection;
  final List<PortfolioRow> portfolioOverview;
  final List<TopExposure>? top10Exposures;
  final List<TopExposure> grandsRisques;

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    return DashboardSnapshot(
      metrics: (json['metrics'] as List<dynamic>)
          .map((item) => DashboardMetric.fromJson(item as Map<String, dynamic>))
          .toList(),
      fondsPropres: json['fonds_propres'] != null 
          ? FondsPropresDetail.fromJson(json['fonds_propres'] as Map<String, dynamic>)
          : null,
      valuationDate: json['valuation_date'] == null
          ? DateTime.now()
          : DateTime.parse(json['valuation_date'] as String),
      categoryDistribution: (json['category_distribution'] as List<dynamic>)
          .map((item) =>
              DistributionEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      rwaTypeDistribution: (json['rwa_type_distribution'] as List<dynamic>? ?? const [])
          .map((item) =>
              DistributionEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      rwaCategoryDistribution: (json['rwa_category_distribution']
                  as List<dynamic>? ??
              json['category_distribution'] as List<dynamic>? ??
              const [])
          .map(
            (item) => DistributionEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      countryDistribution:
          (json['country_distribution'] as List<dynamic>? ?? const [])
              .map((item) =>
                  DistributionEntry.fromJson(item as Map<String, dynamic>))
              .toList(),
      crmDistribution: (json['crm_distribution'] as List<dynamic>? ?? const [])
          .map((item) =>
              DistributionEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      ratingDistribution: (json['rating_distribution'] as List<dynamic>)
          .map((item) =>
              DistributionEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      rwaProjection: (json['rwa_projection'] as List<dynamic>? ?? const [])
          .map((item) =>
              DashboardProjectionPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      portfolioOverview: (json['portfolio_overview'] as List<dynamic>)
          .map((item) => PortfolioRow.fromJson(item as Map<String, dynamic>))
          .toList(),
      top10Exposures: json['top10_exposures'] != null
          ? (json['top10_exposures'] as List<dynamic>)
              .map((item) => TopExposure.fromJson(item as Map<String, dynamic>))
              .toList()
          : <TopExposure>[],
      grandsRisques: json['grands_risques'] != null
          ? (json['grands_risques'] as List<dynamic>)
              .map((item) => TopExposure.fromJson(item as Map<String, dynamic>))
              .toList()
          : <TopExposure>[],
    );
  }
}
