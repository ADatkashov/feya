import 'package:feya/data/models/models.dart';
import 'package:feya/data/repositories/repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Quote parses money, promo and issues', () {
    final q = Quote.fromJson({
      'lines': [
        {
          'variantId': 'v',
          'productId': 'p',
          'productName': 'Букет',
          'variantLabel': 'L',
          'imageUrl': '/media/x.jpg',
          'unitPrice': 1000.5,
          'quantity': 2,
          'lineTotal': 2001,
          'available': true,
          'maxQuantity': 3,
          'issue': 'INSUFFICIENT_STOCK',
        },
      ],
      'subtotal': 2001,
      'discount': 200,
      'promo': {'code': 'FEYA10', 'applied': true, 'discount': 200},
      'deliveryFee': 1500,
      'giftWrapFee': 0,
      'total': 3301,
      'currency': 'KZT',
      'zoneId': 'z',
      'valid': false,
      'issues': ['INSUFFICIENT_STOCK:v'],
    });
    expect(q.total, 3301);
    expect(q.valid, isFalse);
    expect(q.promo!.applied, isTrue);
    expect(q.lines.single.issue, 'INSUFFICIENT_STOCK');
    expect(q.lines.single.imageUrl, endsWith('/media/x.jpg'));
    expect(q.lines.single.imageUrl, startsWith('http'));
  });

  test('SlotsResponse keeps day order and trims seconds', () {
    final s = SlotsResponse.fromJson({
      'zoneId': 'z',
      'asapAvailable': true,
      'asapFee': 1500,
      'asapEtaMinutes': 90,
      'days': [
        {
          'date': '2026-11-02',
          'slots': [
            {
              'templateId': 't1',
              'date': '2026-11-02',
              'start': '10:00:00',
              'end': '12:00:00',
              'available': false,
              'remaining': 6,
              'surcharge': 0,
              'unavailableReason': 'PAST_CUTOFF',
            },
          ],
        },
        {
          'date': '2026-11-03',
          'slots': [
            {
              'templateId': 't1',
              'date': '2026-11-03',
              'start': '10:00:00',
              'end': '12:00:00',
              'available': true,
              'remaining': 6,
              'surcharge': 500,
            },
          ],
        },
      ],
    });
    expect(s.days.keys.toList(), ['2026-11-02', '2026-11-03']);
    expect(s.days['2026-11-02']!.single.reason, 'PAST_CUTOFF');
    expect(s.days['2026-11-03']!.single.start, '10:00');
    expect(s.days['2026-11-03']!.single.surcharge, 500);
  });

  test('QuoteRequest and CreateOrderInput never contain prices or totals', () {
    const line = CartLine(
      variantId: 'v',
      productId: 'p',
      productName: 'n',
      variantLabel: 'l',
      imageUrl: null,
      unitPrice: 999,
      quantity: 2,
    );
    final quote = const QuoteRequest(
      lines: [line],
      promoCode: ' FEYA10 ',
      asap: true,
    ).toJson();
    expect(quote['items'], [
      {'variantId': 'v', 'quantity': 2},
    ]);
    expect(quote['promoCode'], 'FEYA10');
    expect(quote.keys, isNot(contains('total')));
    final order = const CreateOrderInput(
      lines: [line],
      addressId: 'a',
      recipientName: 'M',
      recipientPhone: '+7701',
      asap: true,
    ).toJson();
    expect(order['items'], [
      {'variantId': 'v', 'quantity': 2},
    ]);
    expect(order['acceptTerms'], true);
    expect(order.toString(), isNot(contains('999')));
  });

  test('OrderDetail builds a readable address and timeline', () {
    final o = OrderDetail.fromJson({
      'id': 'o',
      'number': 'FEYA-1001',
      'status': 'PAID',
      'paymentStatus': 'PAID',
      'currency': 'KZT',
      'subtotal': 100,
      'discount': 0,
      'deliveryFee': 0,
      'giftWrapFee': 0,
      'total': 100,
      'asap': false,
      'deliveryDate': '2026-11-03',
      'slotStart': '12:00:00',
      'slotEnd': '14:00:00',
      'eta': '2026-11-03T07:00:00Z',
      'address': {
        'city': 'Алматы',
        'street': 'Абая',
        'building': '10',
        'apartment': '5',
      },
      'recipientName': 'Мария',
      'recipientPhone': '+77011234567',
      'items': [],
      'canCancel': true,
      'canPay': false,
      'timeline': [
        {'status': 'PENDING_PAYMENT', 'at': '2026-11-02T06:00:00Z'},
        {'status': 'PAID', 'at': '2026-11-02T06:01:00Z'},
      ],
      'createdAt': '2026-11-02T06:00:00Z',
    });
    expect(o.addressLine, 'Алматы, Абая 10, кв. 5');
    expect(o.slotStart, '12:00');
    expect(o.timeline.map((e) => e.status), ['PENDING_PAYMENT', 'PAID']);
    expect(o.eta!.isUtc, isTrue);
  });

  test('Tracking without a courier location never invents one', () {
    final t = Tracking.fromJson({
      'orderId': 'o',
      'number': 'N',
      'status': 'ON_THE_WAY',
      'paymentStatus': 'PAID',
      'timeline': [],
      'liveTracking': false,
      'courier': {'name': 'Алексей', 'phone': '+7700'},
    });
    expect(t.location, isNull);
    expect(t.liveTracking, isFalse);
    expect(t.courier!.name, 'Алексей');
  });
}
