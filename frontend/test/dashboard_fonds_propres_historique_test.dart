// La carte des fonds propres porte, sous la décomposition par tier, la bande
// des exercices déjà saisis.
//
// Elle avait été ajoutée puis n'apparaissait pas : la version rendue à l'écran
// n'était pas celle du code. Un essai de rendu tranche ce genre de doute mieux
// qu'une relecture — la bande est là, ou la suite échoue.
//
// L'historique n'est pas décoratif : les limites des EP36 à EP38 se mesurent,
// dit le formulaire, sur les fonds propres de l'exercice PRÉCÉDENT.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/modules/dashboard/models/dashboard_models.dart';
import 'package:rwa_calculator/modules/dashboard/widgets/dashboard_fonds_propres.dart';

FondsPropresDetail _fondsPropres({
  int? exercice,
  List<FondsPropresExercice> historique = const [],
}) {
  return FondsPropresDetail(
    capitalOrdinaire: 49323000000,
    reserves: 25610000000,
    resultatsReport: 12331000000,
    resultatEligible: 7589000000,
    deductionsPrudCet1: -7431000000,
    cet1: 87422000000,
    instrumentsAt1: 5277000000,
    primesEmissionAt1: 859000000,
    deductionsPrudAt1: -236000000,
    at1: 5900000000,
    tier1: 93322000000,
    dettesSubordonneesT2: 11203000000,
    provisionsGeneralesT2: 3160000000,
    deductionsPrudT2: -418000000,
    tier2: 13945000000,
    totalFp: 107267000000,
    exercice: exercice,
    historique: historique,
  );
}

DashboardSnapshot _snapshot(FondsPropresDetail fp) {
  return DashboardSnapshot(
    metrics: const [],
    fondsPropres: fp,
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

Future<void> _afficher(WidgetTester tester, FondsPropresDetail fp) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 1100,
          child: DashboardFondsPropres(data: _snapshot(fp)),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets("la carte mène à l'historique sans le recopier", (tester) async {
    // La carte porte l'exercice déclaré ; les millésimes antérieurs vivent sur
    // leur page. Les aligner ici en pastilles doublait l'information.
    await _afficher(
      tester,
      _fondsPropres(exercice: 2026, historique: const [
        FondsPropresExercice(
            exercice: 2026, cet1: 87422000000, tier1: 93322000000,
            totalFp: 107267000000),
        FondsPropresExercice(
            exercice: 2025, cet1: 80000000000, tier1: 86000000000,
            totalFp: 99000000000),
      ]),
    );

    expect(find.text('Voir historique'), findsOneWidget);
    expect(find.text('Historique'), findsNothing,
        reason: 'la bande de pastilles a été retirée de la carte');
    expect(find.text('2025'), findsNothing,
        reason: "les millésimes ne se lisent plus sur la carte");
  });

  testWidgets('le bouton ouvre la page d\'historique', (tester) async {
    await _afficher(
      tester,
      _fondsPropres(exercice: 2026, historique: const [
        FondsPropresExercice(
            exercice: 2026,
            capitalOrdinaire: 49323000000,
            reserves: 25610000000,
            cet1: 87422000000,
            tier1: 93322000000,
            tier2: 13945000000,
            totalFp: 107267000000),
        FondsPropresExercice(
            exercice: 2025,
            capitalOrdinaire: 45000000000,
            reserves: 20000000000,
            cet1: 80000000000,
            tier1: 86000000000,
            tier2: 13000000000,
            totalFp: 99000000000),
      ]),
    );

    // Le meme bouton bleu plein que « Mettre a jour » en tete de carte :
    // les deux ouvrent une action sur les fonds propres et doivent se
    // reconnaitre au premier coup d'oeil.
    expect(find.widgetWithText(ElevatedButton, 'Voir historique'),
        findsOneWidget);

    await tester.tap(find.text('Voir historique'));
    await tester.pumpAndSettle();

    // La page porte tous les postes, pas seulement les agrégats de la carte.
    expect(find.text('Capital ordinaire'), findsOneWidget);
    expect(find.text('Dettes subordonnées'), findsOneWidget);
    expect(find.text('Total CET1'), findsOneWidget);
    expect(find.text('Tier 1 (CET1 + AT1)'), findsOneWidget);
    expect(find.text('Fonds propres réglementaires'), findsWidgets);

    // Et tous les exercices, côte à côte : c'est ce que la carte ne peut pas
    // montrer, et ce dont la mesure des limites a besoin.
    expect(find.text('Exercice 2026'), findsOneWidget);
    expect(find.text('Exercice 2025'), findsOneWidget);
  });

  testWidgets('la page de détail analyse les exercices déclarés',
      (tester) async {
    // C'est sur cette page qu'on déclare les exercices antérieurs : c'est donc
    // là que doit se lire ce qu'ils affirment, pas seulement leurs montants.
    await _afficher(
      tester,
      _fondsPropres(exercice: 2026, historique: const [
        FondsPropresExercice(
            exercice: 2026,
            cet1: 87422000000,
            at1: 5900000000,
            tier1: 93322000000,
            tier2: 13945000000,
            totalFp: 107267000000),
        FondsPropresExercice(
            exercice: 2025,
            cet1: 54340931232,
            at1: 366864330,
            tier1: 54707795562,
            tier2: 0,
            totalFp: 54707795562),
      ]),
    );

    await tester.tap(find.text('Voir historique'));
    await tester.pumpAndSettle();

    expect(find.text('Analyse'), findsOneWidget);
    // La composition dit la qualité des fonds propres, que le seul total tait.
    expect(find.text('Composition'), findsOneWidget);
    expect(find.textContaining('81.5 %'), findsOneWidget);
    // Et l'écart avec l'exercice précédent : c'est le dénominateur des limites
    // des EP36 à EP38 qui bouge.
    expect(find.text('2025 → 2026'), findsOneWidget);
  });

  testWidgets('la page de détail s\'ouvre même sans relevé', (tester) async {
    // Serveur antérieur à l'historique : la page retombe sur l'exercice
    // courant plutôt que de s'ouvrir vide.
    await _afficher(tester, _fondsPropres(exercice: 2026));

    await tester.tap(find.text('Voir historique'));
    await tester.pumpAndSettle();

    expect(find.text('Exercice 2026'), findsOneWidget);
    expect(find.text('Capital ordinaire'), findsOneWidget);
    expect(find.text('Aucun exercice antérieur'), findsOneWidget);
  });
}
