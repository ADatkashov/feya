import '../../core/config/app_config.dart';

double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
double? _dn(dynamic v) => v == null ? null : (v as num).toDouble();
List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    (v as List? ?? const []).map((e) => f(e as Map<String, dynamic>)).toList();

class PageData<T> {
  const PageData({
    required this.items,
    required this.page,
    required this.hasNext,
    required this.total,
  });
  final List<T> items;
  final int page;
  final bool hasNext;
  final int total;

  factory PageData.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) f,
  ) => PageData(
    items: _list(j['content'], f),
    page: j['page'] as int? ?? 0,
    hasNext: j['hasNext'] as bool? ?? false,
    total: (j['totalElements'] as num?)?.toInt() ?? 0,
  );
}

// --------------------------------------------------------------------------------------------
// Catalog
// --------------------------------------------------------------------------------------------

class Category {
  const Category({required this.id, required this.slug, required this.name});
  final String id;
  final String slug;
  final String name;
  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['id'] as String,
    slug: j['slug'] as String,
    name: j['name'] as String,
  );
}

class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.imageUrl,
    required this.priceFrom,
    required this.currency,
    required this.ratingAvg,
    required this.ratingCount,
    required this.available,
    required this.favorite,
    required this.category,
  });
  final String id;
  final String slug;
  final String name;
  final String? imageUrl;
  final double priceFrom;
  final String currency;
  final double? ratingAvg;
  final int ratingCount;
  final bool available;
  final bool favorite;
  final String category;

  ProductSummary copyWith({bool? favorite}) => ProductSummary(
    id: id,
    slug: slug,
    name: name,
    imageUrl: imageUrl,
    priceFrom: priceFrom,
    currency: currency,
    ratingAvg: ratingAvg,
    ratingCount: ratingCount,
    available: available,
    favorite: favorite ?? this.favorite,
    category: category,
  );

  factory ProductSummary.fromJson(Map<String, dynamic> j) => ProductSummary(
    id: j['id'] as String,
    slug: j['slug'] as String,
    name: j['name'] as String,
    imageUrl: AppConfig.resolveMedia(j['imageUrl'] as String?),
    priceFrom: _d(j['priceFrom']),
    currency: j['currency'] as String? ?? 'KZT',
    ratingAvg: _dn(j['ratingAvg']),
    ratingCount: (j['ratingCount'] as num?)?.toInt() ?? 0,
    available: j['available'] as bool? ?? false,
    favorite: j['favorite'] as bool? ?? false,
    category: j['category'] as String? ?? '',
  );
}

class Variant {
  const Variant({
    required this.id,
    required this.code,
    required this.label,
    required this.price,
    required this.stemsCount,
    required this.available,
    required this.maxQuantity,
  });
  final String id;
  final String code;
  final String label;
  final double price;
  final int? stemsCount;
  final bool available;
  final int maxQuantity;
  factory Variant.fromJson(Map<String, dynamic> j) => Variant(
    id: j['id'] as String,
    code: j['code'] as String,
    label: j['label'] as String,
    price: _d(j['price']),
    stemsCount: (j['stemsCount'] as num?)?.toInt(),
    available: j['available'] as bool? ?? false,
    maxQuantity: (j['maxQuantity'] as num?)?.toInt() ?? 0,
  );
}

class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.composition,
    required this.category,
    required this.categorySlug,
    required this.images,
    required this.variants,
    required this.priceFrom,
    required this.currency,
    required this.ratingAvg,
    required this.ratingCount,
    required this.available,
    required this.favorite,
    required this.prepMinutes,
  });
  final String id;
  final String slug;
  final String name;
  final String description;
  final String composition;
  final String category;
  final String categorySlug;
  final List<String> images;
  final List<Variant> variants;
  final double priceFrom;
  final String currency;
  final double? ratingAvg;
  final int ratingCount;
  final bool available;
  final bool favorite;
  final int prepMinutes;

  factory ProductDetail.fromJson(Map<String, dynamic> j) => ProductDetail(
    id: j['id'] as String,
    slug: j['slug'] as String,
    name: j['name'] as String,
    description: j['description'] as String? ?? '',
    composition: j['composition'] as String? ?? '',
    category: j['category'] as String? ?? '',
    categorySlug: j['categorySlug'] as String? ?? '',
    images:
        ((j['images'] as List? ?? const [])
                .map(
                  (e) => AppConfig.resolveMedia((e as Map)['url'] as String?),
                )
                .whereType<String>())
            .toList(),
    variants: _list(j['variants'], Variant.fromJson),
    priceFrom: _d(j['priceFrom']),
    currency: j['currency'] as String? ?? 'KZT',
    ratingAvg: _dn(j['ratingAvg']),
    ratingCount: (j['ratingCount'] as num?)?.toInt() ?? 0,
    available: j['available'] as bool? ?? false,
    favorite: j['favorite'] as bool? ?? false,
    prepMinutes: (j['prepMinutes'] as num?)?.toInt() ?? 90,
  );
}

