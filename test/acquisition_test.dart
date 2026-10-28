import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pago_app/services/acquisition_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AcquisitionSource.parse', () {
    test('lê utm do link da Play', () {
      final source = AcquisitionSource.parse(
        'utm_source=Instagram&utm_medium=cpc&utm_campaign=lancamento-out&utm_content=video1',
      );
      expect(source.source, 'instagram');
      expect(source.medium, 'cpc');
      expect(source.campaign, 'lancamento-out');
      expect(source.content, 'video1');
    });

    test('sem utm a origem é orgânica', () {
      for (final raw in [null, '', 'gclid=abc']) {
        final source = AcquisitionSource.parse(raw);
        expect(source.source, 'organico');
        expect(source.medium, 'organico');
      }
    });

    test('texto fora do padrão é saneado e limitado', () {
      final source = AcquisitionSource.parse(
        'utm_source=${'a' * 100}&utm_campaign=Promo%20Fim%20de%20Ano!!',
      );
      expect(source.source.length, 64);
      expect(source.campaign, 'promofimdeano');
      expect(source.medium, 'indefinido');
    });
  });

  group('AcquisitionService.registerOnce', () {
    test('envia uma vez por conta e guarda que já enviou', () async {
      SharedPreferences.setMockInitialValues({});
      final calls = <http.Request>[];
      final service = AcquisitionService(
        httpClient: MockClient((request) async {
          calls.add(request);
          return http.Response('{}', 200);
        }),
        baseUrl: 'https://exemplo.test/api',
        idToken: () async => 'token',
        readReferrer: () async => 'utm_source=google&utm_medium=cpc',
      );

      expect(await service.registerOnce('u1'), isTrue);
      expect(await service.registerOnce('u1'), isTrue);
      expect(calls, hasLength(1));
      expect(calls.single.url.toString(), 'https://exemplo.test/api/acquisition/register');
      final body = jsonDecode(calls.single.body) as Map<String, dynamic>;
      expect(body['source'], 'google');
      expect(body['medium'], 'cpc');
      expect(body.keys, isNot(contains('email')));
    });

    test('falha do servidor tenta de novo no próximo acesso', () async {
      SharedPreferences.setMockInitialValues({});
      var status = 500;
      final calls = <int>[];
      final service = AcquisitionService(
        httpClient: MockClient((request) async {
          calls.add(status);
          return http.Response('{}', status);
        }),
        baseUrl: 'https://exemplo.test/api',
        idToken: () async => 'token',
        readReferrer: () async => null,
      );
      expect(await service.registerOnce('u1'), isFalse);
      status = 200;
      expect(await service.registerOnce('u1'), isTrue);
      expect(calls, [500, 200]);
    });
  });
}
