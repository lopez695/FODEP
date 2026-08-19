/// Fichier effectivement produit par un export.
///
/// Sur poste de travail, [path] est le chemin complet écrit sur le disque ;
/// sur le web, le nom sous lequel le navigateur a téléchargé le fichier.
class FichierEnregistre {
  const FichierEnregistre(this.path);

  final String path;
}

/// Le fichier de destination est ouvert dans une autre application.
///
/// Le cas est courant et sans gravité : on réexporte vers un fichier resté
/// ouvert dans Excel depuis l'export précédent. Le message système
/// (« PathAccessException... errno = 32 ») ne dit pas quoi faire ; cette
/// exception le remplace par la seule information utile.
class FichierVerrouilleException implements Exception {
  const FichierVerrouilleException(this.path);

  final String path;

  String get nomFichier => path.split(RegExp(r'[\/]')).last;

  String get message =>
      '« $nomFichier » est ouvert dans une autre application. '
      'Fermez-le, puis relancez l\'export.';

  @override
  String toString() => message;
}