class BannerItem {
  const BannerItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.promoCode,
    required this.targetType,
    required this.targetValue,
  });
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? promoCode;
  final String? targetType;
  final String? targetValue;
  factory BannerItem.fromJson(Map<String, dynamic> j) => BannerItem(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    subtitle: j['subtitle'] as String? ?? '',
    imageUrl: AppConfig.resolveMedia(j['imageUrl'] as String?),
    promoCode: j['promoCode'] as String?,
    targetType: j['targetType'] as String?,
    targetValue: j['targetValue'] as String?,
  );
}

class HomeData {
  const HomeData({
    required this.banners,
    required this.categories,
    required this.featured,
    required this.popular,
    required this.newArrivals,
    required this.seasonal,
  });
  final List<BannerItem> banners;
  final List<Category> categories;
  final List<ProductSummary> featured;
  final List<ProductSummary> popular;
  final List<ProductSummary> newArrivals;
  final List<ProductSummary> seasonal;
  factory HomeData.fromJson(Map<String, dynamic> j) => HomeData(
    banners: _list(j['banners'], BannerItem.fromJson),
    categories: _list(j['categories'], Category.fromJson),
    featured: _list(j['featured'], ProductSummary.fromJson),
    popular: _list(j['popular'], ProductSummary.fromJson),
    newArrivals: _list(j['newArrivals'], ProductSummary.fromJson),
    seasonal: _list(j['seasonal'], ProductSummary.fromJson),
  );
}

class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.text,
    required this.author,
    required this.verified,
    required this.createdAt,
  });
  final String id;
  final int rating;
  final String? text;
  final String author;
  final bool verified;
  final DateTime createdAt;
  factory Review.fromJson(Map<String, dynamic> j) => Review(
    id: j['id'] as String,
    rating: (j['rating'] as num).toInt(),
    text: j['text'] as String?,
    author: j['author'] as String? ?? '',
    verified: j['verified'] as bool? ?? false,
    createdAt: DateTime.parse(j['createdAt'] as String).toUtc(),
  );
}

// --------------------------------------------------------------------------------------------
// Cart & quote
// --------------------------------------------------------------------------------------------

/// A line in the on-device cart. The price here is only a display snapshot; the server quote is authoritative.
class CartLine {
  const CartLine({
    required this.variantId,
    required this.productId,
    required this.productName,
    required this.variantLabel,
    required this.imageUrl,
    required this.unitPrice,
    required this.quantity,
  });
  final String variantId;
  final String productId;
  final String productName;
  final String variantLabel;
  final String? imageUrl;
  final double unitPrice;
  final int quantity;

  CartLine withQuantity(int q) => CartLine(
    variantId: variantId,
    productId: productId,
    productName: productName,
    variantLabel: variantLabel,
    imageUrl: imageUrl,
    unitPrice: unitPrice,
    quantity: q,
  );

  Map<String, dynamic> toJson() => {
    'variantId': variantId,
    'productId': productId,
    'productName': productName,
    'variantLabel': variantLabel,
    'imageUrl': imageUrl,
    'unitPrice': unitPrice,
    'quantity': quantity,
  };

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
    variantId: j['variantId'] as String,
    productId: j['productId'] as String,
    productName: j['productName'] as String,
    variantLabel: j['variantLabel'] as String,
    imageUrl: j['imageUrl'] as String?,
    unitPrice: _d(j['unitPrice']),
    quantity: (j['quantity'] as num).toInt(),
  );
}

