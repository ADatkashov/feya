import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';

Map<String, dynamic> _map(dynamic v) => v as Map<String, dynamic>;
List<dynamic> _arr(dynamic v) => v as List<dynamic>;

// --------------------------------------------------------------------------------------------
// Auth & profile
// --------------------------------------------------------------------------------------------

class OtpChallenge {
  const OtpChallenge({required this.expiresAt, this.devCode});
  final DateTime expiresAt;

  /// Present only when the backend runs in development mode with dev OTP enabled.
  final String? devCode;
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });
  final String accessToken;
  final String refreshToken;
  final UserProfile user;
}

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<OtpChallenge> requestOtp(String phone) async {
    final j = _map(
      await _api.post('/auth/otp/request', body: {'phone': phone}, auth: false),
    );
    return OtpChallenge(
      expiresAt: DateTime.parse(j['expiresAt'] as String),
      devCode: j['devCode'] as String?,
    );
  }

  Future<AuthSession> verifyOtp(String phone, String code) async {
    final j = _map(
      await _api.post(
        '/auth/otp/verify',
        body: {'phone': phone, 'code': code},
        auth: false,
      ),
    );
    return AuthSession(
      accessToken: j['accessToken'] as String,
      refreshToken: j['refreshToken'] as String,
      user: UserProfile.fromJson(_map(j['user'])),
    );
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _api.post(
        '/auth/logout',
        body: {'refreshToken': refreshToken},
        auth: false,
      );
    } on ApiException {
      // Logging out locally must never fail because the server was unreachable.
    }
  }

  Future<UserProfile> me() async =>
      UserProfile.fromJson(_map(await _api.get('/me')));

  Future<UserProfile> updateProfile({
    String? name,
    String? email,
    String? language,
    bool? notifyPush,
    bool? notifyOrderUpdates,
    bool? notifyPromotions,
  }) async {
    final body = <String, dynamic>{
      'name': ?name,
      'email': ?email,
      'language': ?language,
      'notifyPush': ?notifyPush,
      'notifyOrderUpdates': ?notifyOrderUpdates,
      'notifyPromotions': ?notifyPromotions,
    };
    return UserProfile.fromJson(_map(await _api.patch('/me', body: body)));
  }

  Future<void> requestAccountDeletion() async {
    await _api.post('/me/deletion-request');
  }

  Future<void> registerDevice(String token, String platform) async {
    await _api.post(
      '/me/devices',
      body: {'token': token, 'platform': platform},
    );
  }
}

// --------------------------------------------------------------------------------------------
// Catalog
// --------------------------------------------------------------------------------------------

class ProductQuery {
  const ProductQuery({
    this.q,
    this.category,
    this.collection,
    this.sort,
    this.zoneId,
    this.page = 0,
    this.size = 20,
  });
  final String? q;
  final String? category;
  final String? collection;
  final String? sort;
  final String? zoneId;
  final int page;
  final int size;

  Map<String, dynamic> toQuery() => {
    if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
    'category': ?category,
    'collection': ?collection,
    'sort': ?sort,
    'zoneId': ?zoneId,
    'page': page,
    'size': size,
  };
}

class CatalogRepository {
  CatalogRepository(this._api);
  final ApiClient _api;

  Future<HomeData> home({String? zoneId}) async => HomeData.fromJson(
    _map(await _api.get('/home', query: {'zoneId': ?zoneId})),
  );

  Future<List<Category>> categories() async =>
      _arr(await _api.get('/categories'))
          .map((e) => Category.fromJson(_map(e)))
          .toList();

  Future<PageData<ProductSummary>> products(ProductQuery q) async =>
      PageData.fromJson(
        _map(await _api.get('/products', query: q.toQuery())),
        ProductSummary.fromJson,
      );

  Future<ProductDetail> product(String idOrSlug, {String? zoneId}) async =>
      ProductDetail.fromJson(
        _map(await _api.get('/products/$idOrSlug', query: {'zoneId': ?zoneId})),
      );

  Future<List<ProductSummary>> related(String id) async =>
      _arr(await _api.get('/products/$id/related'))
          .map((e) => ProductSummary.fromJson(_map(e)))
          .toList();

  Future<PageData<Review>> reviews(String productId, {int page = 0}) async =>
      PageData.fromJson(
        _map(
          await _api.get(
            '/products/$productId/reviews',
            query: {'page': page, 'size': 10},
          ),
        ),
        Review.fromJson,
      );

  Future<void> addReview(String productId, int rating, String? text) async {
    await _api.post(
      '/products/$productId/reviews',
      body: {
        'rating': rating,
        if (text != null && text.isNotEmpty) 'text': text,
      },
    );
  }

  Future<List<ProductSummary>> favorites() async =>
      _arr(await _api.get('/favorites'))
          .map((e) => ProductSummary.fromJson(_map(e)))
          .toList();

