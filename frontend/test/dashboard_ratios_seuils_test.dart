// Garde sur les seuils prudentiels affichés par le bandeau de ratios du
// tableau de bord. Le minimum Tier 1 du dispositif UMOA est de 6 % : il avait
// dérivé à 7,5 %, si bien que l'excédent annoncé était amputé de 1,5 point.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/modules/dashboard/models/dashboard_models.dart';
import 'package:rwa_calculator/modules/dashboard/widgets/dashboard_ratios_row.dart';

/// Fonds propres calibrés pour un Tier 1 de 11,313 % des RWA, la situation de
/// la copie d'écran ayant révélé le seuil erroné.
FondsPropresDetail _fondsPropres({required double rwa}) {
  final tier1 = rwa * 0.11313;
  return FondsPropresDetail(
    capitalOrdinaire: tier1,
    reserves: 0,
    resultatsReport: 0,
    resultatEligible: 0,
    deductionsPrudCet1: 0,
    cet1: tier1,
    instrumentsAt1: 0,
    primesEmissionAt1: 0,
    deductionsPrudAt1: 0,
    at1: 0,
    tier1: tier1,
    dettesSubordonneesT2: 0,
    provisionsGeneralesT2: 0,
    deductionsPrudT2: 0,
    tier2: 0,
    totalFp: tier1,
  );
}

DashboardSnapshot _snapshot() {
  const rwa = 1000000.0;
  return DashboardSnapshot(
    metrics: const [
      DashboardMetric(
          key: 'rwa', label: 'RWA', value: rwa, variation: '', trend: []),
      DashboardMetric(
          key: 'encours',
          label: 'Encours',
          value: rwa * 2,
          variation: '',
          trend: []),
    ],
    fondsPropres: _fondsPropres(rwa: rwa),
    valuationDate: DateTime(2026, 7, 24),
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

Future<void> _pump(WidgetTester tester, {required double width}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: DashboardRatiosRow(data: _snapshot()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Seuils du bandeau de ratios', () {
    testWidgets('le minimum Tier 1 est de 6 %, pas 7,5 %', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester, width: 1400);

      expect(find.textContaining('Pilier 1 (6%)'), findsOneWidget);
      expect(find.textContaining('Pilier 1 (7,5%)'), findsNothing);
      // Les autres minima du dispositif restent inchangés.
      expect(find.textContaining('Pilier 1 (5%)'), findsOneWidget);
      expect(find.textContaining('Pilier 1 (9%)'), findsOneWidget);
      expect(find.textContaining('Pilier 1 (3%)'), findsOneWidget);
    });

    testWidgets('l\'excédent Tier 1 se mesure sur 6 % + 2,5 % de coussin',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester, width: 1400);

      // 11,313 % − (6 % + 2,5 %) = 2,813 points, et non 1,313 avec l'ancien
      // seuil de 7,5 %. Correspondance exacte : « 11,313% », le ratio lui-même,
      // contient « 1,313 ».
      expect(find.text('+2,813 pts'), findsOneWidget);
      expect(find.text('+1,313 pts'), findsNothing);
    });

    testWidgets('la disposition étroite affiche les mêmes seuils',
        (tester) async {
      tester.view.physicalSize = const Size(700, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester, width: 600);

      expect(find.textContaining('Pilier 1 (6%)'), findsOneWidget);
      expect(find.textContaining('Pilier 1 (7,5%)'), findsNothing);
    });
  });
}
