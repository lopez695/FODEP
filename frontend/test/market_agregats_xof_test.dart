// Les agrégats d'un portefeuille multidevises se calculent en XOF.
//
// Additionner des montants libellés en EUR et en XOF ne produit aucune
// grandeur interprétable : le total affiché divergeait des exigences de fonds
// propres, elles calculées au taux courant. Ces tests verrouillent la
// conversion à la source, ainsi que les poids qui en dépendent.

import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/modules/risque_marche/models/currency_registry.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';

MarketPortfolioRecord _action(Map<String, Object?> valeurs) =>
    MarketPortfolioRecord(
      portfolioType: MarketPortfolioType.equities,
      values: valeurs,
    );

MarketPortfolioDataset _portefeuille(List<MarketPortfolioRecord> lignes) =>
    MarketPortfolioDataset(
      portfolioType: MarketPortfolioType.equities,
      fileName: 'actions.xlsx',
      importedAt: DateTime(2026, 7, 23),
      headers: const [],
      records: lignes,
    );

void main() {
  late double tauxEur;

  setUp(() {
    // Taux effectivement appliqué par le moteur prudentiel : les attentes se
    // construisent dessus plutôt que sur une constante recopiée, sinon le test
    // casse au premier rafraîchissement de cotation.
    tauxEur = marketCurrentRateToXof('EUR');
  });

  test('le référentiel de change expose bien un taux EUR exploitable', () {
    expect(tauxEur, greaterThan(1));
  });

  group('Exposition convertie', () {
    test('une ligne en devise est convertie au taux courant', () {
      final ligne = _action({
        'Emetteur': 'PARIS SA',
        'Devise': 'EUR',
        'Quantité': 100,
        'Cours actuel': 50,
      });

      expect(ligne.exposureAmount, 5000);
      expect(ligne.exposureAmountXof, moreOrLessEquals(5000 * tauxEur));
    });

    test('une ligne en XOF reste inchangée', () {
      final ligne = _action({
        'Emetteur': 'DAKAR SA',
        'Devise': 'XOF',
        'Quantité': 100,
        'Cours actuel': 50,
      });

      expect(ligne.exposureAmountXof, 5000);
    });

    test('devise absente : la ligne est traitée comme du XOF', () {
      final ligne = _action({
        'Emetteur': 'SANS DEVISE',
        'Quantité': 100,
        'Cours actuel': 50,
      });

      expect(ligne.exposureAmountXof, 5000);
    });
  });

  group('Total du portefeuille', () {
    test('le total additionne des montants convertis, pas des montants bruts',
        () {
      final portefeuille = _portefeuille([
        _action({
          'Emetteur': 'DAKAR SA',
          'Devise': 'XOF',
          'Quantité': 1000,
          'Cours actuel': 10000,
        }),
        _action({
          'Emetteur': 'PARIS SA',
          'Devise': 'EUR',
          'Quantité': 1000,
          'Cours actuel': 100,
        }),
      ]);

      const localXof = 10000000.0;
      final etrangerXof = 100000 * tauxEur;

      expect(
        portefeuille.totalExposure,
        moreOrLessEquals(localXof + etrangerXof, epsilon: 0.01),
      );
      // La somme brute, elle, vaudrait 10 100 000 : sans conversion, la ligne
      // en euros pesait cent fois moins que sa valeur réelle.
      expect(portefeuille.totalExposure, greaterThan(10100000));
    });

    test('le total du bandeau et la valeur de marché prudentielle concordent',
        () {
      final portefeuille = _portefeuille([
        _action({
          'Emetteur': 'DAKAR SA',
          'Devise': 'XOF',
          'Quantité': 1000,
          'Cours actuel': 10000,
        }),
        _action({
          'Emetteur': 'PARIS SA',
          'Devise': 'EUR',
          'Quantité': 1000,
          'Cours actuel': 100,
        }),
      ]);

      expect(
        portefeuille.totalExposure,
        moreOrLessEquals(portefeuille.totalMarketValueXof, epsilon: 0.01),
      );
    });
  });

  group('Poids dérivés du total', () {
    test(
        'le poids du premier émetteur se calcule sur des montants comparables',
        () {
      final portefeuille = _portefeuille([
        _action({
          'Emetteur': 'DAKAR SA',
          'Devise': 'XOF',
          'Quantité': 1000,
          'Cours actuel': 10000,
        }),
        _action({
          'Emetteur': 'PARIS SA',
          'Devise': 'EUR',
          'Quantité': 1000,
          'Cours actuel': 100,
        }),
      ]);

      const localXof = 10000000.0;
      final etrangerXof = 100000 * tauxEur;
      final attendu = (localXof > etrangerXof ? localXof : etrangerXof) /
          (localXof + etrangerXof);

      expect(
        portefeuille.concentrationRatio,
        moreOrLessEquals(attendu, epsilon: 0.0001),
      );
    });

    test('le bêta pondéré utilise des poids convertis', () {
      final portefeuille = _portefeuille([
        _action({
          'Emetteur': 'DAKAR SA',
          'Devise': 'XOF',
          'Quantité': 1000,
          'Cours actuel': 10000,
          'Bêta': 0.8,
        }),
        _action({
          'Emetteur': 'PARIS SA',
          'Devise': 'EUR',
          'Quantité': 1000,
          'Cours actuel': 100,
          'Bêta': 1.6,
        }),
      ]);

      const localXof = 10000000.0;
      final etrangerXof = 100000 * tauxEur;
      final attendu =
          (0.8 * localXof + 1.6 * etrangerXof) / (localXof + etrangerXof);

      expect(
        portefeuille.weightedBeta,
        moreOrLessEquals(attendu, epsilon: 0.0001),
      );
    });
  });

  group('Rendement attendu du portefeuille actions', () {
    test(
        'une ligne sans rendement déclaré compte pour zéro, elle n\'est pas '
        'écartée du calcul', () {
      final portefeuille = _portefeuille([
        _action({
          'Emetteur': 'DISTRIBUTRICE',
          'Quantité': 1000,
          'Cours actuel': 10000,
          'Rendement dividende (%)': 6,
        }),
        _action({
          'Emetteur': 'SANS DIVIDENDE',
          'Quantité': 1000,
          'Cours actuel': 10000,
        }),
      ]);

      // Deux lignes de poids égal, une seule rapporte 6 % : le portefeuille
      // rapporte 3 %. L'ancienne pondération écartait la seconde ligne des
      // deux côtés du quotient et annonçait 6 %.
      expect(portefeuille.expectedReturn, moreOrLessEquals(0.03));
    });

    test('le rendement attendu et le rendement dividende pondéré concordent',
        () {
      final portefeuille = _portefeuille([
        _action({
          'Emetteur': 'A',
          'Quantité': 1000,
          'Cours actuel': 10000,
          'Rendement dividende (%)': 6,
        }),
        _action({
          'Emetteur': 'B',
          'Quantité': 3000,
          'Cours actuel': 10000,
          'Rendement dividende (%)': 2,
        }),
        _action({
          'Emetteur': 'C',
          'Quantité': 1000,
          'Cours actuel': 10000,
        }),
      ]);

      expect(
        portefeuille.expectedReturn,
        moreOrLessEquals(portefeuille.weightedDividendYield, epsilon: 1e-9),
      );
    });

    test('aucun rendement déclaré : zéro, pas d\'extrapolation', () {
      final portefeuille = _portefeuille([
        _action({
          'Emetteur': 'A',
          'Quantité': 1000,
          'Cours actuel': 10000,
        }),
      ]);

      expect(portefeuille.expectedReturn, 0);
    });
  });

  group('Cohérence avec le référentiel de change', () {
    test('le taux exposé aux écrans est celui du référentiel partagé', () {
      final registre = CurrencyRegistry().getRate('EUR');
      if (registre == null) return;
      expect(
        marketCurrentRateToXof('EUR'),
        moreOrLessEquals(registre.rateToXof),
      );
    });

    test('le XOF vaut toujours un', () {
      expect(marketCurrentRateToXof('XOF'), 1.0);
    });
  });
}
