import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';

MarketPortfolioRecord _equity(Map<String, Object?> values) =>
    MarketPortfolioRecord(
      portfolioType: MarketPortfolioType.equities,
      values: values,
    );

MarketPortfolioDataset _dataset(List<MarketPortfolioRecord> records) =>
    MarketPortfolioDataset(
      portfolioType: MarketPortfolioType.equities,
      fileName: 'actions.xlsx',
      importedAt: DateTime(2026, 7, 22),
      headers: const [],
      records: records,
    );

void main() {
  group('Plus et moins-values latentes (actions)', () {
    test(
        'le prix de revient est lu dans « Prix d\'achat unitaire », '
        'le nom réellement utilisé par le modèle d\'import', () {
      final record = _equity({
        'Emetteur': 'SONATEL',
        'Quantité': 1000,
        'Prix d\'achat unitaire': 12000,
        'Cours actuel': 13500,
      });

      expect(record.acquisitionPrice, 12000);
      expect(record.acquisitionCost, 12000000);
      expect(record.latentGain, 1500000);
    });

    test('« Prix d\'acquisition », colonne du modèle d\'import, reste lue', () {
      final record = _equity({
        'Emetteur': 'SONATEL',
        'Quantité': 1000,
        'Prix d\'acquisition': 12000,
        'Cours actuel': 13500,
      });

      expect(record.acquisitionPrice, 12000);
      expect(record.latentGain, 1500000);
    });

    test('le prix de revient se déduit du coût d\'acquisition et de la quantité',
        () {
      final record = _equity({
        'Emetteur': 'BOA',
        'Quantité': 500,
        'Coût d\'acquisition': 5000000,
        'Cours actuel': 9000,
      });

      expect(record.acquisitionPrice, 10000);
      expect(record.latentGain, -500000);
    });

    test('la colonne latente importée prime sur le recalcul', () {
      final record = _equity({
        'Emetteur': 'ORAGROUP',
        'Quantité': 100,
        'Prix d\'achat unitaire': 2000,
        'Cours actuel': 2500,
        'Plus/(moins)-value latente': 42000,
      });

      expect(record.latentGain, 42000);
    });

    test('sans prix de revient, aucune plus-value n\'est extrapolée', () {
      final record = _equity({
        'Emetteur': 'Inconnu',
        'Quantité': 100,
        'Cours actuel': 2500,
      });

      expect(record.acquisitionPrice, 0);
      expect(record.latentGain, 0);
    });

    test('le portefeuille agrège la PMV et le rendement latent', () {
      final dataset = _dataset([
        _equity({
          'Emetteur': 'SONATEL',
          'Quantité': 1000,
          'Prix d\'achat unitaire': 12000,
          'Cours actuel': 13500,
        }),
        _equity({
          'Emetteur': 'BOA',
          'Quantité': 500,
          'Prix d\'achat unitaire': 10000,
          'Cours actuel': 9000,
        }),
      ]);

      // 1 500 000 de plus-value - 500 000 de moins-value.
      expect(dataset.totalLatentGain, 1000000);
      expect(dataset.totalAcquisitionCost, 17000000);
      expect(
        dataset.latentReturn,
        moreOrLessEquals(1000000 / 17000000, epsilon: 1e-9),
      );
    });

    test('rendement latent nul quand aucun prix de revient n\'est importé', () {
      final dataset = _dataset([
        _equity({
          'Emetteur': 'Inconnu',
          'Quantité': 100,
          'Cours actuel': 2500,
        }),
      ]);

      expect(dataset.totalAcquisitionCost, 0);
      expect(dataset.latentReturn, 0);
    });
  });

  group('Consolidation par émetteur', () {
    test('un émetteur porté par plusieurs lignes n\'occupe qu\'un rang', () {
      final dataset = _dataset([
        _equity({
          'Emetteur': 'Sanaga Utilities SA',
          'Quantité': 1000,
          'Prix d\'acquisition': 10000,
          'Cours actuel': 9000,
        }),
        _equity({
          'Emetteur': 'Sanaga Utilities SA',
          'Quantité': 500,
          'Prix d\'acquisition': 10000,
          'Cours actuel': 9400,
        }),
        _equity({
          'Emetteur': 'Nokoué Ciments SA',
          'Quantité': 1000,
          'Prix d\'acquisition': 10000,
          'Cours actuel': 12000,
        }),
      ]);

      final issuers = dataset.latentPnlByIssuer;
      expect(issuers.map((line) => line.issuer).toList(), [
        'Nokoué Ciments SA',
        'Sanaga Utilities SA',
      ]);
      // -1 000 000 sur la première ligne, -300 000 sur la seconde.
      expect(issuers.last.gain, -1300000);
      expect(issuers.last.cost, 15000000);
      expect(issuers.last.variation, moreOrLessEquals(-1300000 / 15000000));
    });

    test('le classement suit le montant latent en valeur absolue', () {
      final dataset = _dataset([
        _equity({
          'Emetteur': 'PETITE HAUSSE',
          'Quantité': 100,
          'Prix d\'acquisition': 1000,
          'Cours actuel': 1100,
        }),
        _equity({
          'Emetteur': 'GROSSE BAISSE',
          'Quantité': 100,
          'Prix d\'acquisition': 1000,
          'Cours actuel': 500,
        }),
      ]);

      expect(
        dataset.latentPnlByIssuer.first.issuer,
        'GROSSE BAISSE',
      );
    });
  });

  group('Corrélation', () {
    test(
        'sans série de prix, la corrélation est déduite et signalée comme non '
        'mesurée', () {
      final dataset = _dataset([
        _equity({
          'Emetteur': 'A',
          'Quantité': 1000,
          'Cours actuel': 10000,
        }),
        _equity({
          'Emetteur': 'B',
          'Quantité': 1000,
          'Cours actuel': 10000,
        }),
      ]);

      expect(dataset.hasMeasuredCorrelation, isFalse);
      // Repli : 0,45 + 0,25 × poids du premier émetteur (ici 50 %).
      expect(dataset.correlationProxy, moreOrLessEquals(0.575));
    });
  });

  group('Ventilations du portefeuille actions', () {
    test(
        'le périmètre de négociation isole l\'assiette de l\'exigence : '
        'AFS et participations en sont exclus', () {
      final dataset = _dataset([
        _equity({
          'Emetteur': 'SONATEL',
          'Intention comptable': 'Trading, portefeuille de négociation',
          'Quantité': 1000,
          'Cours actuel': 10000,
        }),
        _equity({
          'Emetteur': 'BOA',
          'Intention comptable': 'AFS, disponible à la vente',
          'Quantité': 1000,
          'Cours actuel': 4000,
        }),
        _equity({
          'Emetteur': 'FILIALE',
          'Intention comptable': 'Titres de participation, portefeuille '
              'bancaire',
          'Quantité': 1000,
          'Cours actuel': 6000,
        }),
      ]);

      expect(dataset.totalMarketValueXof, 20000000);
      expect(dataset.tradingBookValueXof, 10000000);
      expect(dataset.bankingBookValueXof, 10000000);
    });

    test('intention comptable absente : la ligne reste dans l\'assiette', () {
      final dataset = _dataset([
        _equity({
          'Emetteur': 'SANS INTENTION',
          'Quantité': 100,
          'Cours actuel': 1000,
        }),
      ]);

      expect(dataset.tradingBookValueXof, 100000);
      expect(dataset.bankingBookValueXof, 0);
    });

    test('la ventilation par devise couvre toute la valeur de marché', () {
      final dataset = _dataset([
        _equity({
          'Emetteur': 'LOCALE',
          'Devise': 'XOF',
          'Quantité': 1000,
          'Cours actuel': 5000,
        }),
        _equity({
          'Emetteur': 'AUTRE LOCALE',
          'Devise': 'XOF',
          'Quantité': 1000,
          'Cours actuel': 3000,
        }),
      ]);

      expect(dataset.valueByCurrencyXof, {'XOF': 8000000.0});
      expect(dataset.foreignCurrencyValueXof, 0);
      expect(
        dataset.valueByCurrencyXof.values.fold<double>(0, (a, b) => a + b),
        dataset.totalMarketValueXof,
      );
    });

    test('le dividende attendu applique le rendement à la valeur de marché',
        () {
      final dataset = _dataset([
        _equity({
          'Emetteur': 'DISTRIBUTRICE',
          'Quantité': 1000,
          'Cours actuel': 10000,
          'Rendement dividende (%)': 6,
        }),
        _equity({
          'Emetteur': 'SANS DIVIDENDE',
          'Quantité': 1000,
          'Cours actuel': 10000,
        }),
      ]);

      // 6 % de 10 000 000, la seconde ligne ne distribuant rien.
      expect(dataset.expectedDividendIncomeXof, 600000);
      // Rendement pondéré sur l'ensemble du portefeuille, pas sur les seules
      // lignes distributrices : 600 000 / 20 000 000.
      expect(dataset.weightedDividendYield, moreOrLessEquals(0.03));
    });

    test('aucun dividende déclaré : portage nul, pas d\'extrapolation', () {
      final dataset = _dataset([
        _equity({
          'Emetteur': 'SANS DIVIDENDE',
          'Quantité': 1000,
          'Cours actuel': 10000,
        }),
      ]);

      expect(dataset.expectedDividendIncomeXof, 0);
      expect(dataset.weightedDividendYield, 0);
    });
  });

  group('Profil de risque consolide par emetteur', () {
    test(
        'un émetteur portant plusieurs lignes n\'occupe qu\'un rang, '
        'avec un bêta pondéré par la valeur de marché', () {
      final portefeuille = _dataset([
        _equity({
          'Emetteur': 'Atlantis Maritime SA',
          'Quantité': 1000,
          'Cours actuel': 10000,
          'Bêta': 1.0,
          'Rendement dividende (%)': 6,
        }),
        _equity({
          'Emetteur': 'Atlantis Maritime SA',
          'Quantité': 3000,
          'Cours actuel': 10000,
          'Bêta': 1.4,
          'Rendement dividende (%)': 2,
        }),
        _equity({
          'Emetteur': 'Nokoué Ciments SA',
          'Quantité': 500,
          'Cours actuel': 10000,
          'Bêta': 0.8,
        }),
      ]);

      final profils = portefeuille.riskProfileByIssuer;

      // Deux emetteurs pour trois lignes : le tableau annoncait « par
      // emetteur » tout en listant les lignes.
      expect(profils.length, 2);
      expect(profils.first.issuer, 'Atlantis Maritime SA');
      expect(profils.first.marketValue, 40000000);

      // (1,0 x 10 + 1,4 x 30) / 40 = 1,30
      expect(profils.first.beta, moreOrLessEquals(1.30, epsilon: 1e-9));
      // (6 % x 10 + 2 % x 30) / 40 = 3 %
      expect(profils.first.dividendYield, moreOrLessEquals(0.03, epsilon: 1e-9));
    });

    test('le classement suit la valeur de marche consolidee', () {
      final portefeuille = _dataset([
        _equity({
          'Emetteur': 'PETITE A',
          'Quantité': 100,
          'Cours actuel': 10000,
        }),
        _equity({
          'Emetteur': 'PETITE A',
          'Quantité': 100,
          'Cours actuel': 10000,
        }),
        _equity({
          'Emetteur': 'GROSSE B',
          'Quantité': 150,
          'Cours actuel': 10000,
        }),
      ]);

      // 200 lignes cumulees contre 150 : la consolidation fait passer
      // PETITE A devant, alors que ligne par ligne elle etait derriere.
      expect(portefeuille.riskProfileByIssuer.first.issuer, 'PETITE A');
    });

    test('une ligne sans beta ne fausse pas la moyenne de son emetteur', () {
      final portefeuille = _dataset([
        _equity({
          'Emetteur': 'A',
          'Quantité': 1000,
          'Cours actuel': 10000,
          'Bêta': 1.2,
        }),
        _equity({
          'Emetteur': 'A',
          'Quantité': 1000,
          'Cours actuel': 10000,
        }),
      ]);

      // La ligne sans beta ne contribue pas au numerateur mais pese au
      // denominateur : 1,2 x 10 / 20 = 0,6.
      expect(
        portefeuille.riskProfileByIssuer.first.beta,
        moreOrLessEquals(0.6, epsilon: 1e-9),
      );
    });
  });
}
