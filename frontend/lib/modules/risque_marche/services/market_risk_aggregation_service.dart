/// Service d'agrégation des KPI risque de marché
/// Combine Taux, Change, Actions pour calculer RWA Marché Total et contributions
library;

import '../services/foreign_exchange_risk_service.dart';
import '../services/market_data_import_store.dart';

/// Résultat agrégé de tous les risques de marché
class AggregatedMarketRiskResult {
  const AggregatedMarketRiskResult({
    required this.foreignExchangeRisk,
    required this.tauxRwa,
    required this.actionsRwa,
    required this.totalMarketRwa,
    required this.fxContributionPercent,
  });

  final ForeignExchangeRiskResult foreignExchangeRisk;
  final double tauxRwa; // RWA du risque de taux
  final double actionsRwa; // RWA du risque actions
  final double totalMarketRwa; // RWA Marché total
  final double fxContributionPercent; // Contribution FX au RWA total (%)
}

/// Remplace le risque de change de [base] - approximation tirée de la
/// colonne devise des titres obligations/actions importés - par le vrai
/// risque de change calculé sur les positions saisies dans l'onglet Risque
/// de Change (actifs/passifs/achats-ventes à terme, approche standard
/// BCEAO). `capitalRequirement`/`marketRwa` (getters dérivés) reflètent donc
/// automatiquement la correction.
///
/// Si [fxPositions] est vide (rien saisi dans le formulaire actifs/passifs),
/// [base] est renvoyé tel quel : une saisie absente ne doit jamais écraser
/// une exposition change réellement présente dans le portefeuille importé
/// par un zéro. La substitution ne s'applique que si l'utilisateur a
/// effectivement saisi au moins une position de change.
MarketPrudentialCapitalResult applyRealForeignExchangeRisk(
  MarketPrudentialCapitalResult base,
  List<ForeignExchangePosition> fxPositions,
) {
  if (fxPositions.isEmpty) return base;

  final fx = calculateForeignExchangeRisk(fxPositions);
  return MarketPrudentialCapitalResult(
    interestRateSpecificRisk: base.interestRateSpecificRisk,
    interestRateGeneralRisk: base.interestRateGeneralRisk,
    equitySpecificRisk: base.equitySpecificRisk,
    equityGeneralRisk: base.equityGeneralRisk,
    foreignExchangeRisk: fx.capitalRequirement,
    commodityDirectionalRisk: base.commodityDirectionalRisk,
    commodityBasisRisk: base.commodityBasisRisk,
    interestRateSpecificRiskWeightAverage:
        base.interestRateSpecificRiskWeightAverage,
    interestRateGeneralRiskWeightAverage:
        base.interestRateGeneralRiskWeightAverage,
    equityGrossPosition: base.equityGrossPosition,
    equityNetPosition: base.equityNetPosition,
    equityLongPosition: base.equityLongPosition,
    equityShortPosition: base.equityShortPosition,
    equityNetLongPosition: base.equityNetLongPosition,
    equityNetShortPosition: base.equityNetShortPosition,
    equitySpecificBaseLiquid: base.equitySpecificBaseLiquid,
    equitySpecificBaseOther: base.equitySpecificBaseOther,
    equityGeneralBase: base.equityGeneralBase,
    foreignExchangeGlobalNetPosition: fx.globalNetPosition,
    // Le calculateur de change dédié classe chaque devise en longue ou en
    // courte : ce sont ces deux totaux que l'EP27 déclare, la position nette
    // globale n'étant que le plus élevé des deux.
    foreignExchangeLongPosition: fx.totalLongPositions,
    foreignExchangeShortPosition: fx.totalShortPositions,
    commodityGrossPosition: base.commodityGrossPosition,
    commodityNetPosition: base.commodityNetPosition,
    interestRateGeneralDetail: base.interestRateGeneralDetail,
    interestRateSpecificLines: base.interestRateSpecificLines,
  );
}

/// Positions à déclarer sur les états EP26 (actions) et EP27 (change).
///
/// Le formulaire ne se contente pas de l'exigence de fonds propres : il
/// demande l'assiette qui la produit, ventilée en positions longues et
/// courtes, brutes puis nettes. Ces montants sont déjà calculés pour établir
/// l'exigence ; il ne restait qu'à les transmettre.
Map<String, Object?> positionsMarchePourFodep(
  MarketPrudentialCapitalResult resultat,
) {
  return {
    'actions': {
      'longues': resultat.equityLongPosition,
      'courtes': resultat.equityShortPosition,
      'nettes_longues': resultat.equityNetLongPosition,
      'nettes_courtes': resultat.equityNetShortPosition,
      // Assiettes des deux pondérations du risque spécifique.
      'base_specifique_liquide': resultat.equitySpecificBaseLiquid,
      'base_specifique_autre': resultat.equitySpecificBaseOther,
      'base_generale': resultat.equityGeneralBase,
    },
    'change': {
      'longues': resultat.foreignExchangeLongPosition,
      'courtes': resultat.foreignExchangeShortPosition,
      // Position nette globale = le plus élevé des deux sens : c'est elle qui
      // porte l'exigence.
      'position_nette_globale': resultat.foreignExchangeGlobalNetPosition,
    },
    'taux': _tauxPourFodep(resultat),
  };
}

