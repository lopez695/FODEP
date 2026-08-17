import 'package:http/http.dart' as http;

/// Client HTTP par défaut hors navigateur : rien de particulier à configurer,
/// les cookies ne concernent que le web.
http.Client createHttpClient() => http.Client();
