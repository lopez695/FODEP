import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Client HTTP du navigateur, autorisé à transporter les cookies.
///
/// Le jeton de renouvellement vit dans un cookie `HttpOnly` que le JavaScript
/// ne peut pas lire : sans `withCredentials`, le navigateur ne le joindrait pas
/// aux appels vers une API servie depuis une autre origine, et la session
/// serait perdue à chaque rechargement de page.
http.Client createHttpClient() => BrowserClient()..withCredentials = true;
