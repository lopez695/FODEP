// Vérifie que les trois modales d'import Excel (Fonds Propres, BIC, Pertes)
// s'ouvrent sans exception de layout : leur corps est un SingleChildScrollView
// (hauteur non bornée), donc aucun Expanded ne doit s'y trouver.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/core/services/rwa_api_service.dart';
import 'package:rwa_calculator/modules/dashboard/widgets/dashboard_fonds_propres_import_dialog.dart';
import 'package:rwa_calculator/modules/risque_operationnel/widgets/ro_import_bic_dialog.dart';
import 'package:rwa_calculator/modules/risque_operationnel/widgets/ro_import_pertes_dialog.dart';

Future<void> _pumpDialog(
  WidgetTester tester,
  Future<void> Function(BuildContext context, RwaApiService api) open,
) async {
  final api = RwaApiService(baseUrl: 'http://127.0.0.1:1');
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          ctx = context;
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    ),
  );
  // ignore: unawaited_futures
  open(ctx, api);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.byType(Dialog), findsOneWidget);
}

void main() {
  testWidgets('la modale d\'import Fonds Propres s\'ouvre sans erreur',
      (tester) async {
    await _pumpDialog(
        tester, (ctx, api) async => showFondsPropresImportDialog(ctx, api: api));
  });

  testWidgets('la modale d\'import BIC s\'ouvre sans erreur', (tester) async {
    await _pumpDialog(
        tester, (ctx, api) async => showRoImportBicDialog(ctx, api: api));
  });

  testWidgets('la modale d\'import Pertes s\'ouvre sans erreur',
      (tester) async {
    await _pumpDialog(
        tester, (ctx, api) async => showRoImportPertesDialog(ctx, api: api));
  });
}
