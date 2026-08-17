import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/modules/risque_marche/models/currency_registry.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';

void main() {
  group('calculateMarketPrudentialCapital — taux de change utilisé', () {
    setUp(() {
      // Remet le référentiel à sa valeur par défaut avant/après chaque test :
      // ce singleton est partagé, un test ne doit pas polluer le suivant.
      CurrencyRegistry().updateRate('USD', 600.0);
    });
    tearDown(() {
      CurrencyRegistry().updateRate('USD', 600.0);
    });

    MarketPortfolioRecord titreUsd() => MarketPortfolioRecord(
          portfolioType: MarketPortfolioType.bonds,
          values: {
            'ID Titre': 'USD-001',
            'Devise': 'USD',
            'Valeur actuelle': 1000000,
            'quantités': 1,
          },
        );

    test(
        'reflète une actualisation du taux courant (CurrencyRegistry), pas '
        'la table figée de currency_conversion.dart', () {
      final avant = calculateMarketPrudentialCapital(records: [titreUsd()]);
      expect(avant.foreignExchangeGlobalNetPosition,
          moreOrLessEquals(600000000, epsilon: 1));

      CurrencyRegistry().updateRate('USD', 572.97);

      final apres = calculateMarketPrudentialCapital(records: [titreUsd()]);
      expect(apres.foreignExchangeGlobalNetPosition,
          moreOrLessEquals(572970000, epsilon: 1));
      expect(apres.foreignExchangeGlobalNetPosition,
          isNot(avant.foreignExchangeGlobalNetPosition));
    });
  });
}
