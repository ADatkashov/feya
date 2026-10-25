import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:feya/core/network/api_client.dart';
import 'package:feya/core/providers.dart';
import 'package:feya/core/storage/token_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:shared_preferences/shared_preferences.dart';

class FakeResponse {
  FakeResponse(this.body, {this.status = 200});
  final Object? body;
  final int status;
}

typedef Handler = FutureOr<FakeResponse> Function(RequestOptions options);

/// An in-memory HTTP adapter: routes are matched on "METHOD /path" (query string ignored).
class FakeAdapter implements HttpClientAdapter {
  final Map<String, Handler> routes = {};
  final List<RequestOptions> calls = [];

  void on(String route, Handler handler) => routes[route] = handler;
  void json(String route, Object? body, {int status = 200}) =>
      routes[route] = (_) => FakeResponse(body, status: status);

  int count(String route) =>
      calls.where((c) => '${c.method} ${c.path}' == route).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final handler = routes['${options.method} ${options.path}'];
    if (handler == null) {
      return ResponseBody.fromString(
        jsonEncode({'code': 'NOT_FOUND', 'message': 'no route'}),
        404,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    final r = await handler(options);
    return ResponseBody.fromString(
      jsonEncode(r.body),
      r.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient buildClient(
  FakeAdapter adapter, {
  TokenStore? tokens,
  void Function()? onExpired,
  String lang = 'ru',
}) {
  final dio = Dio()..httpClientAdapter = adapter;
  final refreshDio = Dio()..httpClientAdapter = adapter;
  return ApiClient(
    tokens: tokens ?? MemoryTokenStore(),
    language: () => lang,
    dio: dio,
    refreshDio: refreshDio,
    baseUrl: 'http://fake/api/v1',
    onSessionExpired: onExpired,
  );
}

Future<ProviderContainer> buildContainer(
  FakeAdapter adapter, {
  Map<String, Object> prefs = const {},
  TokenStore? tokens,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final store = tokens ?? MemoryTokenStore();
  final container = ProviderContainer(
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
  return container;
}

// ---- sample payloads ------------------------------------------------------------------------

Map<String, dynamic> productJson(
  String id,
  String name, {
  double price = 15900,
  bool available = true,
}) => {
  'id': id,
  'slug': id,
  'name': name,
  'imageUrl': null,
  'priceFrom': price,
  'currency': 'KZT',
  'ratingAvg': null,
  'ratingCount': 0,
  'available': available,
  'favorite': false,
  'category': 'mixed',
};

Map<String, dynamic> homeJson() => {
  'banners': [
    {
      'id': 'b1',
      'title': 'Весна с FEYA',
      'subtitle': '−10%',
      'imageUrl': null,
      'promoCode': 'FEYA10',
      'targetType': 'category',
      'targetValue': 'mixed',
    },
  ],
  'categories': [
    {'id': 'c1', 'slug': 'roses', 'name': 'Розы'},
    {'id': 'c2', 'slug': 'peonies', 'name': 'Пионы'},
  ],
  'featured': [productJson('magiya', 'Магия чувств')],
  'popular': [productJson('romantika', 'Романтика', price: 12900)],
  'newArrivals': <dynamic>[],
  'seasonal': <dynamic>[],
};

Map<String, dynamic> detailJson() => {
  'id': 'magiya',
  'slug': 'magiya',
  'name': 'Магия чувств',
  'description': 'Роскошный букет',
  'composition': 'Пионы, розы',
  'category': 'Смешанные',
  'categorySlug': 'mixed',
  'images': [],
  'variants': [
    {
      'id': 'v-s',
      'code': 'SMALL',
      'label': 'Малый',
      'price': 15900,
      'stemsCount': 9,
      'available': true,
      'maxQuantity': 5,
    },
    {
      'id': 'v-m',
      'code': 'STANDARD',
      'label': 'Стандартный',
      'price': 23900,
      'stemsCount': 15,
      'available': true,
      'maxQuantity': 5,
    },
    {
      'id': 'v-l',
      'code': 'LARGE',
      'label': 'Большой',
      'price': 35900,
      'stemsCount': 25,
      'available': false,
      'maxQuantity': 0,
    },
  ],
  'priceFrom': 15900,
  'currency': 'KZT',
  'ratingAvg': null,
  'ratingCount': 0,
  'available': true,
  'favorite': false,
  'prepMinutes': 90,
};

FakeAdapter standardBackend() {
  final a = FakeAdapter();
  a.json('GET /home', homeJson());
  a.json('GET /categories', homeJson()['categories']);
  a.json('GET /delivery/zones', [
    {
      'id': 'z1',
      'code': 'almaty-center',
      'name': 'Алматы — центр',
      'baseFee': 1500,
      'freeDeliveryThreshold': 25000,
      'asapEnabled': true,
      'asapFee': 1500,
      'asapEtaMinutes': 90,
    },
  ]);
  a.json('GET /products/magiya', detailJson());
  a.json('GET /products/magiya/related', []);
  a.json('GET /products/magiya/reviews', {
    'content': [],
    'page': 0,
    'size': 10,
    'totalElements': 0,
    'totalPages': 0,
    'hasNext': false,
  });
  a.json('GET /products', {
    'content': [
      productJson('magiya', 'Магия чувств'),
      productJson('romantika', 'Романтика'),
    ],
    'page': 0,
    'size': 20,
    'totalElements': 2,
    'totalPages': 1,
    'hasNext': false,
  });
  a.on('POST /cart/quote', (o) {
    final items = (o.data as Map)['items'] as List;
    final prices = {'v-s': 15900.0, 'v-m': 23900.0, 'v-l': 35900.0};
    var subtotal = 0.0;
    final lines = [
      for (final i in items)
        () {
          final q = (i as Map)['quantity'] as int;
          final price = prices[i['variantId']]!;
          subtotal += price * q;
          return {
            'variantId': i['variantId'],
            'productId': 'magiya',
            'productName': 'Магия чувств',
            'variantLabel': 'Вариант',
            'imageUrl': null,
            'unitPrice': price,
            'quantity': q,
            'lineTotal': price * q,
            'available': true,
            'maxQuantity': 5,
            'issue': null,
          };
        }(),
    ];
    final fee = subtotal >= 25000 ? 0.0 : 1500.0;
    return FakeResponse({
      'lines': lines,
      'subtotal': subtotal,
      'discount': 0,
      'promo': null,
      'deliveryFee': fee,
      'giftWrapFee': 0,
      'total': subtotal + fee,
      'currency': 'KZT',
      'zoneId': 'z1',
      'valid': true,
      'issues': <dynamic>[],
    });
  });
  return a;
}
