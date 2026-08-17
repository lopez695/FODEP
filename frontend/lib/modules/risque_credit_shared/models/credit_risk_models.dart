import '../../dashboard/models/dashboard_models.dart';

class CreditExposureOption {
  const CreditExposureOption({
    required this.id,
    required this.label,
    required this.counterpartyName,
    required this.category,
    required this.currency,
    required this.grossAmount,
  });

  final String id;
  final String label;
  final String counterpartyName;
  final String category;
  final String currency;
  final double grossAmount;
}

class CreditGuaranteeRecord {
  const CreditGuaranteeRecord({
    required this.id,
    required this.exposureId,
    required this.exposureLabel,
    required this.counterpartyName,
    required this.sector,
    required this.type,
    required this.value,
    required this.currency,
    required this.coverageRatio,
    required this.expirationDate,
    required this.status,
    required this.sourceLabel,
    required this.rwaLinked,
  });

  final String id;
  final String exposureId;
  final String exposureLabel;
  final String counterpartyName;
  final String sector;
  final String type;
  final double value;
  final String currency;
  final double coverageRatio;
  final DateTime expirationDate;
  final String status;
  final String sourceLabel;
  final bool rwaLinked;

  bool get isExpired {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return expirationDate.isBefore(startOfDay);
  }
}

class CreditGuaranteeDraft {
  const CreditGuaranteeDraft({
    this.id,
    required this.exposureId,
    required this.type,
    required this.value,
    required this.currency,
    required this.coverageRatio,
    required this.expirationDate,
    required this.status,
  });

  final String? id;
  final String exposureId;
  final String type;
  final double value;
  final String currency;
  final double coverageRatio;
  final DateTime expirationDate;
  final String status;
}

class CreditGuaranteeSummary {
  const CreditGuaranteeSummary({
    required this.totalGuarantees,
    required this.activeValue,
    required this.averageCoverage,
    required this.expiringSoonCount,
  });

  final int totalGuarantees;
  final double activeValue;
  final double averageCoverage;
  final int expiringSoonCount;
}

class GuaranteesModuleData {
  const GuaranteesModuleData({
    required this.guarantees,
    required this.exposureOptions,
    required this.summary,
  });

  final List<CreditGuaranteeRecord> guarantees;
  final List<CreditExposureOption> exposureOptions;
  final CreditGuaranteeSummary summary;
}

class CreditIncidentEvent {
  const CreditIncidentEvent({
    required this.date,
    required this.title,
    required this.description,
  });

  final DateTime date;
  final String title;
  final String description;
}

class CreditDefaultRecord {
  const CreditDefaultRecord({
    required this.exposureId,
    required this.counterpartyName,
    required this.country,
    required this.sector,
    required this.rating,
    required this.grossAmount,
    required this.ead,
    required this.rwa,
    required this.capital,
    required this.daysPastDue,
    required this.prudentialStatus,
    required this.estimatedProvision,
    required this.provisionRate,
    required this.incidents,
  });

  final String exposureId;
  final String counterpartyName;
  final String country;
  final String sector;
  final String rating;
  final double grossAmount;
  final double ead;
  final double rwa;
  final double capital;
  final int daysPastDue;
  final String prudentialStatus;
  final double estimatedProvision;
  final double provisionRate;
  final List<CreditIncidentEvent> incidents;

  DateTime get lastIncidentDate => incidents.first.date;
}

class CreditDefaultSummary {
  const CreditDefaultSummary({
    required this.totalDefaults,
    required this.totalDefaultGross,
    required this.totalProvision,
    required this.averageDaysPastDue,
  });

  final int totalDefaults;
  final double totalDefaultGross;
  final double totalProvision;
  final double averageDaysPastDue;
}

class DefaultsModuleData {
  const DefaultsModuleData({
    required this.items,
    required this.summary,
  });

  final List<CreditDefaultRecord> items;
  final CreditDefaultSummary summary;
}

class ConcentrationExposureRow {
  const ConcentrationExposureRow({
    required this.exposureId,
    required this.counterpartyName,
    required this.country,
    required this.sector,
    required this.segment,
    required this.grossAmount,
    required this.ead,
    required this.rwa,
    required this.averageRiskWeight,
    required this.share,
  });

  final String exposureId;
  final String counterpartyName;
  final String country;
  final String sector;
  final String segment;
  final double grossAmount;
  final double ead;
  final double rwa;
  final double averageRiskWeight;
  final double share;
}

