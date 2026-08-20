// Rend le PDF du FODEP à partir d'un contenu déposé sur le disque, pour le
// regarder. Ce n'est pas un cas de test : il ne vérifie rien, il produit un
// fichier. Le lanceur habituel l'ignore — son nom ne finit pas par « _test ».
//
//   flutter test test/rendu_fodep_pdf_manuel.dart \
//       --dart-define=CONTENU=<chemin.json> --dart-define=SORTIE=<chemin.pdf>
//
// Le contenu se produit côté backend :
//   contenu_fodep().model_dump_json()
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/modules/rapports/models/report_models.dart';
import 'package:rwa_calculator/modules/reporting_global/services/fodep_pdf.dart';

const String _contenu = String.fromEnvironment('CONTENU');
const String _sortie = String.fromEnvironment('SORTIE');

void main() {
  // Les polices du PDF viennent du bundle : la liaison doit exister.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('produit le PDF pour relecture', () async {
    expect(_contenu, isNotEmpty, reason: 'passer --dart-define=CONTENU=...');
    expect(_sortie, isNotEmpty, reason: 'passer --dart-define=SORTIE=...');

    final json = jsonDecode(await File(_contenu).readAsString());
    final contenu = ContenuFodep.fromJson(json as Map<String, dynamic>);
    final octets = await construireFodepPdf(contenu: contenu);

    await File(_sortie).writeAsBytes(octets, flush: true);
    stdout.writeln('PDF écrit : $_sortie (${octets.length} octets)');
  });
}
