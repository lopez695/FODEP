// L'enregistrement d'un export dans un navigateur.
//
// La version precedente ecrivait le fichier avec « dart:io », ce que le web ne
// sait pas faire : l'export FODEP s'y terminait par « Unsupported operation:
// _Namespace ». Ce cas s'execute pour de vrai dans Chrome
// (« flutter test --platform chrome ») ; sur la machine virtuelle Dart, c'est
// l'implementation poste de travail qui serait choisie, et le cas n'aurait
// aucun sens.
@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/shared/utils/file_save.dart';

void main() {
  test('le fichier est telecharge sous le nom propose', () async {
    // Sur le web, « getSaveLocation » ne demande rien et renvoie un chemin
    // vide : le nom propose est la seule identite du fichier.
    final enregistre = await saveBytesAtLocation(
      const FileSaveLocation(''),
      Uint8List.fromList(<int>[1, 2, 3]),
      requiredExtension: '.xlsx',
      suggestedName: 'FODEP_31122025',
    );

    expect(enregistre.path, 'FODEP_31122025.xlsx');
  });

  test('une extension deja presente n est pas doublee', () async {
    final enregistre = await saveBytesAtLocation(
      const FileSaveLocation(''),
      Uint8List.fromList(<int>[1, 2, 3]),
      requiredExtension: '.pdf',
      suggestedName: 'rapport_global.pdf',
    );

    expect(enregistre.path, 'rapport_global.pdf');
  });
}