class SectorConcentrationRow {
  const SectorConcentrationRow({
    required this.sector,
    required this.exposureCount,
    required this.grossAmount,
    required this.ead,
    required this.rwa,
    required this.averageRiskWeight,
    required this.rwaShare,
    required this.share,
  });

  final String sector;
  final int exposureCount;
  final double grossAmount;
  final double ead;
  final double rwa;
  final double averageRiskWeight;
  final double rwaShare;
  final double share;
}

class ConcentrationSummary {
  const ConcentrationSummary({
    required this.totalGross,
    required this.totalNetEad,
    required this.totalRwa,
    required this.topSectorShare,
    required this.topThreeShare,
    required this.topSectorLabel,
    required this.topCounterpartyName,
    required this.topCounterpartyShare,
    required this.herfindahlIndex,
    required this.hhiBadge,
    required this.counterpartyCount,
  });

  final double totalGross;
  final double totalNetEad;
  final double totalRwa;
  final double topSectorShare;
  final double topThreeShare;
  final String topSectorLabel;
  final String topCounterpartyName;
  final double topCounterpartyShare;
  final double herfindahlIndex;
  final String hhiBadge;
  final int counterpartyCount;
}

class ConcentrationBreakdownRow {
  const ConcentrationBreakdownRow({
    required this.label,
    required this.group,
    required this.exposureCount,
    required this.grossAmount,
    required this.ead,
    required this.rwa,
    required this.averageRiskWeight,
    required this.portfolioShare,
    required this.rwaShare,
  });

  final String label;
  final String group;
  final int exposureCount;
  final double grossAmount;
  final double ead;
  final double rwa;
  final double averageRiskWeight;
  final double portfolioShare;
  final double rwaShare;
}

class RiskWeightBucketRow {
  const RiskWeightBucketRow({
    required this.label,
    required this.weight,
    required this.exposureCount,
    required this.ead,
    required this.rwa,
    required this.portfolioShare,
    required this.rwaShare,
  });

  final String label;
  final double weight;
  final int exposureCount;
  final double ead;
  final double rwa;
  final double portfolioShare;
  final double rwaShare;
}

class ConcentrationExposureDetail {
  const ConcentrationExposureDetail({
    required this.id,
    required this.analysisDate,
    required this.counterpartyName,
    required this.country,
    required this.region,
    required this.sector,
    required this.segment,
    required this.prudentialCategory,
    required this.rating,
    required this.status,
    required this.hasGuarantee,
    required this.isDefault,
    required this.authorizationAmount,
    required this.onBalanceAmount,
    required this.offBalanceAmount,
    required this.grossAmount,
    required this.ead,
    required this.rwa,
    required this.capital,
    required this.originalRiskWeight,
    required this.riskWeight,
    required this.crmCoverageRatio,
    required this.pd,
    required this.lgd,
    required this.estimatedProvision,
    required this.provisionRate,
    this.joursImpayes = 0,
    this.provisionsAmount = 0.0,
  });

  final String id;
  final DateTime analysisDate;
  final String counterpartyName;
  final String country;
  final String region;
  final String sector;
  final String segment;
  final String prudentialCategory;
  final String rating;
  final String status;
  final bool hasGuarantee;
  final bool isDefault;
  final double authorizationAmount;
  final double onBalanceAmount;
  final double offBalanceAmount;
  final double grossAmount;
  final double ead;
  final double rwa;
  final double capital;
  final double originalRiskWeight;
  final double riskWeight;
  final double crmCoverageRatio;
  final double pd;
  final double lgd;
  final double estimatedProvision;
  final double provisionRate;
  final int joursImpayes;
  final double provisionsAmount;
}

class PortfolioQualitySummary {
  const PortfolioQualitySummary({
    required this.nplRatio,
    required this.defaultRate,
    required this.defaultGross,
    required this.riskCoverage,
    required this.averagePd,
    required this.averageLgd,
    required this.nplTrend,
    required this.defaultTrend,
    required this.coverageTrend,
  });

  final double nplRatio;
  final double defaultRate;
  final double defaultGross;
  final double riskCoverage;
  final double averagePd;
  final double averageLgd;
  final double nplTrend;
  final double defaultTrend;
  final double coverageTrend;
}

class ConcentrationTrendPoint {
  const ConcentrationTrendPoint({
    required this.label,
    required this.date,
    required this.ead,
    required this.rwa,
    required this.npl,
    required this.hhi,
  });

  final String label;
  final DateTime date;
  final double ead;
  final double rwa;
  final double npl;
  final double hhi;
}