/// Échelle de maturité et risque spécifique de taux, pour l'EP25.
Map<String, Object?> _tauxPourFodep(MarketPrudentialCapitalResult resultat) {
  final detail = resultat.interestRateGeneralDetail;
  final tranches = <Map<String, Object?>>[];
  for (final index in detail.zoneParTranche.keys.toList()..sort()) {
    tranches.add({
      'index': index,
      'zone': detail.zoneParTranche[index],
      'nettes_longues': detail.longueParTranche[index] ?? 0,
      'nettes_courtes': detail.courteParTranche[index] ?? 0,
    });
  }

  return {
    'specifique': [
      for (final ligne in resultat.interestRateSpecificLines) ligne.versJson(),
    ],
    'general': {
      'tranches': tranches,
      // Positions équilibrées, avant le facteur de compensation que le
      // formulaire imprime lui-même sur chaque ligne.
      'equilibre_toutes_tranches': detail.equilibreToutesTranches,
      'equilibre_plage_1': detail.equilibreParZone[0],
      'equilibre_plage_2': detail.equilibreParZone[1],
      'equilibre_plage_3': detail.equilibreParZone[2],
      'equilibre_plages_1_2': detail.equilibreEntreZones[0],
      'equilibre_plages_2_3': detail.equilibreEntreZones[1],
      'equilibre_plages_1_3': detail.equilibreEntreZones[2],
      'residu': detail.residu,
    },
  };
}

/// Conversion d'une exigence de fonds propres marché en équivalent RWA (§90).
///
/// Le dispositif retient 12,5 - l'inverse de 8 % - et non l'inverse du ratio
/// de solvabilité de 9 %. Les composantes taux, actions et change doivent
/// partager ce multiplicateur, faute de quoi leur somme n'a plus de sens.
const double _rwaEquivalentMultiplier = 12.5;

/// Service pour calculer les KPI agrégés du risque de marché
class MarketRiskAggregationService {
  static final MarketRiskAggregationService _instance =
      MarketRiskAggregationService._internal();

  factory MarketRiskAggregationService() {
    return _instance;
  }

  MarketRiskAggregationService._internal();

  /// Calcule les KPI agrégés (Taux + Change + Actions)
  AggregatedMarketRiskResult calculateAggregatedRisk({
    required List<ForeignExchangePosition> fxPositions,
    MarketDataImportStore? marketStore,
  }) {
    // 1. Calcule le risque de change
    final fxRisk = calculateForeignExchangeRisk(fxPositions);

    // 2. Récupère le store des données marché
    final store = marketStore ?? MarketDataImportStore.instance;

    // 3. Récupère les RWA des autres risques
    // TODO: Implémenter les méthodes publiques dans MarketDataImportStore
    // pour retourner les RWA Taux et Actions
    final tauxRwa = _getTauxRwaFromStore(store);
    final actionsRwa = _getActionsRwaFromStore(store);

    // 4. Calcule le RWA total du marché
    final totalRwa = fxRisk.marketRwa + tauxRwa + actionsRwa;

    // 5. Calcule la contribution FX
    final fxContribution =
        totalRwa > 0 ? (fxRisk.marketRwa / totalRwa) * 100 : 0.0;

    return AggregatedMarketRiskResult(
      foreignExchangeRisk: fxRisk,
      tauxRwa: tauxRwa,
      actionsRwa: actionsRwa,
      totalMarketRwa: totalRwa,
      fxContributionPercent: fxContribution,
    );
  }

  /// Récupère le RWA Taux du store
  double _getTauxRwaFromStore(MarketDataImportStore store) {
    final capital = store.dataset?.prudentialCapital;
    if (capital == null) return 0.0;
    // interestRateRisk = interestRateSpecificRisk + interestRateGeneralRisk
    // Équivalent RWA = exigence × 12,5, comme les composantes change et
    // actions : additionner des conversions différentes fausserait le total.
    return capital.interestRateRisk * _rwaEquivalentMultiplier;
  }

  /// Récupère le RWA Actions du store
  double _getActionsRwaFromStore(MarketDataImportStore store) {
    final capital = store.dataset?.prudentialCapital;
    if (capital == null) return 0.0;
    // equityRisk = equitySpecificRisk + equityGeneralRisk
    return capital.equityRisk * _rwaEquivalentMultiplier;
  }
}
