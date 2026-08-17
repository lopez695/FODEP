import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/modules/risque_marche/services/foreign_exchange_risk_service.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_risk_aggregation_service.dart';

MarketPrudentialCapitalResult _baseWithForeignExchangeApproximation({
  required double foreignExchangeRisk,
  required double foreignExchangeGlobalNetPosition,
}) {
  return MarketPrudentialCapitalResult(
    interestRateSpecificRisk: 0,
    interestRateGeneralRisk: 0,
    equitySpecificRisk: 0,
    equityGeneralRisk: 0,
    foreignExchangeRisk: foreignExchangeRisk,
    commodityDirectionalRisk: 0,
    commodityBasisRisk: 0,
    interestRateSpecificRiskWeightAverage: 0,
    interestRateGeneralRiskWeightAverage: 0,
    equityGrossPosition: 0,
    equityNetPosition: 0,
    equityLongPosition: 0,
    equityShortPosition: 0,
    equityNetLongPosition: 0,
    equityNetShortPosition: 0,
    equitySpecificBaseLiquid: 0,
    equitySpecificBaseOther: 0,
    equityGeneralBase: 0,
    foreignExchangeGlobalNetPosition: foreignExchangeGlobalNetPosition,
    foreignExchangeLongPosition: foreignExchangeGlobalNetPosition,
    foreignExchangeShortPosition: 0,
    commodityGrossPosition: 0,
    commodityNetPosition: 0,
    interestRateGeneralDetail: const MarketInterestRateGeneralDetail(
      capital: 0,
      longueParTranche: {},
      courteParTranche: {},
      zoneParTranche: {},
      equilibreToutesTranches: 0,
      equilibreParZone: [0, 0, 0],
      equilibreEntreZones: [0, 0, 0],
      residu: 0,
    ),
    interestRateSpecificLines: const [],
  );
}

void main() {
  group('applyRealForeignExchangeRisk', () {
    test(
        'aucune position actif/passif saisie : conserve l\'approximation '
        'tirée des colonnes devise des titres importés (ne remplace pas par zéro)',
        () {
      final base = _baseWithForeignExchangeApproximation(
        foreignExchangeRisk: 1008000000, // 1,008 Md FCFA (9 % de 11,2 Md)
        foreignExchangeGlobalNetPosition: 11200000000,
      );

      final result = applyRealForeignExchangeRisk(base, const []);

      expect(result.foreignExchangeRisk, base.foreignExchangeRisk);
      expect(result.foreignExchangeGlobalNetPosition,
          base.foreignExchangeGlobalNetPosition);
      expect(result.marketRwa, base.marketRwa);
    });

    test(
        'positions actif/passif saisies : remplace l\'approximation par le '
        'risque réel calculé sur ces positions', () {
      final base = _baseWithForeignExchangeApproximation(
        foreignExchangeRisk: 1008000000,
        foreignExchangeGlobalNetPosition: 11200000000,
      );
      const positions = [
        ForeignExchangePosition(
          currency: 'USD',
          assets: 500000000,
          liabilities: 0,
          forwardPurchases: 0,
          forwardSales: 0,
        ),
      ];

      final result = applyRealForeignExchangeRisk(base, positions);

      expect(result.foreignExchangeGlobalNetPosition, 500000000);
      // Risque de change : 8 % de la position nette globale (Art. 417).
      expect(result.foreignExchangeRisk, 500000000 * 0.08);
      expect(result.foreignExchangeRisk, isNot(base.foreignExchangeRisk));
    });
  });

  group('équivalent RWA des composantes marché', () {
    tearDown(() {
      // Le store est un singleton : ne pas laisser fuiter le jeu de test.
      MarketDataImportStore.instance.snapshotNotifier.value =
          MarketDataSnapshot.empty;
    });

    test(
        'taux, actions et change partagent le multiplicateur 12,5 : leur somme '
        'reste additionnable', () {
      // Actions XOF de 100 M : spécifique 8 M + général 8 M = 16 M d'exigence.
      final equities = MarketPortfolioDataset(
        portfolioType: MarketPortfolioType.equities,
        fileName: 'test.xlsx',
        importedAt: DateTime(2026, 7, 21),
        headers: const ['Émetteur / Société', 'Devise', 'Valeur de marché'],
        records: [
          MarketPortfolioRecord(
            portfolioType: MarketPortfolioType.equities,
            values: const {
              'Émetteur / Société': 'Société cotée',
              'Devise': 'XOF',
              'Valeur de marché': 100000000,
            },
          ),
        ],
      );
      MarketDataImportStore.instance.snapshotNotifier.value =
          MarketDataSnapshot.fromDatasets(
        {MarketPortfolioType.equities: equities},
        activeType: MarketPortfolioType.equities,
      );

      final result = MarketRiskAggregationService().calculateAggregatedRisk(
        fxPositions: const [],
        marketStore: MarketDataImportStore.instance,
      );

      // 16 M × 12,5 = 200 M, et non 16 M ÷ 0,09 = 177,8 M : mélanger les deux
      // conversions rendrait le total incohérent avec sa composante change.
      expect(result.actionsRwa, closeTo(200000000, 0.01));
      expect(
        result.totalMarketRwa,
        closeTo(result.tauxRwa + result.actionsRwa + 0.0, 0.01),
      );
    });
  });
}