class ConcentrationAlert {
  const ConcentrationAlert({
    required this.level,
    required this.severity,
    required this.date,
    required this.message,
    required this.recommendation,
  });

  final String level;
  final String severity;
  final DateTime date;
  final String message;
  final String recommendation;
}

class ConcentrationModuleData {
  const ConcentrationModuleData({
    required this.summary,
    required this.sectorRows,
    required this.countryRows,
    required this.regionRows,
    required this.prudentialRows,
    required this.riskWeightRows,
    required this.rwaSectorRows,
    required this.rwaCounterpartyRows,
    required this.exposureDetails,
    required this.topExposures,
    required this.sectorDistribution,
    required this.countryDistribution,
    required this.ratingDistribution,
    required this.quality,
    required this.trends,
    required this.alerts,
  });

  final ConcentrationSummary summary;
  final List<SectorConcentrationRow> sectorRows;
  final List<ConcentrationBreakdownRow> countryRows;
  final List<ConcentrationBreakdownRow> regionRows;
  final List<ConcentrationBreakdownRow> prudentialRows;
  final List<RiskWeightBucketRow> riskWeightRows;
  final List<SectorConcentrationRow> rwaSectorRows;
  final List<ConcentrationExposureRow> rwaCounterpartyRows;
  final List<ConcentrationExposureDetail> exposureDetails;
  final List<ConcentrationExposureRow> topExposures;
  final List<DistributionEntry> sectorDistribution;
  final List<DistributionEntry> countryDistribution;
  final List<DistributionEntry> ratingDistribution;
  final PortfolioQualitySummary quality;
  final List<ConcentrationTrendPoint> trends;
  final List<ConcentrationAlert> alerts;
}

enum CreditReportFamily {
  portfolio,
  guarantees,
  defaults,
}

extension CreditReportFamilyLabel on CreditReportFamily {
  String get label {
    switch (this) {
      case CreditReportFamily.portfolio:
        return 'Portefeuille';
      case CreditReportFamily.guarantees:
        return 'Garanties';
      case CreditReportFamily.defaults:
        return 'Défauts / Impayés';
    }
  }

  String get subtitle {
    switch (this) {
      case CreditReportFamily.portfolio:
        return 'Vue consolidée des expositions de crédit';
      case CreditReportFamily.guarantees:
        return 'Inventaire des garanties et couvertures CRM';
      case CreditReportFamily.defaults:
        return 'Surveillance prudentielle des défauts et retards';
    }
  }
}

enum CreditExportFormat {
  excel,
  pdf,
}

extension CreditExportFormatLabel on CreditExportFormat {
  String get label {
    switch (this) {
      case CreditExportFormat.excel:
        return 'Excel';
      case CreditExportFormat.pdf:
        return 'PDF';
    }
  }

  String get fileExtension {
    switch (this) {
      case CreditExportFormat.excel:
        return '.xlsx';
      case CreditExportFormat.pdf:
        return '.pdf';
    }
  }
}

class CreditReportingFamilySnapshot {
  const CreditReportingFamilySnapshot({
    required this.family,
    required this.itemCount,
    required this.totalAmount,
  });

  final CreditReportFamily family;
  final int itemCount;
  final double totalAmount;
}

class CreditReportHistoryRecord {
  const CreditReportHistoryRecord({
    required this.id,
    required this.createdAt,
    required this.family,
    required this.format,
    required this.fileName,
    required this.lineCount,
    required this.totalAmount,
  });

  final String id;
  final DateTime createdAt;
  final CreditReportFamily family;
  final CreditExportFormat format;
  final String fileName;
  final int lineCount;
  final double totalAmount;
}

class CreditReportingSummary {
  const CreditReportingSummary({
    required this.generatedReports,
    required this.excelExports,
    required this.pdfExports,
  });

  final int generatedReports;
  final int excelExports;
  final int pdfExports;
}

class CreditReportingModuleData {
  const CreditReportingModuleData({
    required this.familySnapshots,
    required this.history,
    required this.summary,
  });

  final List<CreditReportingFamilySnapshot> familySnapshots;
  final List<CreditReportHistoryRecord> history;
  final CreditReportingSummary summary;
}

class CreditExportDataset {
  const CreditExportDataset({
    required this.sheetName,
    required this.headers,
    required this.rows,
    required this.totalAmount,
  });

  final String sheetName;
  final List<String> headers;
  final List<List<String>> rows;
  final double totalAmount;
}
