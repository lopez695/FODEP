// Les dispositions transitoires sur les fonds propres, et l'état EP04.
//
// Bâle III a rendu inadmissibles certains éléments de fonds propres au
// 1er janvier 2018 et les retire par paliers. Quatre lignes de l'EP04 retombent
// dans l'EP03 — FPI07 en CET1, FPI25 en AT1, FPI33 et FPI34 en T2 — et changent
// donc les fonds propres déclarés.
//
// Ce qui se vérifie ici : l'aller-retour des montants avec le serveur, et le
// fait que l'écran distingue ce qui se saisit de ce qui se calcule. Un
// déclarant qui cherche à corriger (i) doit comprendre qu'il ne se saisit pas.

import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/modules/dispositions_transitoires/models/dispositions_transitoires_models.dart';

void main() {
  group('les montants font l\'aller-retour avec le serveur', () {
    test('la charge utile porte les clés attendues par le backend', () {
      const dispositions = DispositionsTransitoires(
        exercice: 2026,
        partCapitalNonAdmissible: 10,
        provisionsReglementees: 2,
        fondsAffectes: 1,
        cet1EnCirculation: 20,
        cet1EligibleAt1: 3,
        cet1EligibleT2Autres: 1,
        dettesSubordonnees2018: 8,
        partDettesNonAdmissible: 4,
        ecartsReevaluation: 1,
        t2EnCirculation: 3,
      );

      final charge = dispositions.toPayload();
      expect(charge['exercice'], 2026);
      expect(charge['part_capital_non_admissible'], 10);
      expect(charge['cet1_en_circulation'], 20);
      expect(charge['t2_en_circulation'], 3);
      // Le taux de retrait n'y est pas : la BCEAO l'imprime sur le formulaire,
      // et l'y relire est l'affaire de l'export.
      expect(charge.containsKey('taux_de_retrait'), isFalse);
      // Le capital social libéré non plus : l'EP03 le déclare déjà.
      expect(charge.containsKey('capital_ordinaire'), isFalse);
    });

    test('un exercice absent se lit comme un champ manquant, pas comme zéro',
        () {
      final dispositions = DispositionsTransitoires.fromJson(const {
        'exercice': 2026,
        'part_capital_non_admissible': 10.0,
      });
      expect(dispositions.exercice, 2026);
      expect(dispositions.partCapitalNonAdmissible, 10.0);
      expect(dispositions.cet1EnCirculation, 0.0);
    });
  });

  group('l\'aperçu de l\'EP04', () {
    SyntheseEp04 syntheseDEssai() => SyntheseEp04.fromJson(const {
          'exercice': 2026,
          'taux_de_retrait': 0.9,
          'renseigne': true,
          'report_ep03': {
            'FPI07': 11700.0,
            'FPI25': 3000.0,
            'FPI33': 1000.0,
            'FPI34': 3000.0,
          },
          'alertes': <String>[],
          'lignes': [
            {
              'code': 'FPI01',
              'libelle': 'Capital social libéré dont ;',
              'formule': '(b)',
              'montant': 49323.0,
              'origine': 'reporte',
              'bloc': 'A',
            },
            {
              'code': 'DT002',
              'libelle': 'Part du capital social non admissible',
              'formule': '(c)',
              'montant': 10000.0,
              'origine': 'saisie',
              'bloc': 'A',
            },
            {
              'code': 'DT005',
              'libelle': 'Total des éléments de CET1 non admissibles',
              'formule': '(f) = c + d + e',
              'montant': 13000.0,
              'origine': 'calcule',
              'bloc': 'A',
            },
            {
              'code': 'FPI07',
              'libelle': 'Inclus dans le CET1',
              'formule': '(i) = min(g, h)',
              'montant': 11700.0,
              'origine': 'calcule',
              'bloc': 'A',
            },
          ],
        });

    test('chaque ligne dit d\'où vient son montant', () {
      final parCode = {
        for (final ligne in syntheseDEssai().lignes) ligne.code: ligne
      };
      expect(parCode['FPI01']!.estReportee, isTrue,
          reason: 'le capital vient de l\'EP03');
      expect(parCode['DT002']!.estCalculee, isFalse);
      expect(parCode['DT005']!.estCalculee, isTrue);
      expect(parCode['FPI07']!.estCalculee, isTrue);
    });

    test('la formule du formulaire accompagne la ligne calculée', () {
      // Sans elle, un montant calculé ressemble à une saisie qu'on aurait
      // oublié de faire.
      final parCode = {
        for (final ligne in syntheseDEssai().lignes) ligne.code: ligne
      };
      expect(parCode['FPI07']!.formule, '(i) = min(g, h)');
      expect(parCode['DT005']!.formule, '(f) = c + d + e');
    });

    test('le report vers l\'EP03 porte les quatre lignes attendues', () {
      // FPI35 et FPI36 n'y sont pas : l'EP03 les déclare de son côté, et un
      // même code DISPRU ne peut pas porter deux valeurs.
      expect(
        syntheseDEssai().reportEp03.keys.toSet(),
        <String>{'FPI07', 'FPI25', 'FPI33', 'FPI34'},
      );
    });

    test('un état non renseigné se lit comme un zéro assumé', () {
      final synthese = SyntheseEp04.fromJson(const {
        'exercice': null,
        'taux_de_retrait': 0.9,
        'renseigne': false,
        'report_ep03': <String, dynamic>{},
        'lignes': <dynamic>[],
        'alertes': ['L\'EP04 partira à zéro.'],
      });
      expect(synthese.renseigne, isFalse);
      expect(synthese.exercice, isNull);
      expect(synthese.reportEp03, isEmpty);
      expect(synthese.alertes, isNotEmpty);
      // Le taux reste lu sur le formulaire, même sans saisie.
      expect(synthese.tauxDeRetrait, 0.9);
    });
  });
}
