// Le détail « Expositions par CRM » range chaque ligne dans l'un de ses trois
// onglets. Un type de CRM non reconnu ne doit jamais être compté comme une
// garantie : cela gonflerait la couverture apparente du portefeuille.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/modules/dashboard/models/dashboard_models.dart';
import 'package:rwa_calculator/modules/dashboard/widgets/dashboard_crm_donut.dart';

PortfolioRow _row({
  required String id,
  required String crmType,
  String counterparty = 'Contrepartie test',
  double grossAmount = 100,
  double ead = 100,
  double rwa = 100,
  double? rwaBeforeCrm,
  String guarantorName = '',
  String collateralType = '',
  double crmCoveragePercent = 0,
  double guarantorRiskWeight = 0,
}) {
  return PortfolioRow(
    id: id,
    counterparty: counterparty,
    country: 'Côte d\'Ivoire',
    category: 'Entreprises',
    rating: 'BBB',
    crmType: crmType,
    grossAmount: grossAmount,
    offBalanceExposureAmount: 0,
    ead: ead,
    rwa: rwa,
    capital: rwa * 0.09,
    rwaBeforeCrm: rwaBeforeCrm,
    guarantorName: guarantorName,
    collateralType: collateralType,
    crmCoveragePercent: crmCoveragePercent,
    guarantorRiskWeight: guarantorRiskWeight,
    originalRiskWeight: 1.0,
    finalRiskWeight: rwa / ead,
  );
}

