import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/modules/participations/models/participation_models.dart';

void main() {
  group('suggererNumeroCentraleRisques', () {
    test('prolonge la série en conservant préfixe et longueur', () {
      expect(
        suggererNumeroCentraleRisques(['CR-001', 'CR-002']),
        'CR-003',
      );
    });

    test('repart du plus grand numéro, quel que soit l\'ordre', () {
      // La base réelle mélange les séries : CR-101 côtoie CR-002.
      expect(
        suggererNumeroCentraleRisques(['CR-101', 'CR-002']),
        'CR-102',
      );
    });

    test('conserve le remplissage par des zéros', () {
      expect(suggererNumeroCentraleRisques(['GR-009']), 'GR-010');
      expect(suggererNumeroCentraleRisques(['GR-0009']), 'GR-0010');
    });

    test('accepte un numéro sans préfixe', () {
      expect(suggererNumeroCentraleRisques(['7']), '8');
    });

    test('ignore les valeurs vides et non numérotées', () {
      expect(
        suggererNumeroCentraleRisques([null, '', '  ', 'SANS-NUMERO', 'CR-004']),
        'CR-005',
      );
    });

    test('ne propose rien quand aucune série n\'existe', () {
      // Inventer une série serait pire que ne rien proposer : le numéro est
      // attribué par la Centrale des risques, pas par l'établissement.
      expect(suggererNumeroCentraleRisques([]), '');
      expect(suggererNumeroCentraleRisques([null, 'ABC']), '');
    });
  });
}
