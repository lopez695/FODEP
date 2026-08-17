/// Modèles pour l'analyse des risques de change au niveau des titres
/// Évaluation de l'impact des fluctuations de devises sur les titres individuels
library fx_security_analysis;

import 'package:flutter/foundation.dart';

/// Énumération pour le statut d'un titre vis-à-vis du risque de change
enum FxSecurityStatus {
  favorable, // Gain de change positif 🟢
  unfavorable, // Perte de change négative 🔴
  stable, // Gain/Perte proche de 0 ⚪
}

/// Énumération pour la position de change
enum FxPositionType {
  long, // Position longue
  short, // Position courte
  neutral, // Position nulle
}

/// Représente l'analyse du risque de change pour un titre individuel
class FxSecurityAnalysis {
  const FxSecurityAnalysis({
    required this.titleId,
    required this.titleName,
    required this.currency,
    required this.initialValue,
    required this.currentValue,
    required this.initialRate,
    required this.currentRate,
    required this.quantity,
    required this.acquisitionDate,
    required this.analysisDate,
  });

  final String titleId; // Identifiant unique du titre
  final String titleName; // Nom du titre (ex: "Obligation Trésor US")
  final String currency; // Devise (XOF, EUR ou USD ; XAF/FCFA repliés sur XOF)
  final double initialValue; // Valeur initiale du titre en devise d'origine
  final double currentValue; // Valeur actuelle du titre en devise d'origine
  final double initialRate; // Taux de change initial (1 devise = X XOF)
  final double currentRate; // Taux de change actuel (1 devise = X XOF)
  final double quantity; // Quantité détenue
  final DateTime acquisitionDate; // Date d'acquisition du titre
  final DateTime analysisDate; // Date d'analyse

  /// Valeur initiale convertie en XOF
  double get initialValueInXof => (initialValue * quantity * initialRate).abs();

  /// Valeur actuelle convertie en XOF
  double get currentValueInXof => (currentValue * quantity * currentRate).abs();

  /// Variation du taux de change en pourcentage
  /// Calcul: ((Taux_Actuel - Taux_Initial) / Taux_Initial) × 100
  double get currencyVariationPercent {
    if (currency == 'XOF' || currency == 'XAF') return 0.0;
    if (initialRate == 0) return 0;
    return ((currentRate - initialRate) / initialRate) * 100;
  }

  /// Gain ou perte de change en XOF - effet de change PUR.
  /// Calcul: Position en devise × (Taux_Actuel − Taux_Initial).
  /// La variation de PRIX du titre (émission → valeur actuelle en devise)
  /// n'entre pas ici : à taux de change inchangé, le gain/perte de change
  /// est nul par construction.
  double get fxGainLoss {
    if (currency == 'XOF' || currency == 'XAF') return 0.0;
    return currentValue * quantity * (currentRate - initialRate);
  }

  /// Gain ou perte de change en pourcentage de la position valorisée au
  /// taux d'acquisition. Cohérent avec [currencyVariationPercent] : à taux
  /// inchangé, il vaut 0.
  double get fxGainLossPercent {
    final base = (currentValue * quantity * initialRate).abs();
    if (base == 0) return 0;
    return (fxGainLoss / base) * 100;
  }

  /// Détermination du type de position (longue/courte)
  /// Position longue: la banque bénéficie d'une appréciation de la devise
  /// Position courte: la banque est pénalisée par l'appréciation
  FxPositionType get positionType {
    if (currency == 'XOF' || currency == 'XAF') return FxPositionType.neutral;
    if (quantity == 0) return FxPositionType.neutral;
    if (quantity > 0) return FxPositionType.long;
    return FxPositionType.short;
  }

  /// Détermination du statut visuel
  FxSecurityStatus get status {
    if (fxGainLoss > 0.01) return FxSecurityStatus.favorable;
    if (fxGainLoss < -0.01) return FxSecurityStatus.unfavorable;
    return FxSecurityStatus.stable;
  }

  /// Représentation textuelle du statut
  String get statusLabel => switch (status) {
        FxSecurityStatus.favorable => 'Favorable',
        FxSecurityStatus.unfavorable => 'Défavorable',
        FxSecurityStatus.stable => 'Stable',
      };

  /// Emoji du statut
  String get statusEmoji => switch (status) {
        FxSecurityStatus.favorable => '🟢',
        FxSecurityStatus.unfavorable => '🔴',
        FxSecurityStatus.stable => '⚪',
      };

  /// Représentation textuelle de la position
  String get positionLabel => switch (positionType) {
        FxPositionType.long => 'Longue',
        FxPositionType.short => 'Courte',
        FxPositionType.neutral => 'Neutre',
      };

