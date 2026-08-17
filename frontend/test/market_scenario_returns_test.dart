// Vérifie qu'une distribution reconstruite n'est jamais présentée comme un
// historique : un portefeuille actions sans série de prix expose une série
// simulée, mais aucun rendement ni aucune perte « observés ». Contrôle aussi
// que la VaR 99 % ne se confond plus avec la pire perte de l'échantillon.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';

MarketPortfolioDataset _equitiesDataset(
  List<Map<String, dynamic>> rows,
) {
  return MarketPortfolioDataset(
    portfolioType: MarketPortfolioType.equities,
    fileName: 'test.xlsx',
    importedAt: DateTime(2026, 7, 22),
    headers: const [],
    records: [
      for (final row in rows)
        MarketPortfolioRecord(
          portfolioType: MarketPortfolioType.equities,
          values: row,
        ),
    ],
  );
}

void main() {
  group('Rendements de scénario actions', () {
    test('sans série de prix : distribution simulée, aucun observé', () {
      final dataset = _equitiesDataset([
        {
          'ID Titre': 'ACT001',
          'Valeur de marché': 4000000000,
          'Volatilité annualisée (%)': 0.22,
          'Rendement attendu (%)': 0.07,
        },
      ]);

      expect(dataset.scenarioReturnsAreSimulated, isTrue);
      expect(dataset.scenarioReturns, isNotEmpty);
      // Une VaR historique ne peut pas s'appuyer là-dessus.
      expect(dataset.observedReturns, isEmpty);
      expect(dataset.observedLosses, isEmpty);
    });

    test('la distribution simulée ne dépend que des paramètres saisis', () {
      List<double> returnsFor(String titleId, double marketValue) {
        return _equitiesDataset([
          {
            'ID Titre': titleId,
            'Valeur de marché': marketValue,
            'Volatilité annualisée (%)': 0.22,
            'Rendement attendu (%)': 0.07,
          },
        ]).scenarioReturns;
      }

      // Reproductible à paramètres identiques...
      expect(returnsFor('ACT001', 4000000000),
          orderedEquals(returnsFor('ACT002', 9000000000)));

      // ...et effectivement gouvernée par la volatilité saisie.
      final volatile = _equitiesDataset([
        {
          'ID Titre': 'ACT003',
          'Valeur de marché': 4000000000,
          'Volatilité annualisée (%)': 0.44,
          'Rendement attendu (%)': 0.07,
        },
      ]).scenarioReturns;
      expect(volatile.last, greaterThan(returnsFor('ACT001', 4000000000).last));
    });

    test('VaR 99 % simulée : quantile normal, distinct de la perte extrême',
        () {
      const volatility = 0.22;
      final dataset = _equitiesDataset([
        {
          'ID Titre': 'ACT001',
          'Valeur de marché': 4000000000,
          'Volatilité annualisée (%)': volatility,
          'Rendement attendu (%)': 0.07,
        },
      ]);

      // Le repli ancien renvoyait le maximum de l'échantillon : VaR ≡ pire
      // perte. Le quantile interpolé doit désormais rester strictement en
      // dessous.
      expect(dataset.scenarioVar99, lessThan(dataset.scenarioWorstLoss));

      // Et coller au quantile théorique µ + z₉₉ σ appliqué à la valeur du
      // portefeuille (le signe s'inverse : une perte est un rendement négatif).
      final dailyVolatility = volatility / math.sqrt(252);
      const dailyMean = 0.07 / 252;
      final theoretical =
          (2.3263 * dailyVolatility - dailyMean) * dataset.portfolioValue;
      expect(
        dataset.scenarioVar99,
        moreOrLessEquals(theoretical, epsilon: theoretical * 0.02),
      );
    });

    test('avec série de prix datée : les rendements sont observés', () {
      final dataset = _equitiesDataset([
        for (var day = 1; day <= 6; day++)
          {
            'ID Titre': 'ACT001',
            'Date d\'analyse': DateTime(2026, 6, day),
            'Valeur de marché': 4000000000 + day * 25000000,
            'Volatilité annualisée (%)': 0.22,
          },
      ]);

      expect(dataset.scenarioReturnsAreSimulated, isFalse);
      expect(dataset.observedReturns, orderedEquals(dataset.scenarioReturns));
      expect(dataset.observedReturns, hasLength(5));
      expect(dataset.observedLosses, hasLength(5));
    });
  });
}
