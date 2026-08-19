// L'État de l'attestation se choisit dans une liste, il ne se tape pas.
//
// Le FODEP est la déclaration prudentielle de l'UMOA : la case n'a que huit
// réponses possibles. Laissée en saisie libre, elle exposait la déclaration à
// la faute de frappe sur la valeur qui l'identifie.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/core/services/rwa_api_service.dart';
import 'package:rwa_calculator/modules/rapports/models/report_models.dart';
import 'package:rwa_calculator/modules/rapports/screens/saisies_fodep_page.dart';

const List<String> _paysUemoa = [
  'Bénin',
  'Burkina Faso',
  "Côte d'Ivoire",
  'Guinée-Bissau',
  'Mali',
  'Niger',
  'Sénégal',
  'Togo',
];

/// API qui sert la case « État » telle que le backend la décrit, avec ses
/// choix, et l'« Établissement » à côté pour vérifier qu'elle reste libre.
class _ApiBouchonnee extends RwaApiService {
  _ApiBouchonnee() : super(baseUrl: 'http://127.0.0.1:1');

  @override
  Future<SaisiesFodep> fetchSaisiesFodep() async => SaisiesFodep.fromJson(
        <String, dynamic>{
          'etats': [
            {
              'etat': 'ADPE',
              'intitule': 'Attestation de déclaration prudentielle',
              'obligatoire': true,
              'renseignees': 0,
              'cases': [
                {
                  'etat': 'ADPE',
                  'cellule': 'C5',
                  'ligne': 0,
                  'code': 'Identification',
                  'libelle': 'État',
                  'colonne': '',
                  'type_saisie': 'pays',
                  'choix': _paysUemoa,
                  'texte': null,
                  'valeur': null,
                },
                {
                  'etat': 'ADPE',
                  'cellule': 'T5',
                  'ligne': 1,
                  'code': 'Identification',
                  'libelle': 'Établissement',
                  'colonne': '',
                  'type_saisie': 'texte',
                  'texte': null,
                  'valeur': null,
                },
              ],
            },
          ],
          'total_cases': 2,
          'total_renseignees': 0,
        },
      );
}

Future<void> _ouvrirLaSaisie(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => SaisiesFodepPage.ouvrir(context, _ApiBouchonnee()),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("l'État se choisit parmi les huit membres de l'Union",
      (tester) async {
    await _ouvrirLaSaisie(tester);

    // La case est une liste, pas une ligne de frappe.
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    for (final pays in _paysUemoa) {
      expect(find.text(pays), findsWidgets, reason: pays);
    }
    // Et de quoi revenir en arrière : une case choisie par erreur se vide.
    // Le menu ouvert peint l'entrée deux fois, dans la liste et sous elle.
    expect(find.text('Non renseigné'), findsWidgets);
  });

  testWidgets("l'État choisi devient une modification à enregistrer",
      (tester) async {
    await _ouvrirLaSaisie(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sénégal').last);
    await tester.pumpAndSettle();

    expect(find.text('Sénégal'), findsWidgets);
    // L'en-tête compte la case en attente : sans quoi rien ne dirait qu'il
    // reste à enregistrer.
    expect(find.textContaining('1'), findsWidgets);
  });

  testWidgets("l'établissement reste une ligne de saisie libre",
      (tester) async {
    await _ouvrirLaSaisie(tester);

    // Une seule liste sur l'attestation : celle de l'État.
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
