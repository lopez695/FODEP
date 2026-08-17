import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Lit la configuration déposée par la page hôte.
///
/// L'URL de l'API n'est pas figée à la compilation : `index.html` peut porter
///
/// ```html
/// <script>window.RWA_CONFIG = { RWA_API_BASE_URL: "https://api.exemple.ci" };</script>
/// ```
///
/// ce qui permet de déplacer le backend sans reconstruire l'application. Sans
/// cette balise, la valeur par défaut relative `/api` s'applique : l'API est
/// alors servie par le même domaine, via le proxy inverse.
String? runtimeEnvironmentValue(String key) {
  final config = globalContext.getProperty<JSObject?>('RWA_CONFIG'.toJS);
  if (config == null) {
    return null;
  }
  final valeur = config.getProperty<JSAny?>(key.toJS);
  if (valeur == null) {
    return null;
  }
  final texte = valeur.dartify();
  return texte is String ? texte : null;
}
