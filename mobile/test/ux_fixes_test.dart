import 'package:feya/core/router/app_router.dart';
import 'package:feya/data/models/models.dart';
import 'package:feya/features/cart/cart_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_test.dart' show pumpApp;
import 'support/fake_backend.dart';

void main() {
  setUpAll(() async {
    for (final l in ['ru', 'kk', 'en']) {
      await initializeDateFormatting(l);
    }
  });

  Future<String> typePhone(WidgetTester tester, String input) async {
    await tester.enterText(find.byType(TextFormField).first, input);
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).first);
    return field.controller!.text;
  }

  testWidgets('login phone field is formatted as +7 XXX XXX XX XX', (
    tester,
  ) async {
    final c = await pumpApp(tester, standardBackend());
    c.read(routerProvider).go('/login');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(await typePhone(tester, '7010000000'), '+7 701 000 00 00');
    // a leading 8 is treated as +7, extra digits are dropped
    expect(await typePhone(tester, '87010000000999'), '+7 701 000 00 00');
    // partial input is grouped as it is typed
    expect(await typePhone(tester, '+7 70100'), '+7 701 00');
  });

  testWidgets('the cart shows the server-localized product and variant names', (
    tester,
  ) async {
    final c = await pumpApp(tester, standardBackend());
    // the snapshot saved when the item was added (possibly in another language)
    c
        .read(cartProvider.notifier)
        .add(
          productId: 'magiya',
          productName: 'Старое название',
          variant: const Variant(
            id: 'v-m',
            code: 'STANDARD',
            label: 'Старый размер',
            price: 23900,
            stemsCount: 15,
            available: true,
            maxQuantity: 5,
          ),
          imageUrl: null,
          quantity: 1,
        );
    await tester.tap(find.text('Корзина'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    // the fake quote answers with the names the server would send for the active language
    expect(find.text('Магия чувств'), findsOneWidget);
    expect(find.text('Вариант'), findsOneWidget);
    expect(find.text('Старое название'), findsNothing);
    expect(find.text('Старый размер'), findsNothing);
  });
}
