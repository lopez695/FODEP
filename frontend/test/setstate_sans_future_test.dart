// `setState` ne doit jamais recevoir une flèche qui affecte un Future.
//
// Une flèche renvoie la valeur de l'affectation. Quand celle-ci est un Future,
// Flutter lève — en mode debug seulement :
//
//     setState() callback argument returned a Future.
//
// L'écran annonce alors un échec sur une opération qui a pourtant réussi, et le
// même code passe silencieusement en build de production. Le piège s'est
// refermé deux fois sur ce projet, la seconde après qu'un commentaire l'eut
// déjà décrit dans `participations_dialog.dart` : un commentaire ne se relit
// pas, un essai s'exécute.
//
// Le contrôle est textuel et volontairement étroit : il relève, fichier par
// fichier, les champs déclarés `Future<...>`, puis refuse qu'une flèche passée
// à `setState` leur affecte quoi que ce soit. Il ne prétend pas typer le code —
// il tient la forme exacte qui a mordu.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Les champs dont le type déclaré est un `Future`, dans un fichier donné.
///
/// Couvre les trois formes du projet : `Future<X> _f;`, `late Future<X> _f;` et
/// `Future<X>? _f;`.
Set<String> _champsFuture(String source) {
  final motif = RegExp(
    r'(?:late\s+)?(?:final\s+)?Future<[^>]*>\??\s+(_[A-Za-z0-9_]*)\s*[;=]',
  );
  return motif.allMatches(source).map((m) => m.group(1)!).toSet();
}

/// Les affectations faites par une flèche passée à `setState`.
Iterable<({String cible, int ligne})> _affectationsEnFleche(String source) sync* {
  final motif = RegExp(r'setState\(\(\)\s*=>\s*([A-Za-z0-9_.]+)\s*=[^=]');
  for (final correspondance in motif.allMatches(source)) {
    final cible = correspondance.group(1)!;
    yield (
      cible: cible.split('.').last,
      ligne: '\n'.allMatches(source.substring(0, correspondance.start)).length + 1,
    );
  }
}

void main() {
  test('aucun setState en flèche n\'affecte un Future', () {
    final racine = Directory('lib');
    expect(racine.existsSync(), isTrue,
        reason: 'l\'essai se lance depuis le dossier frontend');

    final fautifs = <String>[];
    for (final entree in racine.listSync(recursive: true)) {
      if (entree is! File || !entree.path.endsWith('.dart')) continue;
      final source = entree.readAsStringSync();
      if (!source.contains('setState(() =>')) continue;

      final futures = _champsFuture(source);
      if (futures.isEmpty) continue;

      for (final affectation in _affectationsEnFleche(source)) {
        if (futures.contains(affectation.cible)) {
          fautifs.add('${entree.path}:${affectation.ligne} '
              '— setState(() => ${affectation.cible} = …)');
        }
      }
    }

    expect(
      fautifs,
      isEmpty,
      reason: 'Une flèche renvoie la valeur affectée, et setState refuse un '
          'Future. Passez le corps entre accolades :\n'
          '  setState(() {\n    ${'\$champ'} = …;\n  });\n\n'
          'Sites en cause :\n  ${fautifs.join('\n  ')}',
    );
  });

  test('le contrôle sait reconnaître la forme fautive', () {
    // Sans cette vérification, un motif devenu inopérant laisserait passer le
    // défaut en silence — et l'essai resterait vert pour de mauvaises raisons.
    const fautif = '''
class _EcranState extends State<Ecran> {
  late Future<int> _future;
  void _recharger() {
    setState(() => _future = charger());
  }
}
''';
    expect(_champsFuture(fautif), contains('_future'));
    expect(
      _affectationsEnFleche(fautif).map((a) => a.cible),
      contains('_future'),
    );

    const correct = '''
class _EcranState extends State<Ecran> {
  late Future<int> _future;
  void _recharger() {
    setState(() {
      _future = charger();
    });
  }
}
''';
    expect(_affectationsEnFleche(correct), isEmpty);

    // Et une affectation en flèche qui ne porte pas sur un Future reste
    // permise : c'est le cas courant, et l'interdire ferait du bruit.
    const permis = '''
class _EcranState extends State<Ecran> {
  String _recherche = '';
  Future<int>? _future;
  void _filtrer(String v) {
    setState(() => _recherche = v);
  }
}
''';
    final futuresPermis = _champsFuture(permis);
    expect(
      _affectationsEnFleche(permis)
          .where((a) => futuresPermis.contains(a.cible)),
      isEmpty,
    );
  });
}
