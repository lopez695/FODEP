// Service de récupération des taux de change courants depuis une source
// publique gratuite (sans clé d'API). Utilisé par la barre « Taux courants » du
// module Risque de Marché pour proposer, en plus de la saisie manuelle, une
// cotation en ligne lorsque l'utilisateur dispose d'une connexion Internet.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Origine d'un taux de change courant affiché dans la barre.
enum FxRateOrigin {
  /// Valeur initiale issue du référentiel interne (`CurrencyRegistry`).
  registry,

  /// Valeur saisie manuellement par l'utilisateur.
  manual,

  /// Valeur cotée en ligne via [FxRateService].
  online,
}

/// Cotation récupérée en ligne : taux + horodatage + source.
class LiveFxRate {
  const LiveFxRate({
    required this.rateToXof,
    required this.asOf,
    required this.provider,
  });

  /// Taux exprimé en XOF pour 1 unité de la devise demandée.
  final double rateToXof;

  /// Horodatage de la cotation tel que renvoyé par la source.
  final DateTime asOf;

  /// Nom lisible de la source (affiché à l'utilisateur).
  final String provider;
}

/// Erreur fonctionnelle remontée à l'interface avec un message déjà traduit,
/// prêt à être affiché tel quel.
class FxRateException implements Exception {
  FxRateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Récupère les taux de change courants depuis l'accès ouvert et gratuit de
/// ExchangeRate-API (`open.er-api.com`), qui ne nécessite aucune clé et publie
/// le XOF (franc CFA BCEAO).
class FxRateService {
  FxRateService({
    http.Client? client,
    Uri Function(String base)? endpointBuilder,
  })  : _client = client ?? http.Client(),
        _endpointBuilder = endpointBuilder ?? _defaultEndpoint;

  final http.Client _client;
  final Uri Function(String base) _endpointBuilder;

  static const String providerName = 'exchangerate-api.com';

  static Uri _defaultEndpoint(String base) =>
      Uri.parse('https://open.er-api.com/v6/latest/$base');

  /// Récupère le taux courant « 1 [code] = ? XOF ».
  ///
  /// Lève une [FxRateException] au message déjà formaté en cas d'absence de
  /// connexion, de source indisponible ou de réponse inexploitable.
  Future<LiveFxRate> fetchRateToXof(
    String code, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final base = code.trim().toUpperCase();
    if (base == 'XOF') {
      return LiveFxRate(
        rateToXof: 1.0,
        asOf: DateTime.now(),
        provider: providerName,
      );
    }

    final http.Response response;
    try {
      response = await _client.get(_endpointBuilder(base)).timeout(timeout);
    } on TimeoutException {
      throw FxRateException(
          'Délai dépassé - vérifiez votre connexion Internet.');
    } catch (_) {
      throw FxRateException(
          'Pas de connexion Internet ou source indisponible.');
    }

    if (response.statusCode != 200) {
      throw FxRateException(
          'Source indisponible (HTTP ${response.statusCode}).');
    }

    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw FxRateException('Réponse illisible de la source de cotation.');
    }

    if (payload['result'] != 'success') {
      final error = payload['error-type'] ?? payload['result'];
      throw FxRateException('La source a renvoyé une erreur ($error).');
    }

    final rates = payload['rates'];
    if (rates is! Map || rates['XOF'] is! num) {
      throw FxRateException('Taux XOF introuvable dans la réponse.');
    }

    final rate = (rates['XOF'] as num).toDouble();
    if (rate <= 0) {
      throw FxRateException('Taux XOF invalide renvoyé par la source.');
    }

    return LiveFxRate(
      rateToXof: rate,
      asOf: _parseAsOf(payload['time_last_update_unix']),
      provider: providerName,
    );
  }

  static DateTime _parseAsOf(Object? unixSeconds) {
    if (unixSeconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (unixSeconds * 1000).round(),
      );
    }
    return DateTime.now();
  }

  void dispose() => _client.close();
}
