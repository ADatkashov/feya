import 'package:feya/core/network/api_exception.dart';
import 'package:feya/data/repositories/repositories.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

Map<String, dynamic> tracking(String status, {Map<String, dynamic>? loc}) => {
  'orderId': 'o1',
  'number': 'FEYA-1',
  'status': status,
  'paymentStatus': 'PAID',
  'timeline': [],
  'courier': {'name': 'Алексей', 'phone': '+7700'},
  'courierLocation': loc,
  'liveTracking': loc != null,
};

void main() {
  test(
    'tracking updates arrive by polling immediately and keep coming',
    () async {
      final adapter = FakeAdapter();
      var n = 0;
      adapter.on(
        'GET /orders/o1/tracking',
        (_) => FakeResponse(tracking(n++ == 0 ? 'PICKED_UP' : 'ON_THE_WAY')),
      );
      final repo = OrderRepository(buildClient(adapter));
      final events = <String>[];
      final sub = repo
          .watchTracking('o1', poll: const Duration(milliseconds: 40))
          .listen((t) => events.add(t.status));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      expect(events.first, 'PICKED_UP');
      expect(events, contains('ON_THE_WAY'));
    },
  );

  test(
    'a missing order ends the stream with an error instead of polling forever',
    () async {
      final adapter = FakeAdapter()
        ..json('GET /orders/o1/tracking', {
          'code': 'NOT_FOUND',
          'message': 'x',
        }, status: 404);
      final repo = OrderRepository(buildClient(adapter));
      await expectLater(
        repo.watchTracking('o1', poll: const Duration(milliseconds: 30)),
        emitsError(isA<ApiException>()),
      );
    },
  );

  test('a transient network failure does not break the stream', () async {
    final adapter = FakeAdapter();
    var calls = 0;
    adapter.on('GET /orders/o1/tracking', (o) {
      calls++;
      if (calls == 1)
        return FakeResponse({
          'code': 'INTERNAL_ERROR',
          'message': 'x',
        }, status: 500);
      return FakeResponse(tracking('ON_THE_WAY'));
    });
    final repo = OrderRepository(buildClient(adapter));
    final first = await repo
        .watchTracking('o1', poll: const Duration(milliseconds: 30))
        .first;
    expect(first.status, 'ON_THE_WAY');
  });

  test('live location is exposed only when the backend says so', () async {
    final adapter = FakeAdapter()
      ..json(
        'GET /orders/o1/tracking',
        tracking(
          'ON_THE_WAY',
          loc: {
            'latitude': 43.2,
            'longitude': 76.9,
            'updatedAt': '2026-11-02T06:00:00Z',
          },
        ),
      );
    final t = await OrderRepository(buildClient(adapter)).tracking('o1');
    expect(t.liveTracking, isTrue);
    expect(t.location!.latitude, 43.2);
  });
}
