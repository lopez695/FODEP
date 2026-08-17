// Ce fichier decrit les donnees du module referentiels.
/// Ligne de référentiel pour les pondérations de risque.
class RiskWeightRow {
  const RiskWeightRow({
    required this.id,
    required this.segment,
    required this.rating,
    required this.riskWeight,
    required this.approach,
  });

  final String id;
  final String segment;
  final String rating;
  final double riskWeight;
  final String approach;

  factory RiskWeightRow.fromJson(Map<String, dynamic> json) {
    return RiskWeightRow(
      id: json['id'] as String,
      segment: json['segment'] as String,
      rating: json['rating'] as String,
      riskWeight: (json['risk_weight'] as num).toDouble(),
      approach: json['approach'] as String,
    );
  }
}

/// Ligne de référentiel pour les facteurs de conversion de crédit.
class CcfRow {
  const CcfRow({
    required this.id,
    required this.engagementType,
    required this.ccf,
  });

  final String id;
  final String engagementType;
  final double ccf;

  factory CcfRow.fromJson(Map<String, dynamic> json) {
    return CcfRow(
      id: json['id'] as String,
      engagementType: json['engagement_type'] as String,
      ccf: (json['ccf'] as num).toDouble(),
    );
  }
}

/// Ligne de référentiel pour les notations.
class RatingRow {
  const RatingRow({
    required this.id,
    required this.label,
    required this.description,
    required this.sortOrder,
  });

  final String id;
  final String label;
  final String description;
  final int sortOrder;

  factory RatingRow.fromJson(Map<String, dynamic> json) {
    return RatingRow(
      id: json['id'] as String,
      label: json['label'] as String,
      description: json['description'] as String,
      sortOrder: (json['sort_order'] as num).toInt(),
    );
  }
}

/// Données nécessaires à l'écran référentiels.
class ReferentielsModuleData {
  const ReferentielsModuleData({
    required this.riskWeights,
    required this.ccfTable,
    required this.ratings,
  });

  final List<RiskWeightRow> riskWeights;
  final List<CcfRow> ccfTable;
  final List<RatingRow> ratings;

  factory ReferentielsModuleData.fromJson(Map<String, dynamic> json) {
    return ReferentielsModuleData(
      riskWeights: (json['risk_weights'] as List<dynamic>)
          .map((item) => RiskWeightRow.fromJson(item as Map<String, dynamic>))
          .toList(),
      ccfTable: (json['ccf_table'] as List<dynamic>)
          .map((item) => CcfRow.fromJson(item as Map<String, dynamic>))
          .toList(),
      ratings: (json['ratings'] as List<dynamic>)
          .map((item) => RatingRow.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
