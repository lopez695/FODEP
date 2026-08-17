import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';

void main() {
  group('Bond reconstructed CRD', () {
    test('reconstructs active constant profile with linear principal', () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'CP0003',
          'Capital initial': 22605972280,
          'Profil d\'amortissement': 'constant',
          'Fréquence de paiement des intérêts': 'Semestrielle',
          'Maturité (mois)': 180,
          'Maturité résiduelle (mois)': 156,
          'Coupon (%)': 0.049,
        },
      );

      const expectedCapital = 22605972280 * 26 / 30;
      expect(
        record.resolvedCapitalRemainingDue,
        moreOrLessEquals(expectedCapital, epsilon: 0.01),
      );
      expect(
        record.capitalAlreadyRepaid,
        moreOrLessEquals(22605972280 - expectedCapital, epsilon: 0.01),
      );
    });

    test('reconstructs active constant annuity profile after paid periods', () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'CP0007',
          'Capital initial': 82474291920,
          'Profil d\'amortissement': 'annuité constante',
          'Fréquence de paiement des intérêts': 'Trimestrielle',
          'Maturité (mois)': 144,
          'Maturité résiduelle (mois)': 116,
          'Coupon (%)': 0.0965,
        },
      );

      expect(
        record.resolvedCapitalRemainingDue,
        moreOrLessEquals(73252186595.82242, epsilon: 0.01),
      );
      expect(
        record.capitalAlreadyRepaid,
        moreOrLessEquals(9222105324.17758, epsilon: 0.01),
      );
    });

    test('reconstructs active short monthly Treasury bill with linear profile',
        () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'CP0344',
          'Type d\'instrument': 'Bon du trésor - BT',
          'Code type d\'instrument': 'BT',
          'Capital initial': 3360715988,
          'Profil d\'amortissement': 'constant',
          'Fréquence de paiement des intérêts': 'Mensuelle',
          'Maturité (mois)': 36,
          'Maturité résiduelle (mois)': 23,
          'Coupon (%)': 0.0862,
        },
      );

      const expectedCapital = 3360715988 * 23 / 36;
      expect(
        record.resolvedCapitalRemainingDue,
        moreOrLessEquals(expectedCapital, epsilon: 0.01),
      );
      expect(
        record.capitalAlreadyRepaid,
        moreOrLessEquals(3360715988 - expectedCapital, epsilon: 0.01),
      );
    });

    test('reconstructs active long monthly Treasury bill with linear profile',
        () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'CP0138',
          'Type d\'instrument': 'Bon du trésor - BT',
          'Code type d\'instrument': 'BT',
          'Capital initial': 32558786099,
          'Profil d\'amortissement': 'constant',
          'Fréquence de paiement des intérêts': 'Mensuelle',
          'Maturité (mois)': 156,
          'Maturité résiduelle (mois)': 146,
          'Coupon (%)': 0.0854,
        },
      );

      const expectedCapital = 32558786099 * 146 / 156;
      expect(
        record.resolvedCapitalRemainingDue,
        moreOrLessEquals(expectedCapital, epsilon: 0.01),
      );
    });

    test('derives maturities from dates before imported month columns', () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'Date d\'analyse': DateTime(2026, 6, 1),
          'Date d\'émission': DateTime(2024, 1, 1),
          'Date d\'échéance': DateTime(2032, 1, 1),
          'Maturité (mois)': 1,
          'Maturité résiduelle (mois)': 1,
        },
      );

      expect(record.maturityMonths, 96);
      expect(record.residualMaturityMonths, 67);
      expect(record.isActiveAtAnalysisDate, isTrue);
    });

    test('sets matured bonds outstanding capital to zero', () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'Date d\'analyse': DateTime(2026, 6, 1),
          'Date d\'émission': DateTime(2024, 1, 1),
          'Date d\'échéance': DateTime(2026, 6, 1),
          'Capital initial': 1000000000,
          'Profil d\'amortissement': 'In fine',
          'Fréquence de paiement des intérêts': 'Annuelle',
        },
      );

      expect(record.isMaturedAtAnalysisDate, isTrue);
      expect(record.residualMaturityMonths, 0);
      expect(record.resolvedCapitalRemainingDue, 0);
    });

    test('keeps present value distinct from active capital', () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'Capital initial': 1000000000,
          'Valeur actualisée': 950000000,
        },
      );

      expect(record.resolvedCapitalRemainingDue, 1000000000);
      expect(record.presentValue, 950000000);
    });

    test('builds issuer analysis identity from country and issuer', () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'Pays émetteur': 'Côte d\'Ivoire',
          'Emetteur': 'Trésor public',
        },
      );

      expect(record.issuerCountryIso3, 'CIV');
      // La clé est CANONIQUE : casse, accents et ponctuation neutralisés,
      // pour que deux graphies du même émetteur ne comptent pas double dans
      // les classements de concentration.
      expect(record.issuerAnalysisKey, 'CIV|TRESOR PUBLIC');
      // Le libellé, lui, reste le nom du fichier : la clé ne s'affiche pas.
      expect(record.issuerAnalysisLabel, 'Trésor public (CIV)');
    });

    test('deux graphies du même émetteur partagent la clé d\'analyse', () {
      MarketPortfolioRecord bon(String emetteur) => MarketPortfolioRecord(
            portfolioType: MarketPortfolioType.bonds,
            values: {
              'Pays émetteur': 'Côte d\'Ivoire',
              'Emetteur': emetteur,
            },
          );

      expect(
        bon('TRESOR PUBLIC S.A.').issuerAnalysisKey,
        bon('Trésor public SA').issuerAnalysisKey,
      );
    });

    test('zero coupon profile does not create coupon cashflows', () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'Profil d\'amortissement': 'Zéro coupon',
          'Fréquence de paiement des intérêts': 'Semestrielle',
          'Maturité résiduelle (mois)': 60,
          'Valeur nominale unitaire': 100,
          'quantités': 1,
          'Coupon (%)': 0.05,
        },
      );

      expect(record.bondMacaulayDuration, moreOrLessEquals(5, epsilon: 1e-9));
      expect(
        record.bondModifiedDuration,
        moreOrLessEquals(5 / (1 + 0.05 / 2), epsilon: 1e-9),
      );
      expect(
        record.bondCashflowPresentValue,
        moreOrLessEquals(100 /
            (1.025 *
                1.025 *
                1.025 *
                1.025 *
                1.025 *
                1.025 *
                1.025 *
                1.025 *
                1.025 *
                1.025)),
      );
    });

    test('redemption price does not reduce principal cashflow', () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'Profil d\'amortissement': 'Zéro coupon',
          'Fréquence de paiement des intérêts': 'Annuelle',
          'Maturité résiduelle (mois)': 12,
          'Valeur nominale unitaire': 100,
          'quantités': 1,
          'Coupon (%)': 0,
          'Prix de remboursement': 40,
          'Prime de remboursement': -60,
        },
      );

      expect(record.bondCashflowPresentValue, moreOrLessEquals(100));
    });
  });

  group('Market data snapshot architecture', () {
    test('dataset content signature ignores technical import timestamp', () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'CP0001',
          'Capital initial': 1000000000,
          'Coupon (%)': 0.05,
        },
      );
      final first = MarketPortfolioDataset(
        portfolioType: MarketPortfolioType.bonds,
        fileName: 'base.xlsx',
        importedAt: DateTime(2026, 6),
        headers: const ['ID Titre', 'Capital initial', 'Coupon (%)'],
        records: [record],
      );
      final restored = MarketPortfolioDataset(
        portfolioType: MarketPortfolioType.bonds,
        fileName: 'base.xlsx',
        importedAt: DateTime(2026, 6, 2, 12),
        headers: const ['ID Titre', 'Capital initial', 'Coupon (%)'],
        records: [record],
      );

      expect(first.contentSignature, restored.contentSignature);
      expect(
        MarketDataSnapshot.fromDatasets({
          MarketPortfolioType.bonds: first,
        }).contentSignature,
        MarketDataSnapshot.fromDatasets({
          MarketPortfolioType.bonds: restored,
        }).contentSignature,
      );
    });

    test('dataset content signature changes when portfolio content changes',
        () {
      final first = MarketPortfolioDataset(
        portfolioType: MarketPortfolioType.bonds,
        fileName: 'base.xlsx',
        importedAt: DateTime(2026, 6),
        headers: const ['ID Titre', 'Capital initial'],
        records: [
          MarketPortfolioRecord(
            portfolioType: MarketPortfolioType.bonds,
            values: {
              'ID Titre': 'CP0001',
              'Capital initial': 1000000000,
            },
          ),
        ],
      );
      final changed = MarketPortfolioDataset(
        portfolioType: MarketPortfolioType.bonds,
        fileName: 'base.xlsx',
        importedAt: DateTime(2026, 6),
        headers: const ['ID Titre', 'Capital initial'],
        records: [
          MarketPortfolioRecord(
            portfolioType: MarketPortfolioType.bonds,
            values: {
              'ID Titre': 'CP0001',
              'Capital initial': 1200000000,
            },
          ),
        ],
      );

      expect(first.contentSignature, isNot(changed.contentSignature));
    });
  });

  group('Market prudential capital', () {
    test('applies zero specific risk and maturity general risk to UEMOA bonds',
        () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'TPCI-2032',
          'Pays émetteur': 'Côte d\'Ivoire',
          'Type d\'instrument': 'Obligation du trésor',
          'Code type d\'instrument': 'OT',
          'Emetteur': 'Trésor public',
          'Devise': 'XOF',
          'Capital initial': 1000000000,
          'Profil d\'amortissement': 'In fine',
          'Fréquence de paiement des intérêts': 'Annuelle',
          'Maturité résiduelle (mois)': 72,
          'Coupon (%)': 0.05,
        },
      );

      final result = calculateMarketPrudentialCapital(records: [record]);

      expect(result.interestRateSpecificRisk, 0);
      expect(
        result.interestRateGeneralRisk,
        moreOrLessEquals(32500000, epsilon: 0.01),
      );
      // Équivalent RWA = exigence × 12,5 (§90), et non 1/0,09.
      expect(
        result.marketRwa,
        moreOrLessEquals(406250000, epsilon: 0.01),
      );
    });

    test('converts equity specific and general requirements into market RWA',
        () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.equities,
        values: {
          'ID Instrument': 'EQ-001',
          'Émetteur / Société': 'Société cotée',
          'Devise': 'XOF',
          'Quantité': 1000,
          'Cours actuel': 100000,
          'Valeur de marché': 100000000,
        },
      );

      final result = calculateMarketPrudentialCapital(records: [record]);

      // Actions : 8 % du net par émetteur (Art. 399) + 8 % du net par marché
      // (Art. 401). L'équivalent RWA vaut la position elle-même, 8 % × 12,5 = 1.
      expect(result.equitySpecificRisk, 8000000);
      expect(result.equityGeneralRisk, 8000000);
      expect(result.capitalRequirement, 16000000);
      expect(result.marketRwa, moreOrLessEquals(200000000, epsilon: 0.01));
    });

    test('measures non-XOF open currency positions at spot-equivalent value',
        () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.equities,
        values: {
          'ID Instrument': 'USD-001',
          'Émetteur / Société': 'USD listed issuer',
          'Devise': 'USD',
          'Quantité': 10,
          'Cours actuel': 100,
          'Valeur de marché': 1000,
        },
      );

      final result = calculateMarketPrudentialCapital(records: [record]);

      expect(result.foreignExchangeGlobalNetPosition, 600000);
      // Change : 8 % de la position nette globale (Art. 417).
      expect(result.foreignExchangeRisk, 48000);
    });

    test('excludes banking-book (HTM) bonds from interest rate risk (Art. 321)',
        () {
      Map<String, Object?> bond(String intent) => {
            'ID Titre': 'TPCI-2032',
            'Pays émetteur': 'Côte d\'Ivoire',
            'Type d\'instrument': 'Obligation du trésor',
            'Code type d\'instrument': 'OT',
            'Emetteur': 'Trésor public',
            'Devise': 'XOF',
            'Capital initial': 1000000000,
            'Profil d\'amortissement': 'In fine',
            'Fréquence de paiement des intérêts': 'Annuelle',
            'Maturité résiduelle (mois)': 72,
            'Coupon (%)': 0.05,
            'Intention comptable': intent,
          };

      final htm = calculateMarketPrudentialCapital(records: [
        MarketPortfolioRecord(
            portfolioType: MarketPortfolioType.bonds, values: bond('HTM')),
      ]);
      expect(htm.interestRateGeneralRisk, 0);

      final trading = calculateMarketPrudentialCapital(records: [
        MarketPortfolioRecord(
            portfolioType: MarketPortfolioType.bonds, values: bond('Trading')),
      ]);
      expect(
        trading.interestRateGeneralRisk,
        moreOrLessEquals(32500000, epsilon: 0.01),
      );
    });

    test(
        'applies the 4% specific equity rate when liquid and diversified '
        '(Art. 399)', () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.equities,
        values: {
          'ID Instrument': 'EQ-001',
          'Émetteur / Société': 'Société cotée',
          'Devise': 'XOF',
          'Quantité': 1000,
          'Cours actuel': 100000,
          'Valeur de marché': 100000000,
        },
      );

      final result = calculateMarketPrudentialCapital(
        records: [record],
        equityPortfolioLiquidAndDiversified: true,
      );

      expect(result.equitySpecificRisk, 4000000); // 4 % × 100M (Art. 399)
      expect(result.equityGeneralRisk, 8000000); // général reste à 8 % (Art. 401)
    });

    test('nets equity positions per issuer (specific) and per market (general)',
        () {
      final long = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.equities,
        values: {
          'Émetteur / Société': 'Émetteur A',
          'Devise': 'XOF',
          'Valeur de marché': 100000000,
        },
      );
      final short = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.equities,
        values: {
          'Émetteur / Société': 'Émetteur B',
          'Devise': 'XOF',
          'Sens': 'Vente',
          'Valeur de marché': 100000000,
        },
      );

      final result = calculateMarketPrudentialCapital(records: [long, short]);

      // Spécifique : Σ|net par émetteur| = 200M → 8 % = 16M (Art. 399)
      expect(result.equitySpecificRisk, 16000000);
      // Général : net du marché XOF = +100M − 100M = 0 → 0 (Art. 401)
      expect(result.equityGeneralRisk, 0);
    });
  });
}