  /// RWA (Risk Weighted Assets) de change pour le titre
  double get rwa {
    if (currency == 'XOF' || currency == 'XAF') return 0.0;
    return currentValueInXof; // 100% de pondération pour le risque de change
  }
}

/// Résumé des expositions par devise
class FxCurrencyExposure {
  const FxCurrencyExposure({
    required this.currency,
    required this.totalLongExposure,
    required this.totalShortExposure,
    required this.netExposure,
    required this.securitiesCount,
    required this.acquisitionDate,
    required this.analysisDate,
  });

  final String currency;
  final double totalLongExposure; // Somme des expositions longues en XOF
  final double totalShortExposure; // Somme des expositions courtes en XOF
  final double netExposure; // Position nette en XOF
  final int securitiesCount; // Nombre de titres exposés
  final DateTime acquisitionDate;
  final DateTime analysisDate;

  /// Détermination du type de position pour la devise
  FxPositionType get positionType {
    if (netExposure.abs() < 0.01) return FxPositionType.neutral;
    if (netExposure > 0) return FxPositionType.long;
    return FxPositionType.short;
  }

  /// Représentation textuelle de la position
  String get positionLabel => switch (positionType) {
        FxPositionType.long => 'Longue',
        FxPositionType.short => 'Courte',
        FxPositionType.neutral => 'Neutre',
      };

  /// Valeur absolue de l'exposition nette
  double get absoluteNetExposure => netExposure.abs();
}

/// Résultat global de l'analyse des risques de change
class FxRiskAnalysisResult {
  const FxRiskAnalysisResult({
    required this.securities,
    required this.currencyExposures,
    required this.totalExposure,
    required this.globalFxGainLoss,
    required this.totalLongPositions,
    required this.totalShortPositions,
    required this.globalNetPosition,
    required this.capitalRequirement,
    required this.rwaChange,
    required this.marketRiskContribution,
    required this.analysisDate,
  });

  final List<FxSecurityAnalysis> securities;
  final List<FxCurrencyExposure> currencyExposures;
  final double totalExposure; // Exposition totale en devises
  final double globalFxGainLoss; // Gain/Perte global de change
  final double totalLongPositions; // Total positions longues
  final double totalShortPositions; // Total positions courtes
  final double
      globalNetPosition; // Position nette globale = MAX(longues, courtes)
  final double
      capitalRequirement; // Exigence FP Change = globalNetPosition × 8%
  final double rwaChange; // RWA Change = capitalRequirement × 12,5 (§90)
  final double marketRiskContribution; // Contribution au risque de marché (%)
  final DateTime analysisDate;

  /// Nombre de titres exposés au risque de change
  int get exposedSecuritiesCount => securities.length;

  /// Nombre de devises
  int get currenciesCount => currencyExposures.length;

  /// Nombre de titres avec gain de change
  int get securitiesWithGain =>
      securities.where((s) => s.fxGainLoss > 0).length;

  /// Nombre de titres avec perte de change
  int get securitiesWithLoss =>
      securities.where((s) => s.fxGainLoss < 0).length;

  /// Gain moyen par titre
  double get averageFxGainLoss => exposedSecuritiesCount > 0
      ? globalFxGainLoss / exposedSecuritiesCount
      : 0;

  /// Ratio de concentration des positions longues
  double get longConcentrationRatio {
    if (totalLongPositions == 0) return 0;
    final maxLong = currencyExposures
        .map((c) => c.totalLongExposure)
        .fold<double>(0, (max, v) => v > max ? v : max);
    return (maxLong / totalLongPositions).clamp(0, 1);
  }

  /// Ratio de concentration des positions courtes
  double get shortConcentrationRatio {
    if (totalShortPositions == 0) return 0;
    final maxShort = currencyExposures
        .map((c) => c.totalShortExposure)
        .fold<double>(0, (max, v) => v > max ? v : max);
    return (maxShort / totalShortPositions).clamp(0, 1);
  }
}

/// Classe pour tracker les changements dans l'analyse
@immutable
class FxAnalysisSnapshot {
  const FxAnalysisSnapshot({
    required this.result,
    required this.timestamp,
  });

  final FxRiskAnalysisResult result;
  final DateTime timestamp;

  /// Crée une copie avec modifications
  FxAnalysisSnapshot copyWith({
    FxRiskAnalysisResult? result,
    DateTime? timestamp,
  }) {
    return FxAnalysisSnapshot(
      result: result ?? this.result,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
