// Le panneau de suivi juxtaposait un encours (bilan seul) et un RWA calculé
// sur une assiette plus large : le rapprochement était impossible à l'œil.
// Ces tests fixent la chaîne de calcul affichée et, surtout, interdisent de
// présenter « encours + hors bilan » comme l'assiette pondérée lorsqu'un
// facteur de conversion ou une garantie financée la modifie.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/core/services/rwa_api_service.dart';
import 'package:rwa_calculator/modules/expositions/models/suivi_versements_models.dart';
import 'package:rwa_calculator/modules/expositions/widgets/suivi_versements_dialog.dart';

/// Sert un suivi figé : les tests portent sur l'affichage, pas sur le réseau.
class _FakeApi extends RwaApiService {
  _FakeApi(this.payload) : super(baseUrl: 'http://127.0.0.1:1');

  final Map<String, dynamic> payload;

  @override
  Future<ExpositionSuivi> fetchExpositionSuivi(String exposureId) async {
    return ExpositionSuivi.fromJson(payload);
  }
}

Map<String, dynamic> _suivi({
  required double encours,
  required double montantInitial,
  required double horsBilan,
  required double totalVerse,
  required double ead,
  required double ponderation,
  required double rwa,
}) {
  return <String, dynamic>{
    'exposure_id': 'EXP-2026-0050',
    'counterparty_name': 'Afriland First Bank',
    'statut_prudentiel': 'saine',
    'jours_impayes': 0,
    'jours_impayes_suivis': true,
    'seuil_jours_souffrance': 90,
    'declassement_manuel': false,
    'periode_courante': '2026-07',
    'date_octroi': '2025-05-11',
    'date_echeance': '2028-10-23',
    'notation': 'BBB',
    'devise': 'XOF',
    'encours': encours,
    'montant_initial': montantInitial,
    'montant_hors_bilan': horsBilan,
    'total_verse': totalVerse,
    'ead': ead,
    'ponderation': ponderation,
    'rwa': rwa,
    'entries': <dynamic>[],
    'journal': <dynamic>[],
  };
}

Future<void> _pump(WidgetTester tester, Map<String, dynamic> payload) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuiviVersementsDialog(
          api: _FakeApi(payload),
          exposureId: 'EXP-2026-0050',
          counterpartyName: 'Afriland First Bank',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('la chaîne encours → EAD → RWA est posée terme à terme',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(
      tester,
      _suivi(
        encours: 44499900,
        montantInitial: 44500000,
        horsBilan: 8500000,
        totalVerse: 100,
        ead: 52999900,
        ponderation: 0.5,
        rwa: 26499950,
      ),
    );

    // Chaque terme du calcul est nommé : l'encours amorti ne côtoie plus un
    // RWA dont l'assiette resterait invisible.
    expect(find.text('Encours initial'), findsOneWidget);
    expect(find.text('Total versé'), findsOneWidget);
    expect(find.text('Encours actuel'), findsOneWidget);
    expect(find.text('Hors bilan'), findsOneWidget);
    expect(find.text('Assiette pondérée'), findsOneWidget);
    expect(find.text('Pondération'), findsOneWidget);
    expect(find.text('RWA'), findsOneWidget);
    expect(find.text('50 %'), findsOneWidget);

    // Assiette additive : les opérateurs annoncent une somme vérifiable.
    expect(find.text('−'), findsOneWidget);
    expect(find.text('+'), findsOneWidget);
    expect(find.text('×'), findsOneWidget);
    expect(find.text('='), findsNWidgets(3));
    expect(
      find.textContaining('ne se lit pas comme la somme'),
      findsNothing,
    );
  });

  testWidgets("une assiette réduite par une garantie n'est pas présentée "
      'comme une somme', (tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Cas réel EXP-2026-0077 : ARC financée, l'assiette (109,6 M) est très
    // inférieure à encours + hors bilan (369 M).
    await _pump(
      tester,
      _suivi(
        encours: 331500000,
        montantInitial: 331500000,
        horsBilan: 37500000,
        totalVerse: 0,
        ead: 109629676.56,
        ponderation: 1.5,
        rwa: 164444514.84,
      ),
    );

    expect(find.text('Assiette pondérée'), findsOneWidget);
    // Aucun « + ... = » trompeur, et la raison est écrite.
    expect(find.text('+'), findsNothing);
    expect(find.textContaining('ne se lit pas comme la somme'), findsOneWidget);

    // Sans versement enregistré, la ligne ne s'encombre pas d'une soustraction
    // à zéro.
    expect(find.text('Encours initial'), findsNothing);
    expect(find.text('Total versé'), findsNothing);
    expect(find.text('Encours actuel'), findsOneWidget);
  });

  testWidgets('une ligne sans hors bilan garde une chaîne courte',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(
      tester,
      _suivi(
        encours: 9000000,
        montantInitial: 10000000,
        horsBilan: 0,
        totalVerse: 1000000,
        ead: 9000000,
        ponderation: 1.0,
        rwa: 9000000,
      ),
    );

    expect(find.text('Hors bilan'), findsNothing);
    expect(find.text('Encours actuel'), findsOneWidget);
    expect(find.text('Assiette pondérée'), findsOneWidget);
    expect(find.text('100 %'), findsOneWidget);
  });
}
