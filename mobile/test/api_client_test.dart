import 'package:dio/dio.dart';
import 'package:feya/core/network/api_exception.dart';
import 'package:feya/core/storage/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

void main() {
  test('adds bearer token and language headers', () async {
    final adapter = FakeAdapter()..json('GET /me', {'ok': true});
    final tokens = MemoryTokenStore();
    await tokens.save(access: 'A1', refresh: 'R1');
    final api = buildClient(adapter, tokens: tokens, lang: 'kk');
    await api.get('/me');
    final h = adapter.calls.single.headers;
    expect(h['Authorization'], 'Bearer A1');
    expect(h['Accept-Language'], 'kk');
  });

  test('public calls do not send credentials', () async {
    final adapter = FakeAdapter()..json('GET /home', {});
    final tokens = MemoryTokenStore();
    await tokens.save(access: 'A1', refresh: 'R1');
    await buildClient(adapter, tokens: tokens).get('/home', auth: false);
    expect(adapter.calls.single.headers.containsKey('Authorization'), isFalse);
  });

  test('an expired access token is refreshed once and the request retried', () async {
    final adapter = FakeAdapter();
    adapter.on('GET /me', (o) => o.headers['Authorization'] == 'Bearer A2' ? FakeResponse({'name': 'Анна'}) : FakeResponse({'code': 'UNAUTHORIZED', 'message': 'x'}, status: 401));
    adapter.json('POST /auth/refresh', {'accessToken': 'A2', 'refreshToken': 'R2'});
    final tokens = MemoryTokenStore();
    await tokens.save(access: 'A1', refresh: 'R1');
    final api = buildClient(adapter, tokens: tokens);
    final res = await api.get('/me') as Map;
    expect(res['name'], 'Анна');
    expect(adapter.count('POST /auth/refresh'), 1);
    expect(await tokens.readAccess(), 'A2');
    expect(await tokens.readRefresh(), 'R2');
  });

  test('concurrent 401s share a single refresh call', () async {
    final adapter = FakeAdapter();
    adapter.on('GET /a', (o) => o.headers['Authorization'] == 'Bearer A2' ? FakeResponse({'a': 1}) : FakeResponse({}, status: 401));
    adapter.on('GET /b', (o) => o.headers['Authorization'] == 'Bearer A2' ? FakeResponse({'b': 1}) : FakeResponse({}, status: 401));
    adapter.on('POST /auth/refresh', (o) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return FakeResponse({'accessToken': 'A2', 'refreshToken': 'R2'});
    });
    final tokens = MemoryTokenStore();
    await tokens.save(access: 'A1', refresh: 'R1');
    final api = buildClient(adapter, tokens: tokens);
    await Future.wait([api.get('/a'), api.get('/b')]);
    expect(adapter.count('POST /auth/refresh'), 1);
  });

  test('a rejected refresh ends the session and clears the tokens', () async {
    final adapter = FakeAdapter()
      ..json('GET /me', {'code': 'UNAUTHORIZED', 'message': 'x'}, status: 401)
      ..json('POST /auth/refresh', {'code': 'INVALID_REFRESH_TOKEN', 'message': 'x'}, status: 401);
    final tokens = MemoryTokenStore();
    await tokens.save(access: 'A1', refresh: 'R1');
    var expired = 0;
    final api = buildClient(adapter, tokens: tokens, onExpired: () => expired++);
    await expectLater(api.get('/me'), throwsA(isA<ApiException>().having((e) => e.isUnauthorized, 'isUnauthorized', true)));
    expect(expired, 1);
    expect(await tokens.readRefresh(), isNull);
  });

  test('a network failure during refresh keeps the session', () async {
    final adapter = FakeAdapter()..json('GET /me', {}, status: 401);
    adapter.on('POST /auth/refresh', (o) => throw DioException.connectionError(requestOptions: o, reason: 'offline'));
    final tokens = MemoryTokenStore();
    await tokens.save(access: 'A1', refresh: 'R1');
    var expired = 0;
    final api = buildClient(adapter, tokens: tokens, onExpired: () => expired++);
    await expectLater(api.get('/me'), throwsA(isA<ApiException>()));
    expect(expired, 0);
    expect(await tokens.readRefresh(), 'R1');
  });

  test('server errors are mapped to ApiException with code, message and field errors', () async {
    final adapter = FakeAdapter()
      ..json('POST /orders', {'code': 'VALIDATION_FAILED', 'message': 'Validation failed', 'fieldErrors': {'recipient.phone': 'invalid'}}, status: 400);
    final api = buildClient(adapter);
    try {
      await api.post('/orders', body: {});
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.status, 400);
      expect(e.code, 'VALIDATION_FAILED');
      expect(e.fieldErrors['recipient.phone'], 'invalid');
      expect(e.isNetwork, isFalse);
    }
  });

  test('transport failures become network errors; idempotent GETs are retried', () async {
    final adapter = FakeAdapter();
    var attempts = 0;
    adapter.on('GET /home', (o) {
      attempts++;
      if (attempts < 3) throw DioException.connectionError(requestOptions: o, reason: 'offline');
      return FakeResponse({'ok': true});
    });
    final api = buildClient(adapter);
    expect((await api.get('/home') as Map)['ok'], true);
    expect(attempts, 3);

    final adapter2 = FakeAdapter();
    var posts = 0;
    adapter2.on('POST /orders', (o) {
      posts++;
      throw DioException.connectionError(requestOptions: o, reason: 'offline');
    });
    await expectLater(buildClient(adapter2).post('/orders', body: {}), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)));
    expect(posts, 1, reason: 'POSTs must never be retried automatically');
  });
}
