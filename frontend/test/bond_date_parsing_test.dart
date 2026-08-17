import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';

void main() {
  group('Analyse des dates de titre (issueDate/maturityDate)', () {
    test(
        'dates ISO (AAAA-MM-JJ) correctement interprétées : maturité totale '
        'et résiduelle cohérentes entre elles', () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'CI-OTA-001',
          'Date d\'émission': '2024-01-30',
          'Date d\'échéance': '2029-01-30',
          'Date d\'analyse': DateTime(2026, 7, 17),
        },
      );

      expect(record.issueDate, DateTime(2024, 1, 30));
      expect(record.maturityDate, DateTime(2029, 1, 30));
      // 5 ans pile entre émission et échéance = 60 mois, pas ~1 mois.
      expect(record.maturityMonths, closeTo(60, 1));
      // La résiduelle ne doit jamais dépasser la maturité totale.
      expect(record.residualMaturityMonths,
          lessThanOrEqualTo(record.maturityMonths));
    });

    test('dates au format européen (JJ/MM/AAAA) toujours interprétées correctement',
        () {
      final record = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'EU-TEST',
          'Date d\'émission': '30/01/2024',
          'Date d\'échéance': '30/01/2029',
          'Date d\'analyse': DateTime(2026, 7, 17),
        },
      );

      expect(record.issueDate, DateTime(2024, 1, 30));
      expect(record.maturityDate, DateTime(2029, 1, 30));
      expect(record.maturityMonths, closeTo(60, 1));
    });
  });
}
