import 'dart:async';

import 'package:feya/core/providers.dart';
import 'package:feya/core/router/app_router.dart';
import 'package:feya/core/storage/token_store.dart';
import 'package:feya/core/widgets/feya_button.dart';
import 'package:feya/data/models/courier_models.dart';
import 'package:feya/data/repositories/courier_repository.dart';
import 'package:feya/features/courier/courier_providers.dart';
import 'package:feya/features/courier/location_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_test.dart' show pumpApp;
import 'support/fake_backend.dart';

Map<String, dynamic> courierOrder(
  String id,
  String status, {
  bool mine = true,
}) => {
  'id': id,
  'number': 'FEYA-$id',
  'status': status,
  'pickupName': 'Достык',
  'pickupAddress': 'пр. Достык 1',
  'deliveryAddress': 'Алматы, Абая 10, кв. 5',
  'recipientName': mine ? 'Анна' : null,
  'recipientPhone': mine ? '+77011112233' : null,
  'instructions': mine ? 'Позвонить в домофон' : null,
  'deliveryDate': '2026-11-06',
  'slotStart': '10:00:00',
  'slotEnd': '12:00:00',
  'asap': false,
  'eta': '2026-11-06T05:30:00Z',
};

Map<String, dynamic> page(List<Map<String, dynamic>> items) => {
  'content': items,
  'page': 0,
  'size': 50,
  'totalElements': items.length,
  'totalPages': 1,
  'hasNext': false,
};

Map<String, dynamic> userJson(List<String> roles) => {
  'id': 'u1',
  'phone': '+77000000003',
  'name': 'Алексей',
  'email': null,
  'language': 'ru',
  'roles': roles,
  'notifyPush': true,
  'notifyOrderUpdates': true,
  'notifyPromotions': false,
  'status': 'ACTIVE',
};

/// A backend with one signed-in user and a mutable courier state.
class CourierBackend {
  CourierBackend({List<String> roles = const ['COURIER']}) {
    adapter = standardBackend()..json('GET /me', userJson(roles));
    adapter.on('GET /courier/me', (_) => FakeResponse(profile));
    adapter.on('PUT /courier/shift', (o) {
      final b = o.data as Map;
      profile = {
        ...profile,
        'onShift': b['onShift'],
        'locationSharing': b['locationSharing'],
      };
      return FakeResponse(profile);
    });
    adapter.on('GET /courier/orders', (o) {
      final scope = o.queryParameters['scope'];
      return FakeResponse(page(scope == 'available' ? available : mine));
    });
    adapter.on('POST /courier/orders/o1/claim', (_) {
      final o = {
        ...available.removeAt(0),
        ...courierOrder('o1', 'COURIER_ASSIGNED'),
      };
      mine.add(o);
      return FakeResponse(o);
    });
    adapter.on('POST /courier/orders/o2/status', (o) {
      final status = (o.data as Map)['status'] as String;
      mine[0] = {...mine[0], 'status': status};
      if (status == 'DELIVERED' || status == 'READY_FOR_PICKUP') mine.clear();
      return FakeResponse({...courierOrder('o2', status)});
    });
    adapter.on(
      'POST /courier/location',
      (_) => FakeResponse(null, status: 200),
    );
  }

  late final FakeAdapter adapter;
  Map<String, dynamic> profile = {
    'userId': 'u1',
    'vehicle': 'Скутер',
    'onShift': false,
    'locationSharing': false,
  };
  final List<Map<String, dynamic>> available = [];
  final List<Map<String, dynamic>> mine = [];
}

Future<MemoryTokenStore> signedIn() async {
  final t = MemoryTokenStore();
  await t.save(access: 'A', refresh: 'R');
  return t;
}

/// Leaves the app so polling timers of auto-disposed providers are cancelled before the test ends.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

class FakeLocationSource implements LocationSource {
  FakeLocationSource([this.access = LocationAccess.granted]);
  LocationAccess access;
  final controller = StreamController<GeoFix>.broadcast();
  int listeners = 0;

  @override
  Future<LocationAccess> ensureAccess() async => access;

  @override
  Stream<GeoFix> positions({
    required String notificationTitle,
    required String notificationText,
  }) => controller.stream;

  void emit(double lat, double lng) => controller.add(
    GeoFix(latitude: lat, longitude: lng, accuracyM: 5, at: DateTime.now()),
  );
}

