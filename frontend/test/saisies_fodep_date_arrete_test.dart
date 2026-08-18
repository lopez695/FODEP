// La date d'arrêté se choisit au calendrier, et le choix remonte à l'appelant.
//
// Elle arrive pré-remplie de la date de fin du reporting — un défaut commode —
// mais c'est le déclarant qui arrête sa déclaration : elle peut porter sur une
// fin de trimestre sans que le reporting consulté s'y arrête. Les huit cases
// restaient figées, ce qui laissait croire qu'on ne pouvait pas la corriger.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/core/services/rwa_api_service.dart';
import 'package:rwa_calculator/modules/rapports/models/report_models.dart';
import 'package:rwa_calculator/modules/rapports/screens/saisies_fodep_page.dart';

/// API qui répond sans réseau, avec une case à renseigner pour que l'écran
/// affiche l'attestation.
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
                  'cellule': 'T5',
                  // Un numéro de ligne, pas un libellé : la case est repérée
                  // par son adresse dans le formulaire.
                  'ligne': 5,
                  'code': '',
                  'libelle': 'Établissement',
                  'colonne': '',
                  'type_saisie': 'texte',
                  'texte': null,
                  'valeur': null,
                },
              ],
            },
          ],
          'total_cases': 1,
          'total_renseignees': 0,
        },
      );
}

void main() {
  testWidgets('la date d\'arrêté se choisit au calendrier et remonte',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    ({bool modifie, DateTime? dateArrete})? retour;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  retour = await SaisiesFodepPage.ouvrir(
                    context,
                    _ApiBouchonnee(),
                    dateArrete: DateTime(2026, 8, 18),
                  );
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    // La date arrive pré-remplie, chiffre par chiffre, dans le gabarit de
    // l'attestation : 2026 08 18.
    expect(find.text('Date d\'arrêté'), findsOneWidget);
    expect(find.byTooltip('Choisir la date d\'arrêté'), findsOneWidget);

    await tester.tap(find.byTooltip('Choisir la date d\'arrêté'));
    await tester.pumpAndSettle();

    // Le calendrier s'ouvre sur la date retenue, et l'annonce.
    expect(find.text('Date d\'arrêté de la déclaration'), findsOneWidget);

    // Un autre jour du même mois, puis on retient.
    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retenir'));
    await tester.pumpAndSettle();

    // Le retour, puis la sortie de l'écran : la date choisie doit remonter,
    // sans quoi l'export repartirait de celle du reporting et contredirait
    // l'attestation.
    await tester.tap(find.byTooltip('Retour au reporting'));
    await tester.pumpAndSettle();

    expect(retour, isNotNull);
    expect(retour!.dateArrete, DateTime(2026, 8, 25));
    expect(retour!.modifie, isFalse);
  });
}
