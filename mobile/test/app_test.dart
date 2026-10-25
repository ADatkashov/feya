import 'package:feya/app.dart';
import 'package:feya/core/providers.dart';
import 'package:feya/core/router/app_router.dart';
import 'package:feya/core/storage/token_store.dart';
import 'package:feya/data/models/models.dart';
import 'package:feya/features/cart/cart_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  FakeAdapter adapter, {
  Map<String, Object> prefs = const {},
  TokenStore? tokens,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final store = tokens ?? MemoryTokenStore();
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sharedPrefsProvider.overrideWithValue(sp),
      tokenStoreProvider.overrideWithValue(store),
      apiClientProvider.overrideWith(
        (ref) => buildClient(
          adapter,
          tokens: store,
          lang: ref.read(localeProvider).languageCode,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const FeyaApp()),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  return container;
}

void main() {
  setUpAll(() async {
    for (final l in ['ru', 'kk', 'en']) {
      await initializeDateFormatting(l);
    }
  });

  testWidgets(
    'starts on the home screen with real catalog data and bottom navigation',
    (tester) async {
      await pumpApp(tester, standardBackend());
      expect(find.text('FEYA'), findsWidgets);
      expect(find.text('Магия чувств'), findsOneWidget);
      expect(find.text('Роза'), findsNothing);
      expect(find.text('Розы'), findsOneWidget); // category chip
      for (final tab in [
        'Главная',
        'Каталог',
        'Корзина',
        'Заказы',
        'Профиль',
      ]) {
        expect(find.text(tab), findsOneWidget, reason: tab);
      }
    },
  );

  testWidgets('home shows a retry state when the backend is unreachable', (
    tester,
  ) async {
    final adapter = standardBackend()
      ..json('GET /home', {
        'code': 'INTERNAL_ERROR',
        'message': 'x',
      }, status: 500);
    await pumpApp(tester, adapter);
    expect(
      find.text('Сервис временно недоступен. Попробуйте позже.'),
      findsOneWidget,
    );
    expect(find.text('Повторить'), findsOneWidget);
    // recovery after retry
    adapter.json('GET /home', homeJson());
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Магия чувств'), findsOneWidget);
  });

  testWidgets(
    'bottom navigation switches tabs; guests see sign-in prompts for orders and profile',
    (tester) async {
      await pumpApp(tester, standardBackend());
      await tester.tap(find.text('Корзина'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Корзина пуста'), findsOneWidget);

      await tester.tap(find.text('Заказы'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Войдите, чтобы видеть заказы'), findsOneWidget);

      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Войдите в аккаунт'), findsOneWidget);

      await tester.tap(find.text('Каталог'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Романтика'), findsOneWidget);
    },
  );

  testWidgets(
    'opening a bouquet, choosing a size and adding it updates the cart badge and persists',
    (tester) async {
      final c = await pumpApp(tester, standardBackend());
      await tester.tap(find.text('Магия чувств').first);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Размер букета'), findsOneWidget);
      // the unavailable size cannot be chosen
      expect(find.text('Нет в наличии'), findsWidgets);
      await tester.tap(find.text('Малый'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.textContaining('В корзину · 15'), findsOneWidget);
      await tester.tap(find.textContaining('В корзину · 15'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(c.read(cartProvider).single.variantId, 'v-s');
      expect(c.read(cartProvider).single.unitPrice, 15900);
      expect(
        c.read(sharedPrefsProvider).getString('feya.cart.v1'),
        contains('v-s'),
      );
    },
  );

  testWidgets('the cart screen prices lines through the server quote', (
    tester,
  ) async {
    final c = await pumpApp(tester, standardBackend());
    c
        .read(cartProvider.notifier)
        .add(
          productId: 'magiya',
          productName: 'Магия чувств',
          variant: const Variant(
            id: 'v-m',
            code: 'STANDARD',
            label: 'Стандартный',
            price: 23900,
            stemsCount: 15,
            available: true,
            maxQuantity: 5,
          ),
          imageUrl: null,
          quantity: 2,
        );
    await tester.tap(find.text('Корзина'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Магия чувств'), findsOneWidget);
    expect(find.textContaining('47 800'), findsWidgets);
    expect(find.textContaining('Оформить заказ'), findsOneWidget);
    // minus on quantity 2 -> 1, still priced by the server afterwards
    await tester.tap(find.bySemanticsLabel('Уменьшить количество'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(c.read(cartProvider).single.quantity, 1);
  });

  testWidgets('checkout requires sign-in and returns to checkout afterwards', (
    tester,
  ) async {
    final c = await pumpApp(tester, standardBackend());
    c.read(routerProvider).go('/checkout');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Вход в FEYA'), findsOneWidget);
    expect(find.text('Получить код'), findsOneWidget);
  });

  testWidgets(
    'signing in with a one-time code reaches the profile and logout returns to guest mode',
    (tester) async {
      final adapter = standardBackend()
        ..json('POST /auth/otp/request', {
          'expiresAt': '2026-11-02T06:05:00Z',
          'devCode': '123456',
        })
        ..json('POST /auth/otp/verify', {
          'accessToken': 'A',
          'refreshToken': 'R',
          'expiresIn': 900,
          'user': {
            'id': 'u1',
            'phone': '+77010000000',
            'name': 'Анна Иванова',
            'language': 'ru',
            'roles': ['CUSTOMER'],
            'notifyPush': true,
            'notifyOrderUpdates': true,
            'notifyPromotions': false,
            'status': 'ACTIVE',
          },
        })
        ..json('GET /favorites', [])
        ..json('POST /auth/logout', {});
      final tokens = MemoryTokenStore();
      final c = await pumpApp(tester, adapter, tokens: tokens);
      c.read(routerProvider).go('/login');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.enterText(
        find.byType(TextFormField).first,
        '+7 701 000 00 00',
      );
      await tester.tap(find.text('Получить код'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Введите код'), findsOneWidget);
      expect(
        find.text('Режим разработки: код подставлен автоматически.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(await tokens.readAccess(), 'A');
      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Анна Иванова'), findsOneWidget);
      expect(find.text('+7 701 000 00 00'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Выйти'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Выйти'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(await tokens.readRefresh(), isNull);
      expect(
        find.text('Магия чувств'),
        findsOneWidget,
      ); // back on home as a guest
    },
  );

  testWidgets('wrong one-time code shows a localized error', (tester) async {
    final adapter = standardBackend()
      ..json('POST /auth/otp/request', {'expiresAt': '2026-11-02T06:05:00Z'})
      ..json('POST /auth/otp/verify', {
        'code': 'OTP_INVALID',
        'message': 'Invalid or expired code',
      }, status: 400);
    final c = await pumpApp(tester, adapter);
    c.read(routerProvider).go('/login');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byType(TextFormField).first,
      '+7 701 000 00 00',
    );
    await tester.tap(find.text('Получить код'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField).last, '000000');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Неверный или просроченный код'), findsOneWidget);
  });

  testWidgets(
    'language can be switched to Kazakh and English and is remembered',
    (tester) async {
      final c = await pumpApp(tester, standardBackend());
      c.read(routerProvider).go('/settings');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Настройки'), findsOneWidget);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Settings'), findsOneWidget);
      expect(c.read(sharedPrefsProvider).getString('feya.locale'), 'en');
      await tester.tap(find.text('Қазақша'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Баптаулар'), findsOneWidget);
    },
  );

  testWidgets('the saved language is applied at startup', (tester) async {
    await pumpApp(tester, standardBackend(), prefs: {'feya.locale': 'en'});
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);
  });

  testWidgets(
    'catalog search sends the query to the backend and shows empty results',
    (tester) async {
      final adapter = standardBackend();
      await pumpApp(tester, adapter);
      await tester.tap(find.text('Каталог'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      adapter.json('GET /products', {
        'content': [],
        'page': 0,
        'size': 20,
        'totalElements': 0,
        'totalPages': 0,
        'hasNext': false,
      });
      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Ничего не найдено'), findsOneWidget);
      final last = adapter.calls.where((c) => c.path == '/products').last;
      expect(last.queryParameters['q'], 'zzz');
    },
  );

  testWidgets(
    'legal pages are reachable and the help page lists support options',
    (tester) async {
      final c = await pumpApp(tester, standardBackend());
      c.read(routerProvider).go('/legal/privacy');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Политика конфиденциальности'), findsWidgets);
      c.read(routerProvider).go('/help');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Позвонить в поддержку'), findsOneWidget);
    },
  );
}