class QuoteLine {
  const QuoteLine({
    required this.variantId,
    required this.productId,
    required this.productName,
    required this.variantLabel,
    required this.imageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.available,
    required this.maxQuantity,
    required this.issue,
  });
  final String variantId;
  final String productId;
  final String productName;
  final String variantLabel;
  final String? imageUrl;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
  final bool available;
  final int maxQuantity;
  final String? issue;
  factory QuoteLine.fromJson(Map<String, dynamic> j) => QuoteLine(
    variantId: j['variantId'] as String,
    productId: j['productId'] as String,
    productName: j['productName'] as String,
    variantLabel: j['variantLabel'] as String,
    imageUrl: AppConfig.resolveMedia(j['imageUrl'] as String?),
    unitPrice: _d(j['unitPrice']),
    quantity: (j['quantity'] as num).toInt(),
    lineTotal: _d(j['lineTotal']),
    available: j['available'] as bool? ?? false,
    maxQuantity: (j['maxQuantity'] as num?)?.toInt() ?? 0,
    issue: j['issue'] as String?,
  );
}

class PromoInfo {
  const PromoInfo({
    required this.code,
    required this.applied,
    required this.discount,
    required this.error,
  });
  final String code;
  final bool applied;
  final double discount;
  final String? error;
  factory PromoInfo.fromJson(Map<String, dynamic> j) => PromoInfo(
    code: j['code'] as String,
    applied: j['applied'] as bool? ?? false,
    discount: _d(j['discount']),
    error: j['error'] as String?,
  );
}

class Quote {
  const Quote({
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.promo,
    required this.deliveryFee,
    required this.giftWrapFee,
    required this.total,
    required this.currency,
    required this.zoneId,
    required this.valid,
    required this.issues,
  });
  final List<QuoteLine> lines;
  final double subtotal;
  final double discount;
  final PromoInfo? promo;
  final double deliveryFee;
  final double giftWrapFee;
  final double total;
  final String currency;
  final String zoneId;
  final bool valid;
  final List<String> issues;
  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
    lines: _list(j['lines'], QuoteLine.fromJson),
    subtotal: _d(j['subtotal']),
    discount: _d(j['discount']),
    promo: j['promo'] == null
        ? null
        : PromoInfo.fromJson(j['promo'] as Map<String, dynamic>),
    deliveryFee: _d(j['deliveryFee']),
    giftWrapFee: _d(j['giftWrapFee']),
    total: _d(j['total']),
    currency: j['currency'] as String? ?? 'KZT',
    zoneId: j['zoneId'] as String? ?? '',
    valid: j['valid'] as bool? ?? false,
    issues: (j['issues'] as List? ?? const []).cast<String>(),
  );
}

// --------------------------------------------------------------------------------------------
// Delivery & addresses
// --------------------------------------------------------------------------------------------

class DeliveryZone {
  const DeliveryZone({
    required this.id,
    required this.code,
    required this.name,
    required this.baseFee,
    required this.freeDeliveryThreshold,
    required this.asapEnabled,
    required this.asapFee,
    required this.asapEtaMinutes,
  });
  final String id;
  final String code;
  final String name;
  final double baseFee;
  final double? freeDeliveryThreshold;
  final bool asapEnabled;
  final double asapFee;
  final int asapEtaMinutes;
  factory DeliveryZone.fromJson(Map<String, dynamic> j) => DeliveryZone(
    id: j['id'] as String,
    code: j['code'] as String,
    name: j['name'] as String? ?? '',
    baseFee: _d(j['baseFee']),
    freeDeliveryThreshold: _dn(j['freeDeliveryThreshold']),
    asapEnabled: j['asapEnabled'] as bool? ?? false,
    asapFee: _d(j['asapFee']),
    asapEtaMinutes: (j['asapEtaMinutes'] as num?)?.toInt() ?? 90,
  );
}

class Slot {
  const Slot({
    required this.templateId,
    required this.date,
    required this.start,
    required this.end,
    required this.available,
    required this.remaining,
    required this.surcharge,
    required this.reason,
  });
  final String templateId;
  final String date; // yyyy-MM-dd
  final String start; // HH:mm
  final String end;
  final bool available;
  final int remaining;
  final double surcharge;
  final String? reason;
  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
    templateId: j['templateId'] as String,
    date: j['date'] as String,
    start: (j['start'] as String).substring(0, 5),
    end: (j['end'] as String).substring(0, 5),
    available: j['available'] as bool? ?? false,
    remaining: (j['remaining'] as num?)?.toInt() ?? 0,
    surcharge: _d(j['surcharge']),
    reason: j['unavailableReason'] as String?,
  );
}

