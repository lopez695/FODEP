// Test de non-régression du défilement du tableau « Titres exposés au risque
// de change ».
//
// Bug corrigé : les colonnes figées (ÉMETTEUR à gauche, GAIN/PERTE DE CHANGE à
// droite) ne défilaient pas avec les lignes correspondantes du milieu, car les
// trois colonnes étaient trois listes verticales indépendantes synchronisées à
// la main. Le tableau utilise désormais UNE seule liste verticale virtualisée :
// chaque ligne porte ses trois zones, donc tout défile d'un bloc et reste
// aligné par construction, sans rien sacrifier de la virtualisation.
//
// Ce test vérifie que la colonne figée de gauche défile bien avec le corps et
// que la liste est virtualisée (les lignes hors écran ne sont pas construites).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rwa_calculator/core/state/portfolio_amount_unit_scope.dart';
import 'package:rwa_calculator/core/utils/currency_conversion.dart';
import 'package:rwa_calculator/modules/risque_marche/screens/fx_risk_analysis_screen.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';

void main() {
  testWidgets(
      'la colonne figée défile avec le corps et la liste reste virtualisée',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});

    // 60 titres avec un émetteur unique chacun : largement de quoi déborder du
    // viewport et forcer le défilement vertical + la virtualisation.
    const total = 60;
    final records = <MarketPortfolioRecord>[
      for (int i = 0; i < total; i++)
        MarketPortfolioRecord(
          portfolioType: MarketPortfolioType.bonds,
          values: {
            'ID Titre': 'B${i.toString().padLeft(3, '0')}',
            'Emetteur': 'EMET_${i.toString().padLeft(3, '0')}',
            'Devise': 'USD',
            'Valeur nominale unitaire': 1000.0,
            'quantités': 100.0,
            'Prix d\'emission': 1000.0,
            'Cours actuel': 1.0,
            'Taux de change initial': 600.0,
            'Taux de change actuel': 610.0,
          },
        ),
    ];

    MarketDataImportStore.instance.snapshotNotifier.value =
        MarketDataSnapshot.fromDatasets(
      {
        MarketPortfolioType.bonds: MarketPortfolioDataset(
          portfolioType: MarketPortfolioType.bonds,
          fileName: 'mock_portfolio.xlsx',
          importedAt: DateTime.now(),
          headers: const [
            'ID Titre',
            'Emetteur',
            'Devise',
            'Valeur nominale unitaire',
            'quantités',
            'Prix d\'emission',
            'Cours actuel',
            'Taux de change initial',
            'Taux de change actuel',
          ],
          records: records,
        ),
      },
      activeType: MarketPortfolioType.bonds,
    );

    // Volontairement, on N'ATTEND PAS `MarketDataImportStore.initialized` : ce
    // future dépend d'une lecture fichier réelle (dart:io) qui n'est jamais
    // pompée sous `flutter_test`, et son `.timeout` ne se déclenche pas non plus
    // pendant un `await` nu (horloge simulée) — l'attendre figeait tout le test.
    // L'écran rend désormais directement les données présentes dans le snapshot
    // (cf. FxRiskAnalysisScreen.initState), donc le tableau est disponible dès
    // le premier pump sans dépendre de la restauration persistée.
    await tester.pumpWidget(
      PortfolioAmountUnitScope(
        notifier:
            ValueNotifier<PortfolioAmountUnit>(PortfolioAmountUnit.billion),
        child: const MaterialApp(
          home: Scaffold(body: FxRiskAnalysisScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // État initial : la première ligne est visible, la dernière non
    // (virtualisation : elle n'est même pas construite).
    expect(find.text('EMET_000'), findsOneWidget);
    expect(find.text('EMET_059'), findsNothing);

    // On déroule le corps vers le bas (un seul ListView vertical).
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    // Après défilement : la colonne figée de gauche a bien défilé avec le
    // corps — la première ligne a disparu, la dernière est apparue.
    expect(find.text('EMET_000'), findsNothing);
    expect(find.text('EMET_059'), findsOneWidget);
  });
}
