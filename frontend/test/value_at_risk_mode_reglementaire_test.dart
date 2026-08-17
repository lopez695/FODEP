// Vérifie l'affichage de l'onglet VaR en mode réglementaire (aucun
// historique importé) : la VaR paramétrique s'affiche avec la cloche
// théorique seule, la pire perte observée est remplacée par un tiret et
// la méthode historique conserve son erreur explicite.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rwa_calculator/core/services/api_client.dart';
import 'package:rwa_calculator/core/services/rwa_api_service.dart';
import 'package:rwa_calculator/core/state/portfolio_amount_unit_scope.dart';
import 'package:rwa_calculator/core/utils/currency_conversion.dart';
import 'package:rwa_calculator/modules/risque_marche/screens/value_at_risk_screen.dart';

/// Réponse de /api/var/parametrique en mode réglementaire, telle que
/// produite par le backend sans historique : histogramme vide et courbe
/// normale théorique en densité relative base 100. Paramétrable par le
/// niveau de confiance et la volatilité pour simuler les recalculs.
Map<String, dynamic> _reponseParametriqueReglementaire({
  double niveauConfiance = 0.99,
  double volatilite = 0.03,
}) {
  final sigma = 0.049 * volatilite / 0.03;
  final zParNiveau = <double, double>{0.95: 1.6449, 0.975: 1.96, 0.99: 2.3263};
  final z = zParNiveau[niveauConfiance] ?? 2.3263;
  final varValeur = z * sigma;
  final es = 0.131 * sigma / 0.049;
  final courbe = <Map<String, double>>[];
  for (var i = 0; i < 100; i++) {
    final x = -4 * sigma + 8 * sigma * i / 99;
    final zx = x / sigma;
    courbe.add({'x': x, 'y': 100.0 * math.exp(-0.5 * zx * zx)});
  }
  return {
    'methode': 'parametrique',
    'parametres': {
      'type_portefeuille': 'obligations',
      'niveau_confiance': niveauConfiance,
      'horizon_jours': 1,
      'fenetre_jours': 500,
      'volatilite': volatilite,
      'duration_modifiee': 3.4,
    },
    'source_donnees': 'reelles',
    'valeur_portefeuille': 8.001,
    'unite': 'Md FCFA',
    'avertissements': [
      'Aucun historique de prix ni de courbe de taux trouvé. Calculs '
          'limités aux méthodes réglementaires (VaR Paramétrique et '
          'Monte-Carlo simplifiés).',
    ],
    'var': varValeur,
    'expected_shortfall': es,
    'mode_calcul': 'reglementaire',
    'var_multi_horizon': [
      for (final horizon in [1, 3, 10, 21])
        {
          'horizon_jours': horizon,
          'var': varValeur * math.sqrt(horizon),
          'expected_shortfall': es * math.sqrt(horizon),
          'par_niveau': [
            for (final (niveau, zNiveau) in [(0.95, 1.6449), (0.975, 1.96), (0.99, 2.3263)])
              {
                'niveau_confiance': niveau,
                'z_alpha': zNiveau,
                'var': zNiveau * sigma * math.sqrt(horizon),
                'expected_shortfall': es * math.sqrt(horizon) * zNiveau / 2.3263,
              },
          ],
        },
    ],
    'pire_perte': 0.0,
    'p95': 1.6449 * sigma,
    'p975': 1.96 * sigma,
    'p99': 2.3263 * sigma,
    'taux_depassement_pct': 0.0,
    'nombre_observations': 0,
    'mu': 0.0,
    'sigma': sigma,
    'z_alpha': z,
    'skewness': 0.0,
    'kurtosis_exces': 0.0,
    'hypothese_normale_douteuse': false,
    'courbe_normale': courbe,
    'histogramme': <Map<String, dynamic>>[],
  };
}