class SlotsResponse {
  const SlotsResponse({
    required this.zoneId,
    required this.asapAvailable,
    required this.asapFee,
    required this.asapEtaMinutes,
    required this.days,
  });
  final String zoneId;
  final bool asapAvailable;
  final double asapFee;
  final int asapEtaMinutes;
  final Map<String, List<Slot>> days; // ordered by date
  factory SlotsResponse.fromJson(Map<String, dynamic> j) {
    final days = <String, List<Slot>>{};
    for (final d in (j['days'] as List? ?? const [])) {
      final m = d as Map<String, dynamic>;
      days[m['date'] as String] = _list(m['slots'], Slot.fromJson);
    }
    return SlotsResponse(
      zoneId: j['zoneId'] as String,
      asapAvailable: j['asapAvailable'] as bool? ?? false,
      asapFee: _d(j['asapFee']),
      asapEtaMinutes: (j['asapEtaMinutes'] as num?)?.toInt() ?? 90,
      days: days,
    );
  }
}

class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.city,
    required this.street,
    required this.building,
    required this.apartment,
    required this.entrance,
    required this.floor,
    required this.intercom,
    required this.recipientName,
    required this.recipientPhone,
    required this.instructions,
    required this.isDefault,
    required this.deliverable,
  });
  final String id;
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
  final bool isDefault;
  final bool deliverable;

  String get oneLine {
    final parts = <String>['$street $building'];
    if ((apartment ?? '').isNotEmpty) parts.add('кв. $apartment');
    return parts.join(', ');
  }

  factory SavedAddress.fromJson(Map<String, dynamic> j) => SavedAddress(
    id: j['id'] as String,
    label: j['label'] as String?,
    city: j['city'] as String,
    street: j['street'] as String,
    building: j['building'] as String,
    apartment: j['apartment'] as String?,
    entrance: j['entrance'] as String?,
    floor: j['floor'] as String?,
    intercom: j['intercom'] as String?,
    recipientName: j['recipientName'] as String?,
    recipientPhone: j['recipientPhone'] as String?,
    instructions: j['instructions'] as String?,
    isDefault: j['isDefault'] as bool? ?? false,
    deliverable: j['deliverable'] as bool? ?? true,
  );
}

// --------------------------------------------------------------------------------------------
// Orders, payments, tracking
// --------------------------------------------------------------------------------------------

class OrderItemData {
  const OrderItemData({
    required this.productId,
    required this.name,
    required this.variantLabel,
    required this.imageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
  });
  final String productId;
  final String name;
  final String variantLabel;
  final String? imageUrl;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
  factory OrderItemData.fromJson(Map<String, dynamic> j) => OrderItemData(
    productId: j['productId'] as String,
    name: j['name'] as String,
    variantLabel: j['variantLabel'] as String,
    imageUrl: AppConfig.resolveMedia(j['imageUrl'] as String?),
    unitPrice: _d(j['unitPrice']),
    quantity: (j['quantity'] as num).toInt(),
    lineTotal: _d(j['lineTotal']),
  );
}