void main() {
  group('crmBucketLabel', () {
    test('reconnaît les trois types produits par le backend', () {
      // Valeurs réellement servies par /dashboard (champ crm_type).
      expect(crmBucketLabel('Aucune'), 'AUCUNE');
      expect(crmBucketLabel('CRM financee'), 'FINANCÉE');
      expect(crmBucketLabel('CRM non financee'), 'NON FINANCÉE');
    });

    test('tolère les accents et la casse', () {
      expect(crmBucketLabel('CRM FINANCÉE'), 'FINANCÉE');
      expect(crmBucketLabel('CRM Non Financée'), 'NON FINANCÉE');
      expect(crmBucketLabel('Sans CRM'), 'AUCUNE');
    });

    test('une sûreté en espèces reste une CRM financée', () {
      expect(crmBucketLabel('Cash collateral'), 'FINANCÉE');
    });

    test('un type vide ou inconnu ne compte pas comme une garantie', () {
      // Sans cette règle, une ligne sans information de CRM apparaîtrait
      // parmi les expositions couvertes par une garantie non financée.
      expect(crmBucketLabel(''), 'AUCUNE');
      expect(crmBucketLabel('   '), 'AUCUNE');
      expect(crmBucketLabel('Type inattendu'), 'AUCUNE');
    });
  });

  group('effet CRM d\'une ligne de portefeuille', () {
    test('une garantie qui allège le RWA produit une économie positive', () {
      final row = _row(
        id: 'EXP-1',
        crmType: 'CRM financee',
        rwa: 50,
        rwaBeforeCrm: 200,
      );
      expect(row.rwaBeforeCrm, 200);
      expect(row.crmRwaSaving, 150);
    });

    test('une garantie sans effet ne produit aucune économie', () {
      // Le moteur ne retient pas une substitution défavorable : la ligne garde
      // la pondération du débiteur, RWA inchangé.
      final row = _row(
        id: 'EXP-2',
        crmType: 'CRM non financee',
        rwa: 75,
        rwaBeforeCrm: 75,
        crmCoveragePercent: 0.82,
        guarantorRiskWeight: 1.0,
      );
      expect(row.crmRwaSaving, 0);
    });

    test('un RWA dégradé servi par un ancien backend reste signé négatif', () {
      // Garde-fou d'affichage : si une base non recalculée sert encore un RWA
      // superieur au RWA sans CRM, l'ecart ne doit pas passer pour un gain.
      final row = _row(
        id: 'EXP-2-bis',
        crmType: 'CRM non financee',
        rwa: 96,
        rwaBeforeCrm: 75,
      );
      expect(row.crmRwaSaving, lessThan(0));
    });

    test('sans champ servi par le backend, aucun effet n\'est inventé', () {
      final row = _row(id: 'EXP-3', crmType: 'Aucune', rwa: 80);
      expect(row.rwaBeforeCrm, 80);
      expect(row.crmRwaSaving, 0);
    });
  });

  group('détail des expositions par CRM', () {
    Future<void> pumpDetails(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCrmDonut(
              entries: const [
                DistributionEntry(
                  label: 'CRM financee',
                  amount: 100,
                  percentage: 0.5,
                  count: 1,
                ),
                DistributionEntry(
                  label: 'CRM non financee',
                  amount: 100,
                  percentage: 0.5,
                  count: 1,
                ),
              ],
              portfolioOverview: [
                _row(
                  id: 'EXP-FIN',
                  crmType: 'CRM financee',
                  counterparty: 'Société Atlantis Minière SARL',
                  collateralType: 'Liquidités dans la même devise',
                  rwa: 50,
                  rwaBeforeCrm: 100,
                ),
                _row(
                  id: 'EXP-NF',
                  crmType: 'CRM non financee',
                  counterparty: 'M. OUATTARA Mariam',
                  guarantorName: 'Fonds de Garantie des Crédits aux PME',
                  // Garant pondéré comme le débiteur : couverture déclarée à
                  // 82 %, aucune réduction retenue.
                  rwa: 75,
                  rwaBeforeCrm: 75,
                  crmCoveragePercent: 0.8241,
                  guarantorRiskWeight: 1.0,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Voir plus'));
      await tester.pumpAndSettle();
    }

    testWidgets('affiche la contrepartie et son en-tête sans défilement',
        (tester) async {
      // L'en-tête et les lignes partagent le même défilement horizontal :
      // la colonne « Contrepartie » ne peut plus se retrouver hors écran
      // pendant que ses valeurs restent visibles.
      await pumpDetails(tester);

      expect(find.text('Contrepartie'), findsOneWidget);
      expect(find.text('Société Atlantis Minière SARL'), findsOneWidget);
    });

    testWidgets('chaque onglet expose les colonnes propres à son type de CRM',
        (tester) async {
      await pumpDetails(tester);

      expect(find.text('Sûreté'), findsOneWidget);
      expect(find.text('Sûreté retenue'), findsOneWidget);
      expect(find.text('Garant'), findsNothing);

      await tester.tap(find.text('Non financée'));
      await tester.pumpAndSettle();

      expect(find.text('Garant'), findsOneWidget);
      expect(find.text('Pond. garant'), findsOneWidget);
      expect(find.text('Fonds de Garantie des Crédits aux PME'), findsOneWidget);
      expect(find.text('Sûreté retenue'), findsNothing);
    });

    testWidgets('les trois pondérations sont comparables côte à côte',
        (tester) async {
      // Juger une garantie personnelle, c'est comparer le poids du débiteur,
      // celui du garant et celui finalement retenu. Les trois doivent être
      // lisibles ensemble, pas déduits d'une flèche.
      await pumpDetails(tester);
      await tester.tap(find.text('Non financée'));
      await tester.pumpAndSettle();

      expect(find.text('Pond. contrepartie'), findsOneWidget);
      expect(find.text('Pond. garant'), findsOneWidget);
      expect(find.text('Pond. retenue'), findsOneWidget);
    });

    testWidgets('signale une garantie qui ne réduit pas l\'exigence',
        (tester) async {
      // Le moteur ne retient pas une substitution défavorable : la ligne garde
      // la pondération du débiteur. Elle compte pourtant dans le taux de
      // couverture affiché — c'est ce décalage que le bandeau doit dire.
      await pumpDetails(tester);
      await tester.tap(find.text('Non financée'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('aucun allègement'),
        findsOneWidget,
      );
    });

    testWidgets('la recherche filtre les lignes de l\'onglet', (tester) async {
      await pumpDetails(tester);

      await tester.enterText(find.byType(TextField), 'introuvable');
      await tester.pumpAndSettle();

      expect(find.text('Société Atlantis Minière SARL'), findsNothing);
      expect(
        find.text('Aucune exposition ne correspond à ce filtre.'),
        findsOneWidget,
      );
    });
  });
}
