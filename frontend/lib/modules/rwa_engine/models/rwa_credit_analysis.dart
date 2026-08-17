// Modèle de l'analyse RWA Crédit renvoyée par le backend (/rwa-credit/analyse).
// Le frontend se contente d'afficher ces valeurs : aucun calcul métier ici.

class RwaCreditComparisonPeriod {
  const RwaCreditComparisonPeriod({
    required this.key,
    required this.label,
    required this.available,
  });

  final String key;
  final String label;
  final bool available;

  factory RwaCreditComparisonPeriod.fromJson(Map<String, dynamic> json) {
    return RwaCreditComparisonPeriod(
      key: json['key'] as String,
      label: json['label'] as String,
      available: (json['available'] ?? false) as bool,
    );
  }
}

class RwaCreditTranche {
  const RwaCreditTranche({
    required this.riskWeight,
    required this.exposure,
    required this.rwa,
  });

  final double riskWeight;
  final double exposure;
  final double rwa;

  factory RwaCreditTranche.fromJson(Map<String, dynamic> json) {
    return RwaCreditTranche(
      riskWeight: (json['risk_weight'] as num).toDouble(),
      exposure: (json['exposure'] as num).toDouble(),
      rwa: (json['rwa'] as num).toDouble(),
    );
  }
}

class RwaCreditCounterparty {
  const RwaCreditCounterparty({
    required this.name,
    required this.grossExposure,
    required this.exposure,
    required this.rwa,
    required this.capitalRequired,
    required this.share,
  });

  final String name;
  final double grossExposure; // Exposition brute agrégée (XOF).
  final double exposure; // EAD agrégée (XOF).
  final double rwa; // RWA agrégé (XOF).
  final double capitalRequired; // Capital requis = RWA × taux minimum (XOF).
  final double share; // Part du RWA de l'agent (ratio 0–1), somme à 1.

  factory RwaCreditCounterparty.fromJson(Map<String, dynamic> json) {
    return RwaCreditCounterparty(
      name: (json['name'] ?? '') as String,
      grossExposure: (json['gross_exposure'] as num? ?? 0).toDouble(),
      exposure: (json['exposure'] as num? ?? 0).toDouble(),
      rwa: (json['rwa'] as num? ?? 0).toDouble(),
      capitalRequired: (json['capital_required'] as num? ?? 0).toDouble(),
      share: (json['share'] as num? ?? 0).toDouble(),
    );
  }
}

class RwaCreditAgentRow {
  const RwaCreditAgentRow({
    required this.code,
    required this.label,
    required this.grossExposure,
    required this.ead,
    required this.exposureTotal,
    required this.rwa,
    required this.contribution,
    required this.averageWeight,
    required this.expectedWeightMin,
    required this.expectedWeightMax,
    required this.weightOutOfRange,
    required this.rwaVariation,
    required this.tranches,
    required this.counterparties,
  });

  final String code;
  final String label;
  final double grossExposure;
  final double ead;
  final double exposureTotal;
  final double rwa;
  double get capitalRequired => rwa * 0.09;
  final double contribution;
  // Champs Phase 3 tolérants au null (résilience hot reload).
  final double? averageWeight;
  final double? expectedWeightMin;
  final double? expectedWeightMax;
  final bool? weightOutOfRange;
  final RwaCreditVariation? rwaVariation;
  final List<RwaCreditTranche>? tranches;
  // Ventilation par contrepartie (déjà en XOF, share sommant à 1) : source
  // unique du dialogue « Top 5 / Voir tout » pour éviter tout recalcul frontend.
  final List<RwaCreditCounterparty> counterparties;

