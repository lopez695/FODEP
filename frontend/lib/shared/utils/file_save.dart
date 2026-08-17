import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

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

/// Codes d'erreur Windows signalant un fichier tenu ouvert ailleurs.
const int _partageRefuseWindows = 32; // ERROR_SHARING_VIOLATION
const int _verrouRefuseWindows = 33; // ERROR_LOCK_VIOLATION

/// Le fichier de destination est ouvert dans une autre application.
///
/// Le cas est courant et sans gravité : on réexporte vers un fichier resté
/// ouvert dans Excel depuis l'export précédent. Le message système
/// (« PathAccessException... errno = 32 ») ne dit pas quoi faire ; cette
/// exception le remplace par la seule information utile.
class FichierVerrouilleException implements Exception {
  const FichierVerrouilleException(this.path);

  final String path;

  String get nomFichier => path.split(RegExp(r'[\\/]')).last;

  String get message =>
      '« $nomFichier » est ouvert dans une autre application. '
      'Fermez-le, puis relancez l\'export.';

  @override
  String toString() => message;
}

Future<File> saveBytesAtLocation(
  FileSaveLocation location,
  Uint8List bytes, {
  required String requiredExtension,
}) async {
  final targetPath = ensureRequiredFileExtension(
    location.path,
    requiredExtension,
  );
  final file = File(targetPath);
  try {
    await file.writeAsBytes(bytes, flush: true);
  } on FileSystemException catch (erreur) {
    final code = erreur.osError?.errorCode;
    if (code == _partageRefuseWindows || code == _verrouRefuseWindows) {
      throw FichierVerrouilleException(targetPath);
    }
    rethrow;
  }
  return file;
}
