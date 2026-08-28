// Ce que le formulaire « Ajouter un exercice antérieur » envoie réellement.
//
// La base ne gardait qu'une ligne malgré plusieurs saisies d'exercices
// antérieurs : le serveur exigeait pourtant un millésime, donc l'interface en
// envoyait bien un — mais lequel ? Les captures d'écran ne le disent pas.
// Cet essai intercepte l'appel et lit l'exercice transmis.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/core/services/rwa_api_service.dart';
import 'package:rwa_calculator/modules/dashboard/models/dashboard_models.dart';
import 'package:rwa_calculator/modules/dashboard/screens/fonds_propres_exercice_dialog.dart';

/// Retient la mise à jour au lieu de l'envoyer.
class _ApiEspion extends RwaApiService {
  _ApiEspion() : super(baseUrl: 'http://127.0.0.1:1');

  FondsPropresUpdate? recue;

  @override
  Future<DashboardSnapshot> updateFondsPropres(
      FondsPropresUpdate update) async {
    recue = update;
    return DashboardSnapshot(
      metrics: const [],
      valuationDate: DateTime(2026, 6, 30),
      categoryDistribution: const [],
      rwaTypeDistribution: const [],
      rwaCategoryDistribution: const [],
      countryDistribution: const [],
      crmDistribution: const [],
      ratingDistribution: const [],
      rwaProjection: const [],
      portfolioOverview: const [],
    );
  }
}

Future<void> _ouvrir(
  WidgetTester tester,
  _ApiEspion api, {
  required List<int> anneesPrises,
  int? exerciceEnCours,
  FondsPropresExercice? initial,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => FondsPropresExerciceDialog.ouvrir(
              context,
              api,
              initial: initial,
              anneesPrises: anneesPrises,
              exerciceEnCours: exerciceEnCours,
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("l'exercice proposé est l'année libre, pas l'exercice en cours",
      (tester) async {
    final api = _ApiEspion();
    await _ouvrir(tester, api, anneesPrises: [2026], exerciceEnCours: 2026);

    // Le champ s'ouvre sur 2025 : le millésime libre le plus récent.
    // `widgetWithText` attraperait aussi l'indication du champ, qui vaut
    // « 2025 » elle aussi : on lit donc le contrôleur du premier champ.
    final champ = tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(champ.controller?.text, '2025');
  });

  testWidgets("l'enregistrement transmet bien l'exercice antérieur",
      (tester) async {
    final api = _ApiEspion();
    await _ouvrir(tester, api, anneesPrises: [2026], exerciceEnCours: 2026);

    await tester.enterText(find.byType(TextFormField).first, '2025');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(api.recue, isNotNull, reason: "l'appel n'a pas eu lieu");
    expect(api.recue!.exercice, 2025,
        reason: "c'est l'exercice antérieur qui doit être visé, pas 2026");
  });

  testWidgets('viser l’exercice en cours est signalé', (tester) async {
    final api = _ApiEspion();
    await _ouvrir(tester, api, anneesPrises: [2026], exerciceEnCours: 2026);

    await tester.enterText(find.byType(TextFormField).first, '2026');
    await tester.pumpAndSettle();

    expect(
      find.textContaining('remplacera les fonds propres en cours'),
      findsOneWidget,
      reason: 'écraser l’exercice déclaré ne doit pas être silencieux',
    );
  });

  testWidgets('une année déjà enregistrée est refusée', (tester) async {
    final api = _ApiEspion();
    await _ouvrir(tester, api, anneesPrises: [2026, 2025], exerciceEnCours: 2026);

    await tester.enterText(find.byType(TextFormField).first, '2025');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Cet exercice est déjà enregistré'), findsOneWidget);
    expect(api.recue, isNull, reason: 'rien ne doit partir au serveur');
  });
}
