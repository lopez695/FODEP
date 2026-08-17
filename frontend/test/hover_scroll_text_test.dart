// Vérifie le sous-titre des tuiles KPI : une seule ligne en toutes
// circonstances, aucun rétrécissement du texte, et un défilement qui ne se
// déclenche qu'au survol de la tuile puis revient à sa position de départ.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/shared/widgets/hover_scroll_text.dart';

const _style = TextStyle(
  fontSize: 9.5,
  fontWeight: FontWeight.w600,
  height: 1,
);

/// Monte le sous-titre dans une largeur imposée, comme une tuile de la rangée.
Future<void> _pump(
  WidgetTester tester, {
  required String text,
  required bool hovered,
  double width = 120,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: HoverScrollText(
              text: text,
              style: _style,
              hovered: hovered,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Décalage horizontal courant du texte : 0 au repos, négatif quand il défile.
double _offsetOf(WidgetTester tester) {
  final transforms = tester.widgetList<Transform>(find.byType(Transform));
  if (transforms.isEmpty) return 0;
  return transforms.first.transform.getTranslation().x;
}

void main() {
  // Texte volontairement plus large que les 120 px de la tuile.
  const long = 'Exposition brute globale (Actions + Obligations)';
  const short = 'Encours';

  group('Sous-titre de tuile KPI', () {
    testWidgets('reste sur une ligne unique, sans repli ni rétrécissement',
        (tester) async {
      await _pump(tester, text: long, hovered: false);

      final rendered = tester.widget<Text>(find.text(long));
      expect(rendered.maxLines, 1);
      expect(rendered.softWrap, isFalse);
      // Le texte garde sa taille : aucun FittedBox ne le réduit.
      expect(find.byType(FittedBox), findsNothing);
      expect(rendered.style?.fontSize, _style.fontSize);
    });

    testWidgets('ne défile pas tant que la tuile n\'est pas survolée',
        (tester) async {
      await _pump(tester, text: long, hovered: false);

      expect(_offsetOf(tester), 0);
      await tester.pump(const Duration(seconds: 2));
      expect(_offsetOf(tester), 0);
    });

    testWidgets('défile au survol puis revient en sortie', (tester) async {
      await _pump(tester, text: long, hovered: false);
      expect(_offsetOf(tester), 0);

      // Survol : le texte se met en marche.
      await _pump(tester, text: long, hovered: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final moved = _offsetOf(tester);
      expect(moved, lessThan(0),
          reason: 'le texte doit avoir avancé pour révéler sa fin');

      // Sortie : retour à la position de départ.
      await _pump(tester, text: long, hovered: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_offsetOf(tester), moreOrLessEquals(0, epsilon: 0.5));

      // L'animation est bien arrêtée : plus rien ne bouge.
      await tester.pump(const Duration(seconds: 2));
      expect(_offsetOf(tester), moreOrLessEquals(0, epsilon: 0.5));
    });

    testWidgets('un sous-titre qui tient dans la tuile ne bouge jamais',
        (tester) async {
      await _pump(tester, text: short, hovered: true);
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text(short), findsOneWidget);
      expect(_offsetOf(tester), 0);
      // Aucun masque de fondu : rien n'est caché, donc rien à signaler.
      expect(find.byType(ShaderMask), findsNothing);
    });
  });
}
