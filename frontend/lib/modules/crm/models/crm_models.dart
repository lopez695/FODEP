// Ce fichier decrit les donnees du module CRM.
/// Modèle d'un indicateur de synthèse CRM.
class CrmHighlight {
  const CrmHighlight({
    required this.borrowerName,
    required this.borrowerRw,
    required this.guarantorName,
    required this.guarantorRw,
    required this.finalRw,
    required this.label,
  });

  final String borrowerName;
  final double borrowerRw;
  final String guarantorName;
  final double guarantorRw;
  final double finalRw;
  final String label;

  factory CrmHighlight.fromJson(Map<String, dynamic> json) {
    return CrmHighlight(
      borrowerName: json['borrower_name'] as String,
      borrowerRw: (json['borrower_rw'] as num).toDouble(),
      guarantorName: json['guarantor_name'] as String,
      guarantorRw: (json['guarantor_rw'] as num).toDouble(),
      finalRw: (json['final_rw'] as num).toDouble(),
      label: json['label'] as String,
    );
  }
}

/// Modèle Flutter d'une garantie CRM.
class CrmRecord {
  const CrmRecord({
    required this.id,
    required this.exposureId,
    required this.borrowerName,
    required this.borrowerCategory,
    required this.borrowerRating,
    required this.grossAmount,
    required this.guarantorName,
    required this.guarantorCategory,
    required this.guarantorRating,
    required this.guaranteeType,
    required this.coverageAmount,
    required this.coverageRatio,
    required this.borrowerRw,
    required this.guarantorRw,
    required this.finalRw,
    required this.ead,
    required this.rwaBefore,
    required this.rwaAfter,
    required this.capitalBefore,
    required this.capitalAfter,
    required this.rwaReduction,
    required this.capitalSaving,
  });

  final String id;
  final String exposureId;
  final String borrowerName;
  final String borrowerCategory;
  final String borrowerRating;
  final double grossAmount;
  final String guarantorName;
  final String guarantorCategory;
  final String guarantorRating;
  final String guaranteeType;
  final double coverageAmount;
  final double coverageRatio;
  final double borrowerRw;
  final double guarantorRw;
  final double finalRw;
  final double ead;
  final double rwaBefore;
  final double rwaAfter;
  final double capitalBefore;
  final double capitalAfter;
  final double rwaReduction;
  final double capitalSaving;

  factory CrmRecord.fromJson(Map<String, dynamic> json) {
    return CrmRecord(
      id: json['id'] as String,
      exposureId: json['exposure_id'] as String,
      borrowerName: json['borrower_name'] as String,
      borrowerCategory: json['borrower_category'] as String,
      borrowerRating: json['borrower_rating'] as String,
      grossAmount: (json['gross_amount'] as num).toDouble(),
      guarantorName: json['guarantor_name'] as String,
      guarantorCategory: json['guarantor_category'] as String,
      guarantorRating: json['guarantor_rating'] as String,
      guaranteeType: json['guarantee_type'] as String,
      coverageAmount: (json['coverage_amount'] as num).toDouble(),
      coverageRatio: (json['coverage_ratio'] as num).toDouble(),
      borrowerRw: (json['borrower_rw'] as num).toDouble(),
      guarantorRw: (json['guarantor_rw'] as num).toDouble(),
      finalRw: (json['final_rw'] as num).toDouble(),
      ead: (json['ead'] as num).toDouble(),
      rwaBefore: (json['rwa_before'] as num).toDouble(),
      rwaAfter: (json['rwa_after'] as num).toDouble(),
      capitalBefore: (json['capital_before'] as num).toDouble(),
      capitalAfter: (json['capital_after'] as num).toDouble(),
      rwaReduction: (json['rwa_reduction'] as num).toDouble(),
      capitalSaving: (json['capital_saving'] as num).toDouble(),
    );
  }
}

/// Totaux agrégés du module CRM.
class CrmSummary {
  const CrmSummary({
    required this.totalExpositions,
    required this.totalEad,
    required this.totalRwaBefore,
    required this.totalRwaAfter,
    required this.totalCapitalAfter,
    required this.averageCoverage,
  });

  final double totalExpositions;
  final double totalEad;
  final double totalRwaBefore;
  final double totalRwaAfter;
  final double totalCapitalAfter;
  final double averageCoverage;

  factory CrmSummary.fromJson(Map<String, dynamic> json) {
    return CrmSummary(
      totalExpositions: (json['total_expositions'] as num).toDouble(),
      totalEad: (json['total_ead'] as num).toDouble(),
      totalRwaBefore: (json['total_rwa_before'] as num).toDouble(),
      totalRwaAfter: (json['total_rwa_after'] as num).toDouble(),
      totalCapitalAfter: (json['total_capital_after'] as num).toDouble(),
      averageCoverage: (json['average_coverage'] as num).toDouble(),
    );
  }
}

/// Données complètes nécessaires à l'écran CRM.
class CrmModuleData {
  const CrmModuleData({
    required this.highlight,
    required this.items,
    required this.summary,
  });

  final CrmHighlight? highlight;
  final List<CrmRecord> items;
  final CrmSummary summary;

  factory CrmModuleData.fromJson(Map<String, dynamic> json) {
    return CrmModuleData(
      highlight: json['highlight'] == null
          ? null
          : CrmHighlight.fromJson(json['highlight'] as Map<String, dynamic>),
      items: (json['items'] as List<dynamic>)
          .map((item) => CrmRecord.fromJson(item as Map<String, dynamic>))
          .toList(),
      summary: CrmSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }
}
