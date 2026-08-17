// Ce fichier decrit les donnees du module hors bilan.
/// Modèle Flutter d'un engagement hors bilan.
class OffBalanceRecord {
  const OffBalanceRecord({
    required this.id,
    required this.analysisDate,
    required this.counterpartyId,
    required this.counterpartyName,
    required this.category,
    required this.rating,
    required this.engagementType,
    required this.nominalAmount,
    required this.ccf,
    required this.ead,
    required this.riskWeight,
    required this.rwa,
    required this.capital,
    required this.comment,
  });

  final String id;
  final DateTime analysisDate;
  final String counterpartyId;
  final String counterpartyName;
  final String category;
  final String rating;
  final String engagementType;
  final double nominalAmount;
  final double ccf;
  final double ead;
  final double riskWeight;
  final double rwa;
  final double capital;
  final String comment;

  factory OffBalanceRecord.fromJson(Map<String, dynamic> json) {
    return OffBalanceRecord(
      id: json['id'] as String,
      analysisDate: DateTime.parse(json['analysis_date'] as String),
      counterpartyId: json['counterparty_id'] as String,
      counterpartyName: json['counterparty_name'] as String,
      category: json['category'] as String,
      rating: json['rating'] as String,
      engagementType: json['engagement_type'] as String,
      nominalAmount: (json['nominal_amount'] as num).toDouble(),
      ccf: (json['ccf'] as num).toDouble(),
      ead: (json['ead'] as num).toDouble(),
      riskWeight: (json['risk_weight'] as num).toDouble(),
      rwa: (json['rwa'] as num).toDouble(),
      capital: (json['capital'] as num).toDouble(),
      comment: (json['comment'] ?? '') as String,
    );
  }
}

/// Totaux agrégés du module hors bilan.
class OffBalanceSummary {
  const OffBalanceSummary({
    required this.totalEngagements,
    required this.totalEad,
    required this.totalRwa,
    required this.totalCapital,
  });

  final double totalEngagements;
  final double totalEad;
  final double totalRwa;
  final double totalCapital;

  factory OffBalanceSummary.fromJson(Map<String, dynamic> json) {
    return OffBalanceSummary(
      totalEngagements: (json['total_engagements'] as num).toDouble(),
      totalEad: (json['total_ead'] as num).toDouble(),
      totalRwa: (json['total_rwa'] as num).toDouble(),
      totalCapital: (json['total_capital'] as num).toDouble(),
    );
  }
}

/// Données complètes de l'écran hors bilan.
class OffBalanceModuleData {
  const OffBalanceModuleData({
    required this.items,
    required this.summary,
  });

  final List<OffBalanceRecord> items;
  final OffBalanceSummary summary;
}

/// Brouillon utilisé pour créer un engagement hors bilan.
class OffBalanceDraft {
  const OffBalanceDraft({
    required this.counterpartyId,
    required this.engagementType,
    required this.nominalAmount,
    required this.comment,
    required this.analysisDate,
  });

  final String counterpartyId;
  final String engagementType;
  final double nominalAmount;
  final String comment;
  final DateTime analysisDate;
}
