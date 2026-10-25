import 'package:feya/core/providers.dart';
import 'package:feya/data/models/models.dart';
import 'package:feya/data/repositories/repositories.dart';
import 'package:feya/features/cart/cart_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

Variant variant(String id, {double price = 10000, int max = 5}) => Variant(
  id: id,
  code: 'STANDARD',
  label: 'Стандартный',
  price: price,
  stemsCount: 15,
  available: max > 0,
  maxQuantity: max,
);

void main() {
  late ProviderContainer c;

  setUp(() async {
    c = await buildContainer(standardBackend());
  });

  void add(String id, {int qty = 1, int max = 5}) => c
      .read(cartProvider.notifier)
      .add(
        productId: 'p-$id',
        productName: 'Букет $id',
        variant: variant(id, max: max),
        imageUrl: null,
        quantity: qty,
      );

  test('adding the same variant merges quantities', () {
    add('a');
    add('a', qty: 2);
    expect(c.read(cartProvider), hasLength(1));
    expect(c.read(cartProvider).single.quantity, 3);
    expect(c.read(cartCountProvider), 3);
  });

  test('quantity is capped at the available stock of the variant', () {
    add('a', qty: 4, max: 5);
    add('a', qty: 4, max: 5);
    expect(c.read(cartProvider).single.quantity, 5);
  });

  test('quantity can never exceed the global per-line limit', () {
    add('a', qty: 50, max: 0);
    expect(c.read(cartProvider).single.quantity, kMaxQuantityPerLine);
  });

  test('setQuantity updates, clamps and removes at zero', () {
    add('a');
    add('b');
    c.read(cartProvider.notifier).setQuantity('a', 4);
    expect(
      c.read(cartProvider).firstWhere((l) => l.variantId == 'a').quantity,
      4,
    );
    c.read(cartProvider.notifier).setQuantity('a', 999);
    expect(
      c.read(cartProvider).firstWhere((l) => l.variantId == 'a').quantity,
      kMaxQuantityPerLine,
    );
    c.read(cartProvider.notifier).setQuantity('a', 0);
    expect(c.read(cartProvider).map((l) => l.variantId), ['b']);
  });

  test('remove and clear', () {
    add('a');
    add('b');
    c.read(cartProvider.notifier).remove('a');
    expect(c.read(cartProvider), hasLength(1));
    c.read(cartProvider.notifier).clear();
    expect(c.read(cartProvider), isEmpty);
  });

  test('the cart is persisted and restored', () async {
    add('a', qty: 2);
    final raw = c.read(sharedPrefsProvider).getString('feya.cart.v1');
    expect(raw, isNotNull);
    final restored = await buildContainer(
      standardBackend(),
      prefs: {'feya.cart.v1': raw!},
    );
    final lines = restored.read(cartProvider);
    expect(lines.single.variantId, 'a');
    expect(lines.single.quantity, 2);
  });

  test('a corrupted persisted cart is ignored instead of crashing', () async {
    final broken = await buildContainer(
      standardBackend(),
      prefs: {'feya.cart.v1': '{not json'},
    );
    expect(broken.read(cartProvider), isEmpty);
  });

  test(
    'the quote comes from the server, not from client-side arithmetic',
    () async {
      add('v-m', qty: 2);
      final q = await c.read(quoteProvider.future);
      expect(q!.subtotal, 47800);
      expect(
        q.deliveryFee,
        0,
      ); // above the free-delivery threshold, decided by the server
      expect(q.total, 47800);
      final backend = standardBackend();
      final c2 = await buildContainer(backend);
      c2
          .read(cartProvider.notifier)
          .add(
            productId: 'p',
            productName: 'x',
            variant: variant('v-s', price: 1),
            imageUrl: null,
          );
      final q2 = await c2.read(quoteProvider.future);
      // the local snapshot price (1) is ignored: the server says 15 900 + 1 500 delivery
      expect(q2!.subtotal, 15900);
      expect(q2.total, 17400);
    },
  );

  test('an empty cart has no quote', () async {
    expect(await c.read(quoteProvider.future), isNull);
  });

  test('checkout: changing the delivery zone clears the chosen slot', () {
    final ctl = c.read(checkoutProvider.notifier);
    ctl.setAddress(addressId: 'a1', address: null, zoneId: 'z1');
    ctl.chooseSlot(
      const SlotChoice(
        templateId: 't',
        date: '2026-11-03',
        start: '12:00',
        end: '14:00',
      ),
    );
    expect(c.read(checkoutProvider).slot, isNotNull);
    ctl.setAddress(
      addressId: 'a1',
      address: null,
      zoneId: 'z1',
    ); // same zone keeps it
    expect(c.read(checkoutProvider).slot, isNotNull);
    ctl.setAddress(addressId: 'a2', address: null, zoneId: 'z2');
    expect(c.read(checkoutProvider).slot, isNull);
    expect(c.read(checkoutProvider).hasDeliveryTime, isFalse);
  });

  test('checkout: ASAP and a scheduled slot are mutually exclusive', () {
    final ctl = c.read(checkoutProvider.notifier);
    ctl.chooseSlot(
      const SlotChoice(
        templateId: 't',
        date: '2026-11-03',
        start: '12:00',
        end: '14:00',
      ),
    );
    ctl.chooseAsap();
    expect(c.read(checkoutProvider).asap, isTrue);
    expect(c.read(checkoutProvider).slot, isNull);
    ctl.chooseSlot(
      const SlotChoice(
        templateId: 't',
        date: '2026-11-03',
        start: '12:00',
        end: '14:00',
      ),
    );
    expect(c.read(checkoutProvider).asap, isFalse);
  });

  test('checkout: blank promo codes are cleared and reset works', () {
    final ctl = c.read(checkoutProvider.notifier);
    ctl.setPromo('  FEYA10 ');
    expect(c.read(checkoutProvider).promoCode, 'FEYA10');
    ctl.setPromo('   ');
    expect(c.read(checkoutProvider).promoCode, isNull);
    ctl.update((s) => s.copyWith(acceptTerms: true, giftWrap: true));
    ctl.reset();
    expect(c.read(checkoutProvider).acceptTerms, isFalse);
  });
}