void main() {
  setUpAll(() async {
    for (final l in ['ru', 'kk', 'en']) {
      await initializeDateFormatting(l);
    }
  });

  group('models', () {
    test('CourierOrder drops seconds from slots and finds the next action', () {
      final o = CourierOrder.fromJson(courierOrder('o1', 'COURIER_ASSIGNED'));
      expect(o.slotStart, '10:00');
      expect(o.slotEnd, '12:00');
      expect(o.nextStatus, 'PICKED_UP');
      expect(o.isAssigned, isTrue);
      expect(o.isCarrying, isFalse);
      expect(
        CourierOrder.fromJson(courierOrder('o1', 'PICKED_UP')).nextStatus,
        'ON_THE_WAY',
      );
      final last = CourierOrder.fromJson(courierOrder('o1', 'ON_THE_WAY'));
      expect(last.nextStatus, 'DELIVERED');
      expect(last.isCarrying, isTrue);
    });

    test('an unclaimed order has no next action and hides recipient data', () {
      final o = CourierOrder.fromJson(
        courierOrder('o1', 'READY_FOR_PICKUP', mine: false),
      );
      expect(o.isAssigned, isFalse);
      expect(o.nextStatus, isNull);
      expect(o.recipientPhone, isNull);
    });
  });

  group('repository', () {
    test('sendLocation omits recordedAt and null fields', () async {
      final b = CourierBackend();
      final repo = CourierRepository(buildClient(b.adapter));
      await repo.sendLocation(
        GeoFix(latitude: 43.2, longitude: 76.9, at: DateTime.now()),
      );
      final body = b.adapter.calls.last.data as Map;
      expect(body.keys, unorderedEquals(['latitude', 'longitude']));
    });

    test('setShift sends both flags', () async {
      final b = CourierBackend();
      final repo = CourierRepository(buildClient(b.adapter));
      final p = await repo.setShift(onShift: true, locationSharing: true);
      expect(p.onShift, isTrue);
      expect(p.locationSharing, isTrue);
    });
  });

  group('screen', () {
    testWidgets('a customer without the COURIER role sees no access', (
      tester,
    ) async {
      final b = CourierBackend(roles: ['CUSTOMER']);
      final c = await pumpApp(tester, b.adapter, tokens: await signedIn());
      c.read(routerProvider).go('/courier');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Раздел доступен только курьерам'), findsOneWidget);
      expect(b.adapter.count('GET /courier/me'), 0);
      await unmount(tester);
    });

    testWidgets('profile offers courier mode only to couriers', (tester) async {
      final b = CourierBackend();
      await pumpApp(tester, b.adapter, tokens: await signedIn());
      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Режим курьера'), findsOneWidget);
      await unmount(tester);

      final other = CourierBackend(roles: ['CUSTOMER']);
      await pumpApp(tester, other.adapter, tokens: await signedIn());
      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Режим курьера'), findsNothing);
      await unmount(tester);
    });

    testWidgets('claiming needs a shift, then the order moves to my orders', (
      tester,
    ) async {
      final b = CourierBackend()
        ..available.add(courierOrder('o1', 'READY_FOR_PICKUP', mine: false));
      final c = await pumpApp(tester, b.adapter, tokens: await signedIn());
      c.read(routerProvider).go('/courier');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      await tester.tap(find.text('Доступные'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('FEYA-o1'), findsOneWidget);
      // Recipient details are not shown before the order is claimed.
      expect(find.textContaining('+77011112233'), findsNothing);
      final claim = find.widgetWithText(FeyaButton, 'Взять заказ');
      expect(
        tester.widget<FeyaButton>(claim).onPressed,
        isNull,
        reason: 'claiming is disabled while off shift',
      );

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(b.profile['onShift'], isTrue);

      await tester.tap(find.widgetWithText(FeyaButton, 'Взять заказ'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(b.adapter.count('POST /courier/orders/o1/claim'), 1);

      await tester.tap(find.text('Мои заказы'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('FEYA-o1'), findsOneWidget);
      expect(find.textContaining('+77011112233'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('an order goes through pickup, on the way and delivered', (
      tester,
    ) async {
      final b = CourierBackend()
        ..profile = {
          'userId': 'u1',
          'vehicle': null,
          'onShift': true,
          'locationSharing': false,
        }
        ..mine.add(courierOrder('o2', 'COURIER_ASSIGNED'));
      final c = await pumpApp(tester, b.adapter, tokens: await signedIn());
      c.read(routerProvider).go('/courier');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      Future<void> tapAction(String label) async {
        final f = find.widgetWithText(FeyaButton, label);
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      }

      List<String> statuses() => [
        for (final call in b.adapter.calls)
          if (call.path == '/courier/orders/o2/status')
            (call.data as Map)['status'] as String,
      ];

      await tapAction('Забрал заказ');
      expect(statuses(), ['PICKED_UP']);
      await tapAction('Выехал к клиенту');
      expect(statuses(), ['PICKED_UP', 'ON_THE_WAY']);

      // Delivery asks for confirmation first; declining changes nothing.
      await tapAction('Отметить доставленным');
      expect(
        find.text('Подтвердить, что заказ вручён получателю?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Нет'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(statuses(), ['PICKED_UP', 'ON_THE_WAY']);

      await tapAction('Отметить доставленным');
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(statuses(), ['PICKED_UP', 'ON_THE_WAY', 'DELIVERED']);
      expect(find.text('Нет активных заказов'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('losing the race for an order shows a clear message', (
      tester,
    ) async {
      final b = CourierBackend()
        ..profile = {
          'userId': 'u1',
          'vehicle': null,
          'onShift': true,
          'locationSharing': false,
        }
        ..available.add(courierOrder('o1', 'READY_FOR_PICKUP', mine: false));
      b.adapter.json('POST /courier/orders/o1/claim', {
        'code': 'ALREADY_CLAIMED',
        'message': 'Order is already assigned',
      }, status: 409);
      final c = await pumpApp(tester, b.adapter, tokens: await signedIn());
      c.read(routerProvider).go('/courier');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(find.text('Доступные'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(find.widgetWithText(FeyaButton, 'Взять заказ'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Этот заказ уже взял другой курьер'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('location sharing', () {
    CourierBackend onShiftBackend({bool sharing = true}) => CourierBackend()
      ..profile = {
        'userId': 'u1',
        'vehicle': null,
        'onShift': true,
        'locationSharing': sharing,
      };

    test('uploads fixes while on shift, throttled, tagged with the order', () async {
      final b = onShiftBackend();
      final src = FakeLocationSource();
      final c = await _container(b, src, await signedIn());
      c.read(courierLocationProvider.notifier).setActiveOrder('o9');
      await c.read(courierProfileProvider.future);
      await _until(
        () => c.read(courierLocationProvider) == SharingStatus.active,
      );

      src.emit(43.2, 76.9);
      await _until(() => b.adapter.count('POST /courier/location') == 1);
      final body =
          b.adapter.calls.lastWhere((x) => x.path == '/courier/location').data
              as Map;
      expect(body['latitude'], 43.2);
      expect(body['longitude'], 76.9);
      expect(body['orderId'], 'o9');

      // A second fix inside the interval is dropped; one after it goes through.
      src.emit(43.21, 76.91);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(b.adapter.count('POST /courier/location'), 1);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      src.emit(43.22, 76.92);
      await _until(() => b.adapter.count('POST /courier/location') == 2);
    });

    test('nothing is uploaded when sharing is off', () async {
      final b = onShiftBackend(sharing: false);
      final src = FakeLocationSource();
      final c = await _container(b, src, await signedIn());
      await c.read(courierProfileProvider.future);
      src.emit(43.2, 76.9);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(b.adapter.count('POST /courier/location'), 0);
      expect(c.read(courierLocationProvider), SharingStatus.off);
    });

    test(
      'a denied permission is reported instead of failing silently',
      () async {
        final b = onShiftBackend();
        final src = FakeLocationSource(LocationAccess.denied);
        final c = await _container(b, src, await signedIn());
        await c.read(courierProfileProvider.future);
        await _until(
          () =>
              c.read(courierLocationProvider) == SharingStatus.permissionDenied,
        );
        src.emit(43.2, 76.9);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(b.adapter.count('POST /courier/location'), 0);
      },
    );

    test('going off shift stops the upload', () async {
      final b = onShiftBackend();
      final src = FakeLocationSource();
      final c = await _container(b, src, await signedIn());
      await c.read(courierProfileProvider.future);
      await _until(
        () => c.read(courierLocationProvider) == SharingStatus.active,
      );

      await c.read(courierProfileProvider.notifier).setShift(onShift: false);
      expect(c.read(courierLocationProvider), SharingStatus.off);
      src.emit(43.2, 76.9);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(b.adapter.count('POST /courier/location'), 0);
      expect(b.profile['locationSharing'], isFalse);
    });
  });
}

/// Container with a fake GPS source and a short upload interval; the location controller is started up front
/// (in the app the courier screen does that).
Future<ProviderContainer> _container(
  CourierBackend b,
  FakeLocationSource src,
  MemoryTokenStore tokens,
) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sharedPrefsProvider.overrideWithValue(sp),
      tokenStoreProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWith(
        (ref) => buildClient(b.adapter, tokens: tokens),
      ),
      locationSourceProvider.overrideWithValue(src),
      courierLocationIntervalProvider.overrideWithValue(
        const Duration(milliseconds: 200),
      ),
    ],
  );
  addTearDown(c.dispose);
  c.listen(
    courierLocationProvider,
    (_, _) {},
  ); // keep it alive like the screen does
  return c;
}

Future<void> _until(bool Function() cond) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!cond() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(cond(), isTrue, reason: 'condition not met in time');
}
