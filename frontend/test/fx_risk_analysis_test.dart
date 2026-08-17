import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/modules/risque_marche/models/fx_security_analysis.dart';
import 'package:rwa_calculator/modules/risque_marche/services/fx_security_analysis_service.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';

void main() {
  group('FxSecurityAnalysis Model Calculations', () {
    final now = DateTime.now();

    test('RWA is 0.0 for local currency XOF', () {
      final analysis = FxSecurityAnalysis(
        titleId: 'T001',
        titleName: 'Obligation XOF',
        currency: 'XOF',
        initialValue: 10000.0,
        currentValue: 10000.0,
        initialRate: 1.0,
        currentRate: 1.0,
        quantity: 100.0,
        acquisitionDate: now,
        analysisDate: now,
      );

      expect(analysis.rwa, 0.0);
      expect(analysis.currentValueInXof, 10000.0 * 100.0 * 1.0);
    });

    test('RWA is 0.0 for local currency XAF', () {
      final analysis = FxSecurityAnalysis(
        titleId: 'T002',
        titleName: 'Obligation XAF',
        currency: 'XAF',
        initialValue: 5000.0,
        currentValue: 5000.0,
        initialRate: 1.0,
        currentRate: 1.0,
        quantity: 50.0,
        acquisitionDate: now,
        analysisDate: now,
      );

      expect(analysis.rwa, 0.0);
    });

    test('RWA is 100% of currentValueInXof for foreign currencies (USD)', () {
      final analysis = FxSecurityAnalysis(
        titleId: 'T003',
        titleName: 'Obligation USD',
        currency: 'USD',
        initialValue: 100.0,
        currentValue: 110.0,
        initialRate: 600.0,
        currentRate: 610.0,
        quantity: 10.0,
        acquisitionDate: now,
        analysisDate: now,
      );

      // currentValueInXof = currentValue * quantity * currentRate = 110.0 * 10.0 * 610.0 = 671,000.0
      expect(analysis.currentValueInXof, 671000.0);
      expect(analysis.rwa, 671000.0);
    });

    test('fxGainLoss and currencyVariationPercent are calculated correctly',
        () {
      final analysis = FxSecurityAnalysis(
        titleId: 'T004',
        titleName: 'Obligation EUR',
        currency: 'EUR',
        initialValue: 200.0,
        currentValue: 200.0,
        initialRate: 650.0,
        currentRate: 655.0,
        quantity: 5.0,
        acquisitionDate: now,
        analysisDate: now,
      );

      // initialValueInXof = 200 * 5 * 650 = 650,000.0
      // currentValueInXof = 200 * 5 * 655 = 655,000.0
      // fxGainLoss = 655,000.0 - 650,000.0 = 5,000.0
      expect(analysis.fxGainLoss, 5000.0);
      expect(analysis.currencyVariationPercent,
          closeTo(((655.0 - 650.0) / 650.0) * 100, 0.0001));
    });
  });

  group('FxSecurityAnalysisService portfolio analysis', () {
    final service = FxSecurityAnalysisService();
    final now = DateTime(2026, 6, 19);

    MarketPortfolioRecord bond(Map<String, Object?> values) =>
        MarketPortfolioRecord(
          portfolioType: MarketPortfolioType.bonds,
          values: values,
        );

    test(
        'exclut les titres en devise de référence (XOF/XAF) du périmètre de change',
        () {
      final result = service.analyzePortfolio(
        records: [
          bond({
            'Devise': 'XOF',
            'Valeur nominale unitaire': 1000.0,
            'quantités': 5.0
          }),
          bond({
            'Devise': 'XAF',
            'Valeur nominale unitaire': 1000.0,
            'quantités': 5.0
          }),
        ],
        analysisDate: now,
      );

      // La devise de référence ne porte par définition aucun risque de
      // change : ces titres sont exclus du périmètre (convention alignée
      // sur le calcul prudentiel global) et toutes les métriques sont nulles.
      expect(result.securities, isEmpty);
      expect(result.totalExposure, 0.0);
      expect(result.rwaChange, 0.0);
      expect(result.globalNetPosition, 0.0);
    });

    test('variation et gain calculés via taux acquisition (titre) vs courant',
        () {
      final result = service.analyzePortfolio(
        records: [
          bond({
            'Devise': 'USD',
            'Valeur nominale unitaire': 100.0,
            'quantités': 1.0,
            'Taux d\'acquisition': 580.0,
          }),
          // Un titre XOF est exclu du périmètre de change : il ne doit ni
          // apparaître dans la table ni peser sur le calcul du risque.
          bond({
            'Devise': 'XOF',
            'Valeur nominale unitaire': 9999.0,
            'quantités': 1.0
          }),
        ],
        analysisDate: now,
        exchangeRates: {'USD': 625.0},
      );

      expect(result.securities, hasLength(1));
      final usd = result.securities.single;
      expect(usd.currency, 'USD');
      expect(usd.initialRate, 580.0); // taux d'acquisition du titre
      expect(usd.currentRate, 625.0); // taux courant saisi
      expect(usd.currencyVariationPercent,
          closeTo(((625.0 - 580.0) / 580.0) * 100, 0.0001));

      // currentValueInXof = 100 × 1 × 625 = 62 500 ; initial = 100 × 1 × 580 = 58 000
      expect(usd.currentValueInXof, 62500.0);
      expect(usd.fxGainLoss, closeTo(4500.0, 0.0001));

      // Position nette globale = 62 500 (long USD) ; exigence = ×8 % (Art. 417) ;
      // équivalent RWA = exigence ×12,5 (§90), soit la position elle-même.
      expect(result.globalNetPosition, closeTo(62500.0, 0.0001));
      expect(result.capitalRequirement, closeTo(5000.0, 0.0001));
      expect(result.rwaChange, closeTo(62500.0, 0.0001));
    });

    test(
        'sans taux d\'acquisition, repli sur le taux de RÉFÉRENCE du registre '
        '(pas sur le courant) : la cotation produit une variation mesurable',
        () {
      final result = service.analyzePortfolio(
        records: [
          bond({
            'Devise': 'USD',
            'Valeur nominale unitaire': 100.0,
            'quantités': 1.0,
          }),
        ],
        analysisDate: now,
        exchangeRates: {'USD': 625.0},
      );

      expect(result.securities, hasLength(1));
      final usd = result.securities.single;
      // Contre-valeur de référence USD du CurrencyRegistry : 600 XOF.
      expect(usd.initialRate, 600.0);
      expect(usd.currentRate, 625.0);
      expect(usd.currencyVariationPercent,
          closeTo(((625.0 - 600.0) / 600.0) * 100, 0.0001));
      // gain = 100 × 1 × 625 − 100 × 1 × 600 = 2 500
      expect(usd.fxGainLoss, closeTo(2500.0, 0.0001));
      // L'exposition (et donc le RWA) reste bien calculée.
      expect(result.rwaChange, closeTo(62500.0, 0.0001));
    });
  });
}