class TimelineEntry {
  const TimelineEntry({required this.status, required this.at});
  final String status;
  final DateTime at;
  factory TimelineEntry.fromJson(Map<String, dynamic> j) => TimelineEntry(
    status: j['status'] as String,
    at: DateTime.parse(j['at'] as String).toUtc(),
  );
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.number,
    required this.status,
    required this.total,
    required this.itemCount,
    required this.firstItemName,
    required this.firstItemImage,
    required this.deliveryDate,
    required this.slotStart,
    required this.slotEnd,
    required this.asap,
    required this.createdAt,
  });
  final String id;
  final String number;
  final String status;
  final double total;
  final int itemCount;
  final String? firstItemName;
  final String? firstItemImage;
  final String? deliveryDate;
  final String? slotStart;
  final String? slotEnd;
  final bool asap;
  final DateTime createdAt;
  factory OrderSummary.fromJson(Map<String, dynamic> j) => OrderSummary(
    id: j['id'] as String,
    number: j['number'] as String,
    status: j['status'] as String,
    total: _d(j['total']),
    itemCount: (j['itemCount'] as num?)?.toInt() ?? 0,
    firstItemName: j['firstItemName'] as String?,
    firstItemImage: AppConfig.resolveMedia(j['firstItemImage'] as String?),
    deliveryDate: j['deliveryDate'] as String?,
    slotStart: j['slotStart'] == null ? null : shortT(j['slotStart'] as String),
    slotEnd: j['slotEnd'] == null ? null : shortT(j['slotEnd'] as String),
    asap: j['asap'] as bool? ?? false,
    createdAt: DateTime.parse(j['createdAt'] as String).toUtc(),
  );
}

String shortT(String s) => s.length >= 5 ? s.substring(0, 5) : s;

class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.number,
    required this.status,
    required this.paymentStatus,
    required this.currency,
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    required this.giftWrapFee,
    required this.total,
    required this.promoCode,
    required this.asap,
    required this.deliveryDate,
    required this.slotStart,
    required this.slotEnd,
    required this.eta,
    required this.addressLine,
    required this.recipientName,
    required this.recipientPhone,
    required this.giftMessage,
    required this.items,
    required this.timeline,
    required this.canCancel,
    required this.canPay,
    required this.createdAt,
  });
  final String id;
  final String number;
  final String status;
  final String paymentStatus;
  final String currency;
  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double giftWrapFee;
  final double total;
  final String? promoCode;
  final bool asap;
  final String? deliveryDate;
  final String? slotStart;
  final String? slotEnd;
  final DateTime? eta;
  final String addressLine;
  final String recipientName;
  final String recipientPhone;
  final String? giftMessage;
  final List<OrderItemData> items;
  final List<TimelineEntry> timeline;
  final bool canCancel;
  final bool canPay;
  final DateTime createdAt;

  factory OrderDetail.fromJson(Map<String, dynamic> j) {
    final a = j['address'] as Map<String, dynamic>;
    final parts = <String>[
      '${a['city']}',
      '${a['street']} ${a['building']}',
      if ((a['apartment'] ?? '').toString().isNotEmpty) 'кв. ${a['apartment']}',
    ];
    return OrderDetail(
      id: j['id'] as String,
      number: j['number'] as String,
      status: j['status'] as String,
      paymentStatus: j['paymentStatus'] as String? ?? 'UNPAID',
      currency: j['currency'] as String? ?? 'KZT',
      subtotal: _d(j['subtotal']),
      discount: _d(j['discount']),
      deliveryFee: _d(j['deliveryFee']),
      giftWrapFee: _d(j['giftWrapFee']),
      total: _d(j['total']),
      promoCode: j['promoCode'] as String?,
      asap: j['asap'] as bool? ?? false,
      deliveryDate: j['deliveryDate'] as String?,
      slotStart: j['slotStart'] == null
          ? null
          : shortT(j['slotStart'] as String),
      slotEnd: j['slotEnd'] == null ? null : shortT(j['slotEnd'] as String),
      eta: j['eta'] == null ? null : DateTime.parse(j['eta'] as String).toUtc(),
      addressLine: parts.join(', '),
      recipientName: j['recipientName'] as String? ?? '',
      recipientPhone: j['recipientPhone'] as String? ?? '',
      giftMessage: j['giftMessage'] as String?,
      items: _list(j['items'], OrderItemData.fromJson),
      timeline: _list(j['timeline'], TimelineEntry.fromJson),
      canCancel: j['canCancel'] as bool? ?? false,
      canPay: j['canPay'] as bool? ?? false,
      createdAt: DateTime.parse(j['createdAt'] as String).toUtc(),
    );
  }
}

