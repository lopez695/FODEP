import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'file_save_types.dart';

// L'écriture d'un fichier n'existe que sur poste de travail : sur le web, le
// navigateur seul décide où atterrit un téléchargement. Le test porte sur
// « dart.library.io » plutôt que sur « dart.library.html » car ce dernier est
// faux pour une compilation WebAssembly, qui repartirait alors sur « dart:io »
// et échouerait à l'exécution (« Unsupported operation: _Namespace »).
import 'file_save_web.dart'
    if (dart.library.io) 'file_save_io.dart' as platform;

export 'file_save_types.dart';

String ensureRequiredFileExtension(String path, String requiredExtension) {
  final trimmedExtension = requiredExtension.trim();
  if (trimmedExtension.isEmpty) {
    throw ArgumentError.value(
      requiredExtension,
      'requiredExtension',
      'L extension requise ne peut pas etre vide.',
    );
  }

  final normalizedExtension = trimmedExtension.startsWith('.')
      ? trimmedExtension
      : '.$trimmedExtension';
  if (path.toLowerCase().endsWith(normalizedExtension.toLowerCase())) {
    return path;
  }
  return '$path$normalizedExtension';
}

/// Enregistre [bytes] à l'emplacement choisi par l'utilisateur.
///
/// [suggestedName] est obligatoire parce qu'il est la seule identité du
/// fichier sur le web : le sélecteur y renvoie un emplacement vide, le
/// navigateur nommant lui-même le téléchargement. Sans lui, l'utilisateur
/// recevrait un fichier appelé « .xlsx ». Sur poste de travail, c'est le
/// chemin retourné par [FileSaveLocation] qui fait foi.
Future<FichierEnregistre> saveBytesAtLocation(
  FileSaveLocation location,
  Uint8List bytes, {
  required String requiredExtension,
  required String suggestedName,
}) {
  return platform.saveBytesAtLocationImpl(
    location,
    bytes,
    requiredExtension: requiredExtension,
    ensureExtension: ensureRequiredFileExtension,
    suggestedName: suggestedName,
  );
}
