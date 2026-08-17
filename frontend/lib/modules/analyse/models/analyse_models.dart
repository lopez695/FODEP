// Modèles de données pour le module d'analyse.
import 'package:flutter/material.dart';

import '../../dashboard/models/dashboard_models.dart';

/// Données complètes d'analyse du portefeuille.
class AnalyseData {
  const AnalyseData({
    required this.regulatoryReport,
    required this.portfolioQualityScore,
    required this.qualityTrend,
    required this.concentrationLevel,
    required this.concentrationTrend,
    required this.crmCoverageRatio,
    required this.crmTrend,
    required this.rwaReductionPotential,
    required this.sectorDistribution,
    required this.sectorInsights,
    required this.ratingDistribution,
    required this.ratingInsights,
    required this.topConcentration,
    required this.lowRatedExposure,
    required this.weightedAverageRating,
    required this.rwaEvolution,
    required this.rwaVariation,
    required this.currentCapital,
    required this.prudentialAlerts,
    required this.topRiskExposures,
    required this.recommendations,
  });

  final RegulatoryAnalysisReport regulatoryReport;
  final double portfolioQualityScore;
  final String qualityTrend;
  final double concentrationLevel;
  final String concentrationTrend;
  final double crmCoverageRatio;
  final String crmTrend;
  final double rwaReductionPotential;
  final List<DistributionEntry> sectorDistribution;
  final List<String> sectorInsights;
  final List<DistributionEntry> ratingDistribution;
  final List<String> ratingInsights;
  final DistributionEntry? topConcentration;
  final double lowRatedExposure;
  final String? weightedAverageRating;
  final List<RwaEvolutionPoint> rwaEvolution;
  final double rwaVariation;
  final double currentCapital;
  final List<PrudentialAlert> prudentialAlerts;
  final List<RiskExposure> topRiskExposures;
  final List<AnalyseRecommendation> recommendations;
}

enum RegulatoryZone { uemoa, cemac }

enum RegulatoryStatus { green, warning, critical }

extension RegulatoryStatusLabel on RegulatoryStatus {
  String get label {
    switch (this) {
      case RegulatoryStatus.green:
        return 'GREEN';
      case RegulatoryStatus.warning:
        return 'WARNING';
      case RegulatoryStatus.critical:
        return 'CRITICAL';
    }
  }
}

/// Rapport JSON produit par le moteur de regles prudentielles.
class RegulatoryAnalysisReport {
  const RegulatoryAnalysisReport({
    required this.analysisId,
    required this.timestamp,
    required this.regulatoryZone,
    required this.status,
    required this.availableCapital,
    required this.requiredCapital,
    required this.economicCapital,
    required this.diagnostics,
    required this.rootCauses,
    required this.recommendations,
    required this.analysisCards,
    required this.alertTimeline,
    required this.consultantNarrative,
  });

  final String analysisId;
  final DateTime timestamp;
  final RegulatoryZone regulatoryZone;
  final RegulatoryStatus status;
  final double availableCapital;
  final double requiredCapital;
  final double economicCapital;
  final List<RegulatoryDiagnostic> diagnostics;
  final List<String> rootCauses;
  final List<RegulatoryAction> recommendations;
  final List<RegulatoryAnalysisCard> analysisCards;
  final List<RegulatoryAlertEvent> alertTimeline;
  final String consultantNarrative;

  double get capitalGap => availableCapital - requiredCapital;

  Map<String, dynamic> toJson() {
    return {
      'analysis_id': analysisId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'regulatory_zone': regulatoryZone.name.toUpperCase(),
      'status': status.label,
      'available_capital': availableCapital,
      'required_capital': requiredCapital,
      'economic_capital': economicCapital,
      'capital_gap': capitalGap,
      'diagnostics': diagnostics.map((item) => item.toJson()).toList(),
      'root_causes': rootCauses,
      'recommendations': recommendations.map((item) => item.toJson()).toList(),
    };
  }
}

class RegulatoryDiagnostic {
  const RegulatoryDiagnostic({
    required this.ruleReference,
    required this.threshold,
    required this.currentValue,
    required this.gap,
    required this.message,
    required this.severity,
  });

  final String ruleReference;
  final double threshold;
  final double currentValue;
  final double gap;
  final String message;
  final String severity;

  Map<String, dynamic> toJson() {
    return {
      'rule_reference': ruleReference,
      'threshold': threshold,
      'current_value': currentValue,
      'gap': gap,
      'message': message,
      'severity': severity,
    };
  }
}

class RegulatoryAction {
  const RegulatoryAction({
    required this.action,
    required this.deadline,
    required this.priority,
  });

  final String action;
  final DateTime deadline;
  final int priority;

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'deadline': deadline.toIso8601String().split('T').first,
      'priority': priority,
    };
  }
}

class RegulatoryAnalysisCard {
  const RegulatoryAnalysisCard({
    required this.title,
    required this.ruleReference,
    required this.status,
    required this.keyValue,
    required this.keyLabel,
    required this.diagnostic,
    required this.cause,
    required this.recommendation,
    required this.icon,
  });

  final String title;
  final String ruleReference;
  final RegulatoryStatus status;
  final String keyValue;
  final String keyLabel;
  final String diagnostic;
  final String cause;
  final String recommendation;
  final IconData icon;
}

class RegulatoryAlertEvent {
  const RegulatoryAlertEvent({
    required this.date,
    required this.title,
    required this.detail,
    required this.status,
  });

  final DateTime date;
  final String title;
  final String detail;
  final RegulatoryStatus status;
}

/// Point d'évolution du RWA dans le temps.
class RwaEvolutionPoint {
  const RwaEvolutionPoint({
    required this.label,
    required this.value,
    required this.date,
  });

  final String label;
  final double value;
  final DateTime date;
}

/// Alerte prudentielle.
class PrudentialAlert {
  const PrudentialAlert({
    required this.severity,
    required this.message,
    required this.action,
  });

  final String severity;
  final String message;
  final String action;
}

/// Exposition à risque.
class RiskExposure {
  const RiskExposure({
    required this.counterparty,
    required this.rwa,
    required this.rating,
    required this.category,
  });

  final String counterparty;
  final double rwa;
  final String rating;
  final String category;
}

/// Recommandation d'optimisation.
class AnalyseRecommendation {
  const AnalyseRecommendation({
    required this.title,
    required this.description,
    required this.impact,
    required this.effort,
    required this.priority,
    required this.category,
    required this.estimatedSaving,
    required this.actions,
  });

  final String title;
  final String description;
  final String impact;
  final String effort;
  final String priority;
  final String category;
  final double? estimatedSaving;
  final List<String> actions;
}

/// KPI d'analyse.
class AnalyseKpi {
  const AnalyseKpi({
    required this.label,
    required this.value,
    this.suffix,
    required this.icon,
    required this.color,
    required this.trend,
  });

  final String label;
  final String value;
  final String? suffix;
  final IconData icon;
  final Color color;
  final String trend;
}

/// Insight d'analyse.
class AnalyseInsight {
  const AnalyseInsight({
    required this.icon,
    required this.severity,
    required this.message,
    required this.recommendation,
  });

  final IconData icon;
  final String severity;
  final String message;
  final String recommendation;
}