  Future<void> setFavorite(String productId, bool on) async {
    if (on) {
      await _api.put('/favorites/$productId');
    } else {
      await _api.delete('/favorites/$productId');
    }
  }
}

// --------------------------------------------------------------------------------------------
// Cart (device-local persistence) and server-side quote
// --------------------------------------------------------------------------------------------

class CartStore {
  CartStore(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'feya.cart.v1';

  List<CartLine> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      return _arr(jsonDecode(raw))
          .map((e) => CartLine.fromJson(_map(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<CartLine> lines) =>
      _prefs.setString(_key, jsonEncode(lines.map((e) => e.toJson()).toList()));
}

class SlotChoice {
  const SlotChoice({
    required this.templateId,
    required this.date,
    required this.start,
    required this.end,
    this.surcharge = 0,
  });
  final String templateId;
  final String date;
  final String start;
  final String end;
  final double surcharge;
  Map<String, dynamic> toJson() => {'templateId': templateId, 'date': date};
}

class QuoteRequest {
  const QuoteRequest({
    required this.lines,
    this.promoCode,
    this.zoneId,
    this.slot,
    this.asap = false,
    this.giftWrap = false,
  });
  final List<CartLine> lines;
  final String? promoCode;
  final String? zoneId;
  final SlotChoice? slot;
  final bool asap;
  final bool giftWrap;

  Map<String, dynamic> toJson() => {
    'items': [
      for (final l in lines) {'variantId': l.variantId, 'quantity': l.quantity},
    ],
    if (promoCode != null && promoCode!.trim().isNotEmpty)
      'promoCode': promoCode!.trim(),
    'zoneId': ?zoneId,
    if (slot != null) 'slot': slot!.toJson(),
    'asap': asap,
    'giftWrap': giftWrap,
  };
}

class QuoteRepository {
  QuoteRepository(this._api);
  final ApiClient _api;

  Future<Quote> quote(QuoteRequest r) async =>
      Quote.fromJson(_map(await _api.post('/cart/quote', body: r.toJson())));
}

// --------------------------------------------------------------------------------------------
// Addresses & delivery
// --------------------------------------------------------------------------------------------

class AddressInput {
  const AddressInput({
    this.label,
    required this.city,
    required this.street,
    required this.building,
    this.apartment,
    this.entrance,
    this.floor,
    this.intercom,
    this.recipientName,
    this.recipientPhone,
    this.instructions,
    this.makeDefault = false,
  });
  final String? label;
  final String city;
  final String street;
  final String building;
  final String? apartment;
  final String? entrance;
  final String? floor;
  final String? intercom;
  final String? recipientName;
  final String? recipientPhone;
  final String? instructions;
  final bool makeDefault;

  Map<String, dynamic> toJson() => {
    'label': label,
    'city': city,
    'street': street,
    'building': building,
    'apartment': apartment,
    'entrance': entrance,
    'floor': floor,
    'intercom': intercom,
    'recipientName': recipientName,
    'recipientPhone': recipientPhone,
    'instructions': instructions,
    'makeDefault': makeDefault,
  };
}

class AddressRepository {
  AddressRepository(this._api);
  final ApiClient _api;

  Future<List<SavedAddress>> list() async =>
      _arr(await _api.get('/addresses'))
          .map((e) => SavedAddress.fromJson(_map(e)))
          .toList();
  Future<SavedAddress> create(AddressInput a) async => SavedAddress.fromJson(
    _map(await _api.post('/addresses', body: a.toJson())),
  );
  Future<SavedAddress> update(String id, AddressInput a) async =>
      SavedAddress.fromJson(
        _map(await _api.put('/addresses/$id', body: a.toJson())),
      );
  Future<void> setDefault(String id) async {
    await _api.put('/addresses/$id/default');
  }

  Future<void> delete(String id) async {
    await _api.delete('/addresses/$id');
  }
}

class DeliveryRepository {
  DeliveryRepository(this._api);
  final ApiClient _api;

  Future<DeliveryZone> resolve(String city) async => DeliveryZone.fromJson(
    _map(
      await _api.get(
        '/delivery/zones/resolve',
        query: {'city': city},
        auth: false,
      ),
    ),
  );

  Future<SlotsResponse> slots(String zoneId, {int days = 7}) async =>
      SlotsResponse.fromJson(
        _map(
          await _api.get(
            '/delivery/slots',
            query: {'zoneId': zoneId, 'days': days},
            auth: false,
          ),
        ),
      );
}

// --------------------------------------------------------------------------------------------
// Orders, payments, tracking, notifications
// --------------------------------------------------------------------------------------------

class CreateOrderInput {
  const CreateOrderInput({
    required this.lines,
    this.promoCode,
    this.addressId,
    this.address,
    required this.recipientName,
    required this.recipientPhone,
    this.slot,
    this.asap = false,
    this.giftMessage,
    this.anonymousSender = false,
    this.giftWrap = false,
    this.instructions,
    this.saveAddress = false,
  });
  final List<CartLine> lines;
  final String? promoCode;
  final String? addressId;
  final AddressInput? address;
  final String recipientName;
  final String recipientPhone;
  final SlotChoice? slot;
  final bool asap;
  final String? giftMessage;
  final bool anonymousSender;
  final bool giftWrap;
  final String? instructions;
  final bool saveAddress;

  Map<String, dynamic> toJson() => {
    'items': [
      for (final l in lines) {'variantId': l.variantId, 'quantity': l.quantity},
    ],
    if (promoCode != null && promoCode!.trim().isNotEmpty)
      'promoCode': promoCode!.trim(),
    'addressId': ?addressId,
    if (address != null)
      'address': {
        'city': address!.city,
        'street': address!.street,
        'building': address!.building,
        'apartment': address!.apartment,
        'entrance': address!.entrance,
        'floor': address!.floor,
        'intercom': address!.intercom,
        'saveAddress': saveAddress,
      },
    'recipient': {'name': recipientName, 'phone': recipientPhone},
    if (slot != null) 'slot': slot!.toJson(),
    'asap': asap,
    if (giftMessage != null && giftMessage!.trim().isNotEmpty)
      'giftMessage': giftMessage!.trim(),
    'anonymousSender': anonymousSender,
    'giftWrap': giftWrap,
    if (instructions != null && instructions!.trim().isNotEmpty)
      'instructions': instructions!.trim(),
    'acceptTerms': true,
  };
}

class OrderRepository {
  OrderRepository(this._api);
  final ApiClient _api;

  Future<OrderDetail> create(
    CreateOrderInput input,
    String idempotencyKey,
  ) async => OrderDetail.fromJson(
    _map(
      await _api.post(
        '/orders',
        body: input.toJson(),
        headers: {'Idempotency-Key': idempotencyKey},
      ),
    ),
  );

  Future<PageData<OrderSummary>> list({int page = 0}) async =>
      PageData.fromJson(
        _map(await _api.get('/orders', query: {'page': page, 'size': 20})),
        OrderSummary.fromJson,
      );

  Future<OrderDetail> get(String id) async =>
      OrderDetail.fromJson(_map(await _api.get('/orders/$id')));

  Future<OrderDetail> cancel(String id, {String? reason}) async =>
      OrderDetail.fromJson(
        _map(await _api.post('/orders/$id/cancel', body: {'reason': ?reason})),
      );

  Future<Tracking> tracking(String id) async =>
      Tracking.fromJson(_map(await _api.get('/orders/$id/tracking')));

  /// Live updates: tries server-sent events first and transparently falls back to polling every [poll].
  Stream<Tracking> watchTracking(
    String id, {
    Duration poll = const Duration(seconds: 10),
  }) async* {
    var sseWorking = false;
    try {
      await for (final json in _api.events('/orders/$id/tracking/stream')) {
        sseWorking = true;
        yield Tracking.fromJson(json);
      }
    } catch (_) {
      // fall through to polling
    }
    if (sseWorking) {
      // the stream ended normally (server timeout): pick up with polling instead of silently stalling
    }
    while (true) {
      try {
        yield await tracking(id);
      } on ApiException catch (e) {
        if (e.status == 404 || e.status == 401) rethrow;
      }
      await Future<void>.delayed(poll);
    }
  }
}

class PaymentRepository {
  PaymentRepository(this._api);
  final ApiClient _api;

  Future<PaymentMethods> methods() async => PaymentMethods.fromJson(
    _map(await _api.get('/payments/methods', auth: false)),
  );

  Future<PaymentInfo> start(String orderId, String method) async =>
      PaymentInfo.fromJson(
        _map(
          await _api.post(
            '/orders/$orderId/payments',
            body: {'method': method},
          ),
        ),
      );

  Future<PaymentInfo> get(String paymentId) async =>
      PaymentInfo.fromJson(_map(await _api.get('/payments/$paymentId')));

  /// Sandbox only: asks the (simulated) gateway to complete the payment. The order becomes paid only after the
  /// backend has processed the resulting signed webhook.
  Future<PaymentInfo> sandboxComplete(
    String paymentId, {
    required bool success,
  }) async => PaymentInfo.fromJson(
    _map(
      await _api.post(
        '/payments/sandbox/$paymentId/complete',
        body: {'outcome': success ? 'SUCCESS' : 'FAILURE'},
      ),
    ),
  );
}

class NotificationRepository {
  NotificationRepository(this._api);
  final ApiClient _api;

  Future<PageData<AppNotification>> list({int page = 0}) async =>
      PageData.fromJson(
        _map(
          await _api.get('/notifications', query: {'page': page, 'size': 30}),
        ),
        AppNotification.fromJson,
      );

  Future<int> unreadCount() async =>
      (_map(await _api.get('/notifications/unread-count'))['count'] as num)
          .toInt();

  Future<void> markRead(String id) async {
    await _api.post('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.post('/notifications/read-all');
  }
}
