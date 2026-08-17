// La gestion d'équipe doit être atteignable quelle que soit la largeur de
// l'écran.
//
// L'application porte DEUX barres d'en-tête : `_WorkspaceTopBar` sur poste de
// travail, `_TopBar` sur écran étroit. La zone compte n'avait été posée que
// sur la seconde : le bouton « Gérer l'équipe » apparaissait au téléphone et
// restait introuvable sur ordinateur, pour le même compte.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:rwa_calculator/core/app_module.dart';
import 'package:rwa_calculator/core/auth/session_controller.dart';
import 'package:rwa_calculator/core/auth/session_scope.dart';
import 'package:rwa_calculator/core/state/portfolio_amount_unit_scope.dart';
import 'package:rwa_calculator/core/state/portfolio_currency_scope.dart';
import 'package:rwa_calculator/core/utils/currency_conversion.dart';
import 'package:rwa_calculator/core/localization/app_language.dart';
import 'package:rwa_calculator/shared/widgets/app_shell.dart';

class _ClientFactice extends http.BaseClient {
  _ClientFactice(this.reponses);

  final Map<String, (int, String)> reponses;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final (code, corps) = reponses[request.url.path] ?? (404, '{}');
    return http.StreamedResponse(
      Stream.value(corps.codeUnits),
      code,
      request: request,
    );
  }
}

Future<SessionController> _sessionEdition() async {
  final controller = SessionController(
    baseUrl: 'http://test',
    client: _ClientFactice({
      '/auth/me': (401, '{}'),
      '/auth/refresh': (
        200,
        '{"access_token":"jeton","expires_in":3600,'
            '"profil":{"identifiant":"pascal","role":"edition"}}'
      ),
    }),
  );
  await controller.initialiser();
  return controller;
}

void main() {
  // Le contrôleur est rendu à l'appelant : son minuteur de renouvellement
  // doit être libéré DANS le corps du test, le contrôle des minuteurs en
  // attente s'exécutant avant les tearDown.
  Future<SessionController> monter(WidgetTester tester, Size taille) async {
    final session = await _sessionEdition();

    tester.view.physicalSize = taille;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionScope(
          controller: session,
          child: PortfolioCurrencyScope(
            notifier: ValueNotifier<String>('XOF'),
            child: PortfolioAmountUnitScope(
              notifier: ValueNotifier<PortfolioAmountUnit>(
                PortfolioAmountUnit.billion,
              ),
              child: AppShell(
                selectedModule: AppModule.vueEnsemble,
                onSelectModule: (_) {},
                onReturnToWelcome: () {},
                themeMode: ThemeMode.light,
                onThemeModeChanged: (_) {},
                portfolioDisplayCurrency: ValueNotifier<String>('XOF'),
                portfolioAmountUnit: ValueNotifier<PortfolioAmountUnit>(
                  PortfolioAmountUnit.billion,
                ),
                appLanguage: ValueNotifier<AppLanguage>(AppLanguage.francais),
                fontFamily: 'Roboto',
                onFontFamilyChanged: (_) {},
                primaryColor: const Color(0xFF172B4D),
                onPrimaryColorChanged: (_) {},
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return session;
  }

  testWidgets('la gestion d\'équipe est atteignable sur poste de travail',
      (tester) async {
    final session = await monter(tester, const Size(1600, 1000));

    expect(
      find.byTooltip('Gérer l\'équipe'),
      findsOneWidget,
      reason: 'La barre du poste de travail doit porter la zone compte.',
    );
    session.dispose();
  });

  testWidgets('la gestion d\'équipe est atteignable sur écran étroit',
      (tester) async {
    final session = await monter(tester, const Size(420, 900));

    expect(
      find.byTooltip('Gérer l\'équipe'),
      findsOneWidget,
      reason: 'La barre mobile doit porter la même zone compte.',
    );
    session.dispose();
  });
}
