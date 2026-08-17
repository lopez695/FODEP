// Vérifie que les jauges de limites prudentielles se posent sans exception de
// layout. La ligne d'une limite empile des Row imbriquées : le niveau observé
// et l'étiquette d'état sont des enfants non flexibles d'une Row, donc ils
// reçoivent une largeur infinie et doivent se dimensionner à leur contenu.
// Sans MainAxisSize.min, la mise en page échoue au premier rendu.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/modules/participations/models/participation_models.dart';
import 'package:rwa_calculator/modules/participations/widgets/jauge_limite.dart';

LimitePrudentielle _limite({
  required String code,
  required String etat,
  required double numerateur,
  required double denominateur,
  required double limite,
  String? concerne,
}) {
  final mesurable = denominateur > 0;
  final observe = mesurable ? numerateur / denominateur : 0.0;
  return LimitePrudentielle(
    code: code,
    libelle: 'Participation la plus forte dans une entité commerciale',
    etat: etat,
    numerateur: numerateur,
    numerateurLibelle: 'Souscription (montant brut)',
    denominateur: denominateur,
    denominateurLibelle: 'Capital de l\'entreprise émettrice',
    observe: observe,
    limite: limite,
    mesurable: mesurable,
    respectee: mesurable && observe <= limite,
    excedent: mesurable ? (numerateur - limite * denominateur).clamp(0, 1e18) : 0,
    concerne: concerne,
  );
}

/// Les quatre états possibles d'une limite : respectée, proche de son plafond,
/// dépassée, et non mesurable faute de dénominateur.
final _limites = <LimitePrudentielle>[
  _limite(
    code: 'RA006',
    etat: 'EP35',
    numerateur: 9000,
    denominateur: 40000,
    limite: 0.25,
    concerne: 'Sucrivoire SA',
  ),
  _limite(
    code: 'RA007',
    etat: 'EP35',
    numerateur: 1200,
    denominateur: 13200,
    limite: 0.15,
    concerne: 'Sucrivoire SA',
  ),
  _limite(
    code: 'RA008',
    etat: 'EP35',
    numerateur: 9000,
    denominateur: 13200,
    limite: 0.60,
  ),
  _limite(
    code: 'RA009',
    etat: 'EP36',
    numerateur: 500,
    denominateur: 0,
    limite: 0.15,
  ),
];

Future<void> _poser(WidgetTester tester, double largeur) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: largeur,
            // Hauteur non bornée, comme la colonne défilante qui porte la carte
            // dans l'onglet Portefeuille.
            child: ListView(
              children: [
                for (final limite in _limites) JaugeLimite(limite: limite),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('les jauges se posent sans exception à largeur courante',
      (tester) async {
    await _poser(tester, 960);
    expect(tester.takeException(), isNull);
  });

  testWidgets('les jauges se posent sans exception en fenêtre étroite',
      (tester) async {
    await _poser(tester, 420);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chaque limite annonce son état en clair, pas seulement en couleur',
      (tester) async {
    await _poser(tester, 960);

    // RA006 consomme 90 % de son plafond de 25 % : proche, pas dépassée.
    expect(find.text(EtatLimite.procheDuPlafond.libelle), findsOneWidget);
    expect(find.text('22.5 %'), findsOneWidget);
    expect(find.text('90 % du plafond'), findsOneWidget);

    // RA009 n'a pas de dénominateur : ni respectée, ni dépassée.
    expect(find.text(EtatLimite.nonMesurable.libelle), findsOneWidget);
    expect(find.text('non mesurable'), findsOneWidget);

    // Le libellé de la norme reste lisible, le code n'identifie plus la ligne
    // à lui seul.
    expect(find.text('RA006'), findsOneWidget);
    expect(
      find.text('Participation la plus forte dans une entité commerciale'),
      findsNWidgets(_limites.length),
    );
  });
}
