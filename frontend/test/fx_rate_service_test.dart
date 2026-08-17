import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rwa_calculator/modules/risque_marche/services/fx_rate_service.dart';

void main() {
  group('FxRateService.fetchRateToXof', () {
    test('renvoie le taux XOF et son horodatage en cas de succès', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), contains('/USD'));
        return http.Response(
          jsonEncode({
            'result': 'success',
            'time_last_update_unix': 1718800000,
            'base_code': 'USD',
            'rates': {'USD': 1, 'XOF': 612.34, 'EUR': 0.92},
          }),
          200,
        );
      });
      final service = FxRateService(client: client);

      final quote = await service.fetchRateToXof('USD');

      expect(quote.rateToXof, 612.34);
      expect(quote.provider, FxRateService.providerName);
      expect(
        quote.asOf,
        DateTime.fromMillisecondsSinceEpoch(1718800000 * 1000),
      );
    });

    test('XOF se résout localement à 1.0 sans appel réseau', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });
      final service = FxRateService(client: client);

      final quote = await service.fetchRateToXof('xof');

      expect(quote.rateToXof, 1.0);
      expect(called, isFalse);
    });

    test('lève une FxRateException si la source répond une erreur HTTP',
        () async {
      final client = MockClient((request) async => http.Response('nope', 503));
      final service = FxRateService(client: client);

      expect(
        () => service.fetchRateToXof('USD'),
        throwsA(isA<FxRateException>()),
      );
    });

    test('lève une FxRateException si le taux XOF est absent', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({
              'result': 'success',
              'rates': {'USD': 1, 'EUR': 0.92},
            }),
            200,
          ));
      final service = FxRateService(client: client);

      expect(
        () => service.fetchRateToXof('USD'),
        throwsA(isA<FxRateException>()),
      );
    });

    test('lève une FxRateException si la connexion échoue', () async {
      final client = MockClient((request) async {
        throw const _NetworkFailure();
      });
      final service = FxRateService(client: client);

      expect(
        () => service.fetchRateToXof('USD'),
        throwsA(isA<FxRateException>()),
      );
    });
  });
}

class _NetworkFailure implements Exception {
  const _NetworkFailure();
}
