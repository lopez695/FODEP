/// Service de calcul du risque de change conforme BCEAO
/// Approche standard: Position nette globale × 8%
library;

import 'dart:math' as math;

import '../models/currency_registry.dart';

/// Représente une position de change par devise
class ForeignExchangePosition {
  const ForeignExchangePosition({
    required this.currency,
    required this.assets,
    required this.liabilities,
    required this.forwardPurchases,
    required this.forwardSales,
  });

  final String currency;
  final double assets; // Actifs en devise
  final double liabilities; // Passifs en devise
  final double forwardPurchases; // Achats à terme en devise
  final double forwardSales; // Ventes à terme en devise

  /// Calcule la position nette : Actifs - Passifs - Achats_à_terme + Ventes_à_terme
  double get netPosition =>
      assets - liabilities - forwardPurchases + forwardSales;

  /// Détermine si la position est longue (positive)
  bool get isLong => netPosition > 0;

  /// Détermine si la position est courte (négative)
  bool get isShort => netPosition < 0;

  /// Valeur absolue de la position nette
  double get absolutePosition => netPosition.abs();

  Map<String, Object?> toJson() => {
        'currency': currency,
        'assets': assets,
        'liabilities': liabilities,
        'forward_purchases': forwardPurchases,
        'forward_sales': forwardSales,
      };

  factory ForeignExchangePosition.fromJson(Map<String, Object?> json) {
    double asDouble(Object? value) =>
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0.0;
    return ForeignExchangePosition(
      currency: (json['currency'] as String?) ?? '',
      assets: asDouble(json['assets']),
      liabilities: asDouble(json['liabilities']),
      forwardPurchases: asDouble(json['forward_purchases']),
      forwardSales: asDouble(json['forward_sales']),
    );
  }
}

/// Résultat du calcul du risque de change
class ForeignExchangeRiskResult {
  const ForeignExchangeRiskResult({
    required this.positions,
    required this.totalLongPositions,
    required this.totalShortPositions,
    required this.globalNetPosition,
    required this.capitalRequirement,
    required this.marketRwa,
  });

  final List<ForeignExchangePosition> positions;
  final double totalLongPositions; // Somme des positions positives
  final double
      totalShortPositions; // Somme des positions négatives (valeur absolue)
  final double globalNetPosition; // MAX(longues, courtes)
  final double capitalRequirement; // Position_Nette_Globale × 8%
  final double marketRwa; // Capital_Requirement × 12,5
}

/// Calcule le risque de change conformément à l'approche standard BCEAO
/// Article 45 du dispositif prudentiel
ForeignExchangeRiskResult calculateForeignExchangeRisk(
  List<ForeignExchangePosition> positions,
) {
  double totalLong = 0.0;
  double totalShort = 0.0;

  // Pour chaque devise, classer position longue ou courte
  for (final position in positions) {
    if (position.netPosition > 0) {
      totalLong += position.netPosition;
    } else if (position.netPosition < 0) {
      totalShort += position.netPosition.abs();
    }
  }

  // Position nette globale = MAX(longues, courtes)
  final globalNetPosition = math.max(totalLong, totalShort);

  // Exigence de fonds propres pour risque de change = 8 % de la position
  // nette globale. C'est le taux que le FODEP imprime sur l'EP27, dans une
  // colonne verrouillée par la BCEAO (RM060 et RM061 = 0,08) : une exigence
  // calculée à 9 % ne vaudrait pas la position multipliée par sa pondération,
  // et l'état ne se bouclerait pas. Le passage à l'actif pondéré se fait
  // ensuite par le multiplicateur ci-dessous, pas en gonflant ce taux.
  final capitalRequirement = globalNetPosition * 0.08;

  // Équivalent RWA = Exigence_FP × 12,5, comme l'annonce la documentation du
  // champ `marketRwa` ci-dessus et comme le retient le reste du projet.
  final marketRwa = capitalRequirement * 12.5;

  return ForeignExchangeRiskResult(
    positions: positions,
    totalLongPositions: totalLong,
    totalShortPositions: totalShort,
    globalNetPosition: globalNetPosition,
    capitalRequirement: capitalRequirement,
    marketRwa: marketRwa,
  );
}

/// Calcule l'analyse statistique des positions
PositionAnalysis analyzePositions(List<ForeignExchangePosition> positions) {
  if (positions.isEmpty) {
    return const PositionAnalysis(
      totalDevises: 0,
      longPositions: 0,
      shortPositions: 0,
      neutralPositions: 0,
      averagePositionSize: 0,
      largestLongPosition: 0,
      largestShortPosition: 0,
      concentrationRatio: 0,
    );
  }

  final registry = CurrencyRegistry();
  int longCount = 0;
  int shortCount = 0;
  int neutralCount = 0;
  double largestLong = 0;
  double largestShort = 0;
  double totalAbsolute = 0;

  for (final pos in positions) {
    final rate = registry.getRate(pos.currency);
    final rateValue = rate?.rateToXof ?? 1.0;
    final positionInXof = pos.netPosition * rateValue;

    totalAbsolute += positionInXof.abs();

    if (pos.netPosition > 0) {
      longCount++;
      largestLong = math.max(largestLong, positionInXof);
    } else if (pos.netPosition < 0) {
      shortCount++;
      largestShort = math.max(largestShort, positionInXof.abs());
    } else {
      neutralCount++;
    }
  }

  final averageSize =
      positions.isNotEmpty ? totalAbsolute / positions.length : 0.0;
  final concentrationRatio = largestLong > 0 || largestShort > 0
      ? (math.max(largestLong, largestShort)) /
          (totalAbsolute > 0 ? totalAbsolute : 1)
      : 0.0;

  return PositionAnalysis(
    totalDevises: positions.length,
    longPositions: longCount,
    shortPositions: shortCount,
    neutralPositions: neutralCount,
    averagePositionSize: averageSize,
    largestLongPosition: largestLong,
    largestShortPosition: largestShort,
    concentrationRatio: concentrationRatio,
  );
}