class PaymentInfo {
  const PaymentInfo({
    required this.id,
    required this.orderId,
    required this.status,
    required this.amount,
    required this.sandbox,
    required this.checkoutUrl,
    required this.failureReason,
  });
  final String id;
  final String orderId;
  final String status; // PENDING | SUCCEEDED | FAILED | REFUNDED ...
  final double amount;
  final bool sandbox;
  final String? checkoutUrl;
  final String? failureReason;
  factory PaymentInfo.fromJson(Map<String, dynamic> j) => PaymentInfo(
    id: j['id'] as String,
    orderId: j['orderId'] as String,
    status: j['status'] as String,
    amount: _d(j['amount']),
    sandbox: j['sandbox'] as bool? ?? false,
    checkoutUrl: j['checkoutUrl'] as String?,
    failureReason: j['failureReason'] as String?,
  );
}

class PaymentMethods {
  const PaymentMethods({
    required this.configured,
    required this.sandbox,
    required this.methods,
  });
  final bool configured;
  final bool sandbox;
  final List<String> methods;
  factory PaymentMethods.fromJson(Map<String, dynamic> j) => PaymentMethods(
    configured: j['configured'] as bool? ?? false,
    sandbox: j['sandbox'] as bool? ?? false,
    methods: (j['methods'] as List? ?? const []).cast<String>(),
  );
}

class CourierInfo {
  const CourierInfo({
    required this.name,
    required this.phone,
    required this.vehicle,
  });
  final String name;
  final String phone;
  final String? vehicle;
  factory CourierInfo.fromJson(Map<String, dynamic> j) => CourierInfo(
    name: j['name'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    vehicle: j['vehicle'] as String?,
  );
}

class CourierLocation {
  const CourierLocation({
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
  factory CourierLocation.fromJson(Map<String, dynamic> j) => CourierLocation(
    latitude: _d(j['latitude']),
    longitude: _d(j['longitude']),
    updatedAt: DateTime.parse(j['updatedAt'] as String).toUtc(),
  );
}

class Tracking {
  const Tracking({
    required this.orderId,
    required this.number,
    required this.status,
    required this.paymentStatus,
    required this.eta,
    required this.timeline,
    required this.courier,
    required this.location,
    required this.liveTracking,
  });
  final String orderId;
  final String number;
  final String status;
  final String paymentStatus;
  final DateTime? eta;
  final List<TimelineEntry> timeline;
  final CourierInfo? courier;
  final CourierLocation? location;
  final bool liveTracking;
  factory Tracking.fromJson(Map<String, dynamic> j) => Tracking(
    orderId: j['orderId'] as String,
    number: j['number'] as String,
    status: j['status'] as String,
    paymentStatus: j['paymentStatus'] as String? ?? 'UNPAID',
    eta: j['eta'] == null ? null : DateTime.parse(j['eta'] as String).toUtc(),
    timeline: _list(j['timeline'], TimelineEntry.fromJson),
    courier: j['courier'] == null
        ? null
        : CourierInfo.fromJson(j['courier'] as Map<String, dynamic>),
    location: j['courierLocation'] == null
        ? null
        : CourierLocation.fromJson(
            j['courierLocation'] as Map<String, dynamic>,
          ),
    liveTracking: j['liveTracking'] as bool? ?? false,
  );
}

// --------------------------------------------------------------------------------------------
// Account
// --------------------------------------------------------------------------------------------

class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    required this.name,
    required this.email,
    required this.language,
    required this.roles,
    required this.notifyPush,
    required this.notifyOrderUpdates,
    required this.notifyPromotions,
  });
  final String id;
  final String phone;
  final String? name;
  final String? email;
  final String language;
  final List<String> roles;
  final bool notifyPush;
  final bool notifyOrderUpdates;
  final bool notifyPromotions;

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id: j['id'] as String,
    phone: j['phone'] as String,
    name: j['name'] as String?,
    email: j['email'] as String?,
    language: j['language'] as String? ?? 'ru',
    roles: (j['roles'] as List? ?? const []).cast<String>(),
    notifyPush: j['notifyPush'] as bool? ?? true,
    notifyOrderUpdates: j['notifyOrderUpdates'] as bool? ?? true,
    notifyPromotions: j['notifyPromotions'] as bool? ?? false,
  );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.read,
    required this.createdAt,
  });
  final String id;
  final String type;
  final String title;
  final String body;
  final String? data;
  final bool read;
  final DateTime createdAt;
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    type: j['type'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    data: j['data'] as String?,
    read: j['read'] as bool? ?? false,
    createdAt: DateTime.parse(j['createdAt'] as String).toUtc(),
  );
}
