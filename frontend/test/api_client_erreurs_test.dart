// Ce qu'une panne du serveur donne à lire.
//
// En ligne, l'hébergeur est derrière une passerelle : quand l'application ne
// répond pas, c'est la passerelle qui répond à sa place, par une page HTML
// entière. Le client la recopiait dans l'exception, et l'écran l'affichait
// telle quelle — cinquante lignes de balises Cloudflare à la place d'une
// phrase. Ces essais tiennent la règle : le serveur a la parole tant qu'il dit
// quelque chose, et le code de statut est traduit quand il se tait.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:rwa_calculator/core/services/api_client.dart';

const _pageCloudflare = '''<!DOCTYPE html>
<html class="no-js" lang="en-US">
<head>
<title>onrender.com | 520: Web server is returning an unknown error</title>
<meta charset="UTF-8" />
</head>
<body>
<div id="cf-wrapper"><h1>Web server is returning an unknown error</h1>
<span class="code-label">Error code 520</span></div>
</body>
</html>''';

ApiClient _client(http.Response Function(http.Request) repondre) => ApiClient(
      baseUrl: 'https://exemple.test',
      client: MockClient((requete) async => repondre(requete)),
    );

Future<ApiException> _erreurDe(ApiClient client) async {
  try {
    await client.get('/rapports/fodep/analyse');
    fail('un statut hors 2xx doit lever');
  } on ApiException catch (erreur) {
    return erreur;
  }
}

void main() {
  test("une page d'erreur HTML ne remonte pas dans le message", () async {
    final erreur = await _erreurDe(
      _client((_) => http.Response(_pageCloudflare, 520)),
    );

    expect(erreur.message, isNot(contains('<')));
    expect(erreur.message, isNot(contains('DOCTYPE')));
    expect(erreur.message, contains('520'));
    expect(erreur.message, contains('réessayez'));
  });

  test('le motif du serveur est conservé quand il en donne un', () async {
    // Un refus métier porte sa raison : c'est elle qu'il faut lire, pas une
    // traduction du code de statut.
    final erreur = await _erreurDe(
      _client((_) => http.Response(
            '{"detail": {"code": "DEVISE_REFUSEE", '
            '"message": "La devise GBP n\'est pas convertible."}}',
            422,
          )),
    );

    expect(erreur.message, "La devise GBP n'est pas convertible.");
  });

  test('un texte simple est gardé, mais borné', () async {
    final erreur = await _erreurDe(
      _client((_) => http.Response('Traceback : ${'x' * 500}', 500)),
    );

    expect(erreur.message.length, lessThanOrEqualTo(200));
    expect(erreur.message, startsWith('Traceback :'));
  });

  test('un corps vide laisse parler le code de statut', () async {
    final erreur = await _erreurDe(_client((_) => http.Response('', 503)));

    expect(erreur.message, contains('503'));
    expect(erreur.message, contains("n'a pas répondu"));
  });

  test('un serveur plus ancien que l\'application se reconnaît', () async {
    // 404 et 405 sur une adresse que le client connaît : c'est le serveur qui
    // est en retard, et le message doit le dire plutôt que d'accuser le réseau.
    final absente = await _erreurDe(_client((_) => http.Response('', 404)));
    expect(absente.message, contains('plus ancien'));

    final refusee = await _erreurDe(_client((_) => http.Response('', 405)));
    expect(refusee.message, contains('plus ancien'));
  });
}
