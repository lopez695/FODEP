// Ce fichier encapsule les appels HTTP bas niveau.
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException({
    required this.method,
    required this.path,
    required this.statusCode,
    this.detail,
  });

  final String method;
  final String path;
  final int statusCode;
  final dynamic detail;

  String get message {
    if (detail is String && (detail as String).trim().isNotEmpty) {
      return detail as String;
    }
    if (detail is Map) {
      final detailMap = Map<String, dynamic>.from(detail as Map);
      final payloadMessage = detailMap['message'];
      if (payloadMessage is String && payloadMessage.trim().isNotEmpty) {
        return payloadMessage;
      }
    }
    return '$method $path failed with $statusCode';
  }

  @override
  String toString() => message;
}

/// Client HTTP minimal chargé des appels API bas niveau.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.tokenProvider,
    this.onUnauthorized,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Fournit le jeton d'accès courant, ou null quand l'API ne l'exige pas.
  /// Le jeton n'est jamais mémorisé ici : il est relu à chaque appel, sinon un
  /// renouvellement laisserait ce client avec un jeton périmé.
  final String? Function()? tokenProvider;

  /// Tente de renouveler la session après un 401. Retourne vrai si un nouveau
  /// jeton est disponible et que la requête peut être rejouée.
  final Future<bool> Function()? onUnauthorized;

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    final token = tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Joue la requête, et la rejoue une seule fois si le jeton vient d'expirer.
  ///
  /// Une seule tentative de renouvellement : boucler sur un 401 persistant
  /// enfermerait l'application dans une série d'appels sans fin.
  Future<http.Response> _envoyer(
    Future<http.Response> Function() requete,
  ) async {
    final reponse = await requete();
    if (reponse.statusCode != 401 || onUnauthorized == null) {
      return reponse;
    }
    final renouvele = await onUnauthorized!.call();
    if (!renouvele) {
      return reponse;
    }
    return requete();
  }

  Future<dynamic> get(String path) async {
    final separator = path.contains('?') ? '&' : '?';
    final cacheBuster = '${separator}_t=${DateTime.now().millisecondsSinceEpoch}';
    final response = await _envoyer(
      () => _client.get(
        Uri.parse('$baseUrl$path$cacheBuster'),
        headers: _headers(),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        method: 'GET',
        path: path,
        statusCode: response.statusCode,
        detail: _decodeErrorDetail(response.body),
      );
    }
    return _decodeSuccessBody(response.body);
  }

  Future<Uint8List> getBytes(String path) async {
    final reponse = await getBytesAvecEntetes(path);
    return reponse.bytes;
  }

  /// Télécharge un fichier sans perdre les en-têtes de la réponse.
  ///
  /// Certains exports transmettent, à côté du fichier, ce que l'utilisateur
  /// doit savoir avant de s'en servir — les réserves de lecture du FODEP, par
  /// exemple. `getBytes` les jetterait avec le reste de la réponse.
  Future<({Uint8List bytes, Map<String, String> headers})> getBytesAvecEntetes(
    String path,
  ) async {
    final separator = path.contains('?') ? '&' : '?';
    final cacheBuster = '${separator}_t=${DateTime.now().millisecondsSinceEpoch}';
    final response = await _envoyer(
      () => _client.get(
        Uri.parse('$baseUrl$path$cacheBuster'),
        headers: _headers(),
      ),
    );
    _ensureSuccess(method: 'GET', path: path, response: response);
    return (bytes: response.bodyBytes, headers: response.headers);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await _envoyer(
      () => _client.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
    );
    _ensureSuccess(method: 'POST', path: path, response: response);
    return _decodeSuccessBody(response.body);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await _envoyer(
      () => _client.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
    );
    _ensureSuccess(method: 'PUT', path: path, response: response);
    return _decodeSuccessBody(response.body);
  }

  Future<dynamic> delete(String path) async {
    final response = await _envoyer(
      () => _client.delete(
        Uri.parse('$baseUrl$path'),
        headers: _headers(),
      ),
    );
    _ensureSuccess(method: 'DELETE', path: path, response: response);
    return _decodeSuccessBody(response.body);
  }

  Future<dynamic> uploadBytes(
    String path,
    Uint8List bytes,
    String filename, {
    Map<String, String> fields = const {},
  }) async {
    Future<http.Response> envoi() async {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
        ..fields.addAll(fields)
        ..headers.addAll(_headers())
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: filename,
          ),
        );
      final streamedResponse = await _client.send(request);
      return http.Response.fromStream(streamedResponse);
    }

    final response = await _envoyer(envoi);
    _ensureSuccess(method: 'POST', path: path, response: response);
    return _decodeSuccessBody(response.body);
  }

  void _ensureSuccess({
    required String method,
    required String path,
    required http.Response response,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw ApiException(
      method: method,
      path: path,
      statusCode: response.statusCode,
      detail: _decodeErrorDetail(response.body),
    );
  }

  dynamic _decodeSuccessBody(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    return jsonDecode(body);
  }

  dynamic _decodeErrorDetail(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
        return decoded['detail'];
      }
      return decoded;
    } catch (_) {
      return body;
    }
  }
}
