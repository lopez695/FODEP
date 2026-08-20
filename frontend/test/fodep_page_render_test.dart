// La page de la déclaration prudentielle porte les trois moments de la tâche :
// renseigner les cases que l'application ne calcule pas, exporter le formulaire,
// et relire une déclaration déjà produite. Les deux premiers vivaient à deux
// coins opposés de l'écran de reporting, ce qui laissait exporter sans avoir
// rien renseigné.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/core/services/rwa_api_service.dart';
import 'package:rwa_calculator/modules/rapports/models/report_models.dart';
import 'package:rwa_calculator/modules/risque_operationnel/models/ro_models.dart';
import 'package:rwa_calculator/modules/rapports/screens/fodep_page.dart';

/// API qui répond sans réseau : la page n'a besoin que du décompte des cases.
class _ApiBouchonnee extends RwaApiService {
  _ApiBouchonnee() : super(baseUrl: 'http://127.0.0.1:1');

  @override
  Future<SaisiesFodep> fetchSaisiesFodep() async => SaisiesFodep.fromJson(
        <String, dynamic>{
          'etats': const [],
          'total_cases': 27,
          'total_renseignees': 4,
        },
      );

  /// La méthode du risque opérationnel : l'écran la lit au chargement.
  @override
  Future<ParametresAs> fetchAsParametres() async => const ParametresAs(
        asAutorisee: true,
        dateAutorisation: '2026-01-15',
        referenceAutorisation: 'CB/2026/014',
        multiplicateurRwa: 12.5,
        ratioSolvabiliteMin: 0.09,
      );
}

Future<void> _poser(WidgetTester tester, {DateTime? dateArrete}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: FodepPage(api: _ApiBouchonnee(), dateArrete: dateArrete),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la page porte les trois étapes de la déclaration',
      (tester) async {
    await _poser(tester, dateArrete: DateTime(2026, 8, 18));

    expect(tester.takeException(), isNull);
    expect(find.text('Déclaration prudentielle (FODEP)'), findsOneWidget);

    // Les deux actions qui vivaient sur l'écran de reporting, plus l'analyse
    // d'une déclaration déposée.
    expect(find.text('Cases à renseigner'), findsOneWidget);
    expect(find.text('Exporter le FODEP'), findsOneWidget);
    expect(find.text('Analyser une déclaration'), findsOneWidget);
    expect(find.text('Importer une déclaration'), findsOneWidget);
    // Les deux formats de la déclaration sont annoncés : le classeur transmis
    // et son impression.
    expect(find.textContaining('.xlsx'), findsOneWidget);

    // L'export est la seule action qui produit la pièce déclarative : elle est
    // pleine. La saisie et l'analyse restent des contours.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(2));

    // La date d'arrêté est annoncée : on n'exporte pas une déclaration sans
    // savoir de quelle date elle parle.
    expect(find.textContaining('18/08/2026'), findsOneWidget);

    // Et l'avancement de la saisie, lu depuis le backend.
    expect(find.textContaining('4 case(s) renseignée(s) sur 27'), findsOneWidget);
  });

  testWidgets('sans date d\'arrêté, la page dit d\'où elle viendra',
      (tester) async {
    await _poser(tester);

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('déduite de la date d\'analyse la plus récente'),
      findsOneWidget,
    );
  });

  testWidgets('les deux méthodes se présentent à la même taille',
      (tester) async {
    // Elles se valent : l'une n'est pas plus grande que l'autre. Sans cela, la
    // mention de l'accord de la Commission bancaire allonge la carte de
    // l'approche standard, et le déséquilibre se lit comme une préférence de
    // l'application.
    await _poser(tester, dateArrete: DateTime(2026, 8, 18));

    expect(find.text('Méthode du risque opérationnel'), findsOneWidget);

    Size carte(String titre) => tester.getSize(
          find
              .ancestor(of: find.text(titre), matching: find.byType(InkWell))
              .first,
        );

    final base = carte('Indicateur de base');
    final standard = carte('Standard');
    expect(base.height, standard.height);
    expect(base.width, standard.width);

    // L'egalite n'est pas acquise d'avance : la carte de l'approche standard
    // porte une ligne de plus, et c'est elle qui la faisait depasser.
    expect(find.text('sur accord de la Commission bancaire'), findsOneWidget);

    // Et chacune annonce les états qu'elle renseigne.
    expect(find.text('EP21 · EP22'), findsOneWidget);
    expect(find.text('EP23 · EP24'), findsOneWidget);
  });
}
