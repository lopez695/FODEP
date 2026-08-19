import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'file_save_types.dart';

/// Codes d'erreur Windows signalant un fichier tenu ouvert ailleurs.
const int _partageRefuseWindows = 32; // ERROR_SHARING_VIOLATION
const int _verrouRefuseWindows = 33; // ERROR_LOCK_VIOLATION

/// Écrit le fichier au chemin que l'utilisateur a choisi.
///
/// [suggestedName] n'a servi qu'à préremplir la boîte de dialogue : ici, seul
/// le chemin retourné par celle-ci fait foi.
Future<FichierEnregistre> saveBytesAtLocationImpl(
  FileSaveLocation location,
  Uint8List bytes, {
  required String requiredExtension,
  required String Function(String path, String extension) ensureExtension,
  required String suggestedName,
}) async {
  final targetPath = ensureExtension(location.path, requiredExtension);
  try {
    await File(targetPath).writeAsBytes(bytes, flush: true);
  } on FileSystemException catch (erreur) {
    final code = erreur.osError?.errorCode;
    if (code == _partageRefuseWindows || code == _verrouRefuseWindows) {
      throw FichierVerrouilleException(targetPath);
    }
    rethrow;
  }
  return FichierEnregistre(targetPath);
}