  factory RwaCreditAgentRow.fromJson(Map<String, dynamic> json) {
    return RwaCreditAgentRow(
      code: json['code'] as String,
      label: json['label'] as String,
      grossExposure: (json['gross_exposure'] as num).toDouble(),
      ead: (json['ead'] as num).toDouble(),
      exposureTotal: (json['exposure_total'] as num).toDouble(),
      rwa: (json['rwa'] as num).toDouble(),
      contribution: (json['contribution'] as num).toDouble(),
      averageWeight: (json['average_weight'] as num?)?.toDouble(),
      expectedWeightMin: (json['expected_weight_min'] as num?)?.toDouble(),
      expectedWeightMax: (json['expected_weight_max'] as num?)?.toDouble(),
      weightOutOfRange: json['weight_out_of_range'] as bool?,
      rwaVariation: json['rwa_variation'] == null
          ? null
          : RwaCreditVariation.fromJson(
              json['rwa_variation'] as Map<String, dynamic>),
      tranches: (json['tranches'] as List<dynamic>?)
          ?.map((item) =>
              RwaCreditTranche.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      counterparties: (json['counterparties'] as List<dynamic>? ?? const [])
          .map((item) =>
              RwaCreditCounterparty.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class RwaCreditVariation {
  const RwaCreditVariation({required this.amount, required this.percent});

  final double amount;
  final double percent;

  factory RwaCreditVariation.fromJson(Map<String, dynamic> json) {
    return RwaCreditVariation(
      amount: (json['amount'] as num).toDouble(),
      percent: (json['percent'] as num).toDouble(),
    );
  }
}

class RwaCreditTotals {
  const RwaCreditTotals({
    required this.grossExposure,
    required this.ead,
    required this.exposureTotal,
    required this.rwa,
  });

  final double grossExposure;
  final double ead;
  final double exposureTotal;
  final double rwa;
  double get capitalRequired => rwa * 0.09;

  factory RwaCreditTotals.fromJson(Map<String, dynamic> json) {
    return RwaCreditTotals(
      grossExposure: (json['gross_exposure'] as num).toDouble(),
      ead: (json['ead'] as num).toDouble(),
      exposureTotal: (json['exposure_total'] as num).toDouble(),
      rwa: (json['rwa'] as num).toDouble(),
    );
  }
}

class RwaCreditAnalysis {
  const RwaCreditAnalysis({
    required this.referenceDate,
    required this.scopeLabel,
    required this.minimumCapitalRatio,
    required this.reconciliationThreshold,
    required this.comparisonPeriods,
    required this.totals,
    required this.agents,
    required this.densityRwa,
    required this.densityTrend,
    required this.ownFunds,
    required this.ownFundsAvailable,
    required this.capitalMargin,
    required this.solvencyRatio,
    required this.rwaTotal,
    required this.exposureVariation,
    required this.rwaVariation,
  });

  final DateTime? referenceDate;
  final String scopeLabel;
  final double minimumCapitalRatio;
  final double reconciliationThreshold;
  final List<RwaCreditComparisonPeriod> comparisonPeriods;
  final RwaCreditTotals totals;
  final List<RwaCreditAgentRow> agents;
  // Champs Phase 2 tolérants au null : un objet parsé par une version
  // antérieure du modèle (hot reload) ne fait pas planter l'affichage.
  final double? densityRwa;
  final List<double>? densityTrend;
  final double? ownFunds;
  final bool? ownFundsAvailable;
  final double? capitalMargin;
  final double? solvencyRatio;
  final double? rwaTotal;
  final RwaCreditVariation? exposureVariation;
  final RwaCreditVariation? rwaVariation;

  bool get isEmpty => agents.isEmpty;

  factory RwaCreditAnalysis.fromJson(Map<String, dynamic> json) {
    RwaCreditVariation? variation(String key) {
      final raw = json[key];
      return raw == null
          ? null
          : RwaCreditVariation.fromJson(raw as Map<String, dynamic>);
    }

    return RwaCreditAnalysis(
      referenceDate: json['reference_date'] == null
          ? null
          : DateTime.parse(json['reference_date'] as String),
      scopeLabel: (json['scope_label'] ?? '') as String,
      minimumCapitalRatio: (json['minimum_capital_ratio'] as num).toDouble(),
      reconciliationThreshold:
          (json['reconciliation_threshold'] as num).toDouble(),
      comparisonPeriods: (json['comparison_periods'] as List<dynamic>? ?? const [])
          .map((item) =>
              RwaCreditComparisonPeriod.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      totals: RwaCreditTotals.fromJson(json['totals'] as Map<String, dynamic>),
      agents: (json['agents'] as List<dynamic>? ?? const [])
          .map((item) => RwaCreditAgentRow.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      densityRwa: (json['density_rwa'] as num? ?? 0).toDouble(),
      densityTrend: (json['density_trend'] as List<dynamic>? ?? const [])
          .map((item) => (item as num).toDouble())
          .toList(growable: false),
      ownFunds: (json['own_funds'] as num?)?.toDouble(),
      ownFundsAvailable: (json['own_funds_available'] ?? false) as bool,
      capitalMargin: (json['capital_margin'] as num?)?.toDouble(),
      solvencyRatio: (json['solvency_ratio'] as num?)?.toDouble(),
      rwaTotal: (json['rwa_total'] as num?)?.toDouble(),
      exposureVariation: variation('exposure_variation'),
      rwaVariation: variation('rwa_variation'),
    );
  }
}