RwaApiService _serviceSimule() {
  final client = MockClient((requete) async {
    final chemin = requete.url.path;
    if (chemin.contains('/api/var/historique')) {
      return http.Response(
        jsonEncode({
          'detail': {
            'code': 'VAR_PARAMETRE_INVALIDE',
            'message':
                'La méthode de la VaR Historique nécessite obligatoirement '
                    "l'importation d'un historique de prix dans le fichier "
                    'Excel. Aucun historique trouvé.',
          },
        }),
        422,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (chemin.contains('/api/var/parametrique')) {
      final parametres = requete.url.queryParameters;
      return http.Response(
        jsonEncode(_reponseParametriqueReglementaire(
          niveauConfiance:
              double.tryParse(parametres['niveau_confiance'] ?? '') ?? 0.99,
          volatilite: double.tryParse(parametres['volatilite'] ?? '') ?? 0.03,
        )),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response('{}', 404);
  });
  return RwaApiService(
    client: ApiClient(baseUrl: 'http://test.local', client: client),
  );
}

/// Réponse Monte-Carlo d'un petit portefeuille actions (≈ 275 M FCFA) : les
/// montants sont bien inférieurs au milliard, l'écran doit donc les afficher
/// en millions et non « 0,0 Md ».
Map<String, dynamic> _reponseMonteCarloActionsPetit() {
  final histogramme = <Map<String, double>>[
    for (var i = 0; i < 6; i++)
      {
        'borne_inf': -0.02 + i * 0.006,
        'borne_sup': -0.02 + (i + 1) * 0.006,
        'effectif': (100 + i * 30).toDouble(),
      },
  ];
  return {
    'methode': 'montecarlo',
    'parametres': {'type_portefeuille': 'actions'},
    'source_donnees': 'reelles',
    'valeur_portefeuille': 0.2754,
    'unite': 'Md FCFA',
    'avertissements': <String>[],
    'var': 0.0113,
    'expected_shortfall': 0.0142,
    'pire_perte': 0.0201,
    'p95': 0.0081,
    'p975': 0.0097,
    'p99': 0.0113,
    'taux_depassement_pct': 1.0,
    'nombre_observations': 10000,
    'nb_simulations': 10000,
    'graine': 42,
    'modele_simulation': 'rendements normaux réglementaires x bêta',
    'ic_var_95': {'borne_basse': 0.0108, 'borne_haute': 0.0119},
    'histogramme': histogramme,
    'courbe_normale': <Map<String, double>>[],
  };
}

RwaApiService _serviceActionsMonteCarlo() {
  final client = MockClient((requete) async {
    if (requete.url.path.contains('/api/var/montecarlo')) {
      return http.Response(
        jsonEncode(_reponseMonteCarloActionsPetit()),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    // Toute autre méthode (historique par défaut) : 422 explicite.
    return http.Response(
      jsonEncode({
        'detail': {'code': 'VAR_PARAMETRE_INVALIDE', 'message': 'Aucun historique.'},
      }),
      422,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  return RwaApiService(
    client: ApiClient(baseUrl: 'http://test.local', client: client),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'mode réglementaire : cloche théorique seule, tiret pour la pire perte',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1700, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // La police de test Ahem rend chaque glyphe carré (14 px de large) :
    // les libellés du panneau de paramètres débordent artificiellement,
    // ce qui n'arrive pas avec la vraie police. On ignore uniquement ces
    // débordements ; toute autre erreur de rendu fait échouer le test.
    final onErrorParDefaut = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      onErrorParDefaut?.call(details);
    };
    addTearDown(() => FlutterError.onError = onErrorParDefaut);

    await tester.pumpWidget(
      PortfolioAmountUnitScope(
        notifier: ValueNotifier<PortfolioAmountUnit>(PortfolioAmountUnit.billion),
        child: MaterialApp(
          home: Scaffold(body: ValueAtRiskScreen(api: _serviceSimule())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Méthode par défaut : paramétrique (fonctionne sans historique) — pas
    // historique, verrouillée et placée en dernier tant qu'aucun historique
    // de prix réel n'est disponible (décision du 2026-07-17).
    expect(find.text('VALEUR DU PORTEFEUILLE'), findsOneWidget);

    // Sans observation, la pire perte observée est un tiret, pas un zéro.
    expect(find.text('-'), findsOneWidget);

    // La VaR et l'ES du backend sont bien affichées sur les cartes KPI.
    expect(find.textContaining('0,1'), findsWidgets);

    // L'onglet Historique n'est plus un cadenas : il annonce ce qu'il
    // contient et reste navigable.
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.text('Méthodologie'), findsOneWidget);

    await tester.tap(find.text('VaR Historique'));
    await tester.pumpAndSettle();

    // Il expose la méthode et le cas chiffré, sans jamais appeler le serveur.
    expect(find.text('Méthode de la VaR historique'), findsOneWidget);
    expect(find.text('Cas chiffré, de bout en bout'), findsOneWidget);
    expect(
      find.textContaining('nécessite obligatoirement'),
      findsNothing,
      reason: 'la VaR historique ne doit déclencher aucune requête',
    );

    await tester.pump(const Duration(seconds: 11));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'axe figé : les recalculs déplacent les seuils sans recaler l\'axe',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1700, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final onErrorParDefaut = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      onErrorParDefaut?.call(details);
    };
    addTearDown(() => FlutterError.onError = onErrorParDefaut);

    await tester.pumpWidget(
      PortfolioAmountUnitScope(
        notifier: ValueNotifier<PortfolioAmountUnit>(PortfolioAmountUnit.billion),
        child: MaterialApp(
          home: Scaffold(body: ValueAtRiskScreen(api: _serviceSimule())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('VaR Paramétrique'));
    await tester.pumpAndSettle();

    // Le peintre du graphique est une classe privée : l'accès dynamique à
    // ses champs publics suffit pour vérifier le cadrage de l'axe.
    dynamic peintre() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .firstWhere(
          (cp) =>
              cp.painter.runtimeType.toString() == '_HistogrammeVarPainter',
        )
        .painter;

    final p0 = peintre();
    final xMin0 = p0.xMinFige as double?;
    final xMax0 = p0.xMaxFige as double?;
    expect(xMin0, isNotNull, reason: 'l\'axe doit être figé dès la 1re réponse');
    expect(xMax0, isNotNull);
    // Cadrage initial : cloche ±4 sigma (sigma = 0,049).
    expect(xMin0, closeTo(-4 * 0.049, 1e-6));
    expect(p0.reponsePrecedente, isNull);

    // Changement de niveau de confiance : la VaR bouge (2,3263 sigma ->
    // 1,96 sigma), l'axe reste figé et le filigrane avant/après apparaît.
    await tester.tap(find.text('97,50 %').first);
    await tester.pumpAndSettle();
    final p1 = peintre();
    expect(p1.xMinFige, equals(xMin0));
    expect(p1.xMaxFige, equals(xMax0));
    expect(p1.reponsePrecedente, isNotNull,
        reason: 'la réponse précédente doit rester tracée en filigrane');
    expect(p1.reponse.varValeur as double, closeTo(1.96 * 0.049, 1e-6));
    expect(
      p1.reponsePrecedente.varValeur as double,
      closeTo(2.3263 * 0.049, 1e-6),
    );

    // Hausse de volatilité : la cloche s'élargit nettement mais la borne
    // gauche de l'axe ne se recale pas ; la VaR reste visible à droite.
    await tester.drag(find.byType(Slider).first, const Offset(150, 0));
    await tester.pumpAndSettle();
    final p2 = peintre();
    expect(p2.xMinFige, equals(xMin0),
        reason: 'l\'axe figé ne doit pas se recaler automatiquement');
    final courbeMin = (p2.reponse.courbeNormale as List).first.dx as double;
    expect(courbeMin, lessThan(-1.0),
        reason: 'la volatilité accrue doit élargir la cloche théorique');
    expect(
      p2.xMaxFige as double,
      greaterThanOrEqualTo(p2.reponse.varValeur as double),
      reason: 'la VaR doit rester dans le cadre',
    );

    // Recadrage manuel : l'axe se recale sur la distribution courante.
    await tester.tap(find.byIcon(Icons.center_focus_strong));
    await tester.pump();
    final p3 = peintre();
    expect(p3.xMinFige as double, closeTo(courbeMin, 1e-9),
        reason: 'le bouton recadrer doit caler l\'axe sur la cloche courante');

    await tester.pump(const Duration(seconds: 11));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'petit portefeuille actions : montants affichés en millions, pas « 0,0 Md »',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1700, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final onErrorParDefaut = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      onErrorParDefaut?.call(details);
    };
    addTearDown(() => FlutterError.onError = onErrorParDefaut);

    await tester.pumpWidget(
      PortfolioAmountUnitScope(
        notifier: ValueNotifier<PortfolioAmountUnit>(PortfolioAmountUnit.billion),
        child: MaterialApp(
          home: Scaffold(body: ValueAtRiskScreen(api: _serviceActionsMonteCarlo())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Bascule sur la VaR Monte-Carlo (le mock renvoie le petit portefeuille).
    await tester.tap(find.text('VaR Monte-Carlo').first);
    await tester.pumpAndSettle();

    final textesCartes = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((rt) => rt.text.toPlainText())
        .toList();

    // Le portefeuille (0,2754 Md) est lu en millions : 275,4 M.
    expect(
      textesCartes.any((t) => t.contains('275,4 M')),
      isTrue,
      reason: 'la valeur du portefeuille doit s\'afficher « 275,4 M »',
    );
    // La VaR (0,0113 Md) devient 11,3 M au lieu de « 0,0 Md ».
    expect(
      textesCartes.any((t) => t.contains('11,3 M')),
      isTrue,
      reason: 'la VaR doit s\'afficher « 11,3 M »',
    );
    // Aucune carte ne doit rester bloquée sur « 0,0 » ni sur l\'unité « Md ».
    expect(
      textesCartes.any((t) => t.contains('0,0') || t.contains('Md')),
      isFalse,
      reason: 'aucune valeur ne doit être écrasée à « 0,0 Md »',
    );

    await tester.pump(const Duration(seconds: 11));
    await tester.pumpWidget(const SizedBox());
  });
}
