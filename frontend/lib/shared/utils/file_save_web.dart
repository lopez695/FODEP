import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'file_save_types.dart';

/// Déclenche le téléchargement du fichier par le navigateur.
///
/// Sur le web, `getSaveLocation` ne demande rien à l'utilisateur : il renvoie
/// un emplacement au chemin vide, que `XFile.saveTo` ignore. Le seul élément
/// qui compte est donc le nom proposé — c'est celui que porte le fichier dans
/// le dossier des téléchargements.
Future<FichierEnregistre> saveBytesAtLocationImpl(
  FileSaveLocation location,
  Uint8List bytes, {
  required String requiredExtension,
  required String Function(String path, String extension) ensureExtension,
  required String suggestedName,
}) async {
  final nom = ensureExtension(suggestedName, requiredExtension);
  await XFile.fromData(bytes, name: nom).saveTo(location.path);
  return FichierEnregistre(nom);
}
