import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';

const int kMaxQuantityPerLine = 20;

/// The on-device cart. Persisted on every change; prices shown here are snapshots, the server quote is authoritative.
class CartController extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => ref.read(cartStoreProvider).load();

  void _commit(List<CartLine> lines) {
    state = lines;
    ref.read(cartStoreProvider).save(lines);
  }

  /// Adds [quantity] of a variant, merging with an existing line and honouring the quantity cap.
  void add({
    required String productId,
    required String productName,
    required Variant variant,
    required String? imageUrl,
    int quantity = 1,
  }) {
    final lines = [...state];
    final i = lines.indexWhere((l) => l.variantId == variant.id);
    final limit = variant.maxQuantity > 0
        ? variant.maxQuantity.clamp(1, kMaxQuantityPerLine)
        : kMaxQuantityPerLine;
    if (i >= 0) {
      lines[i] = lines[i].withQuantity(
        (lines[i].quantity + quantity).clamp(1, limit),
      );
    } else {
      lines.add(
        CartLine(
          variantId: variant.id,
          productId: productId,
          productName: productName,
          variantLabel: variant.label,
          imageUrl: imageUrl,
          unitPrice: variant.price,
          quantity: quantity.clamp(1, limit),
        ),
      );
    }
    _commit(lines);
  }

  void setQuantity(String variantId, int quantity) {
    if (quantity <= 0) {
      remove(variantId);
      return;
    }
    _commit([
      for (final l in state)
        if (l.variantId == variantId)
          l.withQuantity(quantity.clamp(1, kMaxQuantityPerLine))
        else
          l,
    ]);
  }

  void remove(String variantId) =>
      _commit(state.where((l) => l.variantId != variantId).toList());

  void clear() => _commit(const []);

  int get itemCount => state.fold(0, (sum, l) => sum + l.quantity);
}

final cartProvider = NotifierProvider<CartController, List<CartLine>>(
  CartController.new,
);

final cartCountProvider = Provider<int>(
  (ref) => ref.watch(cartProvider).fold(0, (s, l) => s + l.quantity),
);

/// Everything the customer has chosen on the way to checkout. Lives for the whole checkout session.
class CheckoutState {
  const CheckoutState({
    this.promoCode,
    this.addressId,
    this.address,
    this.saveAddress = false,
    this.zoneId,
    this.recipientName = '',
    this.recipientPhone = '',
    this.slot,
    this.asap = false,
    this.giftMessage = '',
    this.anonymousSender = false,
    this.giftWrap = false,
    this.instructions = '',
    this.acceptTerms = false,
  });

  final String? promoCode;
  final String? addressId;
  final AddressInput? address;
  final bool saveAddress;
  final String? zoneId;
  final String recipientName;
  final String recipientPhone;
  final SlotChoice? slot;
  final bool asap;
  final String giftMessage;
  final bool anonymousSender;
  final bool giftWrap;
  final String instructions;
  final bool acceptTerms;

  bool get hasAddress => addressId != null || address != null;
  bool get hasDeliveryTime => asap || slot != null;

  CheckoutState copyWith({
    Object? promoCode = _keep,
    Object? addressId = _keep,
    Object? address = _keep,
    bool? saveAddress,
    Object? zoneId = _keep,
    String? recipientName,
    String? recipientPhone,
    Object? slot = _keep,
    bool? asap,
    String? giftMessage,
    bool? anonymousSender,
    bool? giftWrap,
    String? instructions,
    bool? acceptTerms,
  }) => CheckoutState(
    promoCode: identical(promoCode, _keep)
        ? this.promoCode
        : promoCode as String?,
    addressId: identical(addressId, _keep)
        ? this.addressId
        : addressId as String?,
    address: identical(address, _keep)
        ? this.address
        : address as AddressInput?,
    saveAddress: saveAddress ?? this.saveAddress,
    zoneId: identical(zoneId, _keep) ? this.zoneId : zoneId as String?,
    recipientName: recipientName ?? this.recipientName,
    recipientPhone: recipientPhone ?? this.recipientPhone,
    slot: identical(slot, _keep) ? this.slot : slot as SlotChoice?,
    asap: asap ?? this.asap,
    giftMessage: giftMessage ?? this.giftMessage,
    anonymousSender: anonymousSender ?? this.anonymousSender,
    giftWrap: giftWrap ?? this.giftWrap,
    instructions: instructions ?? this.instructions,
    acceptTerms: acceptTerms ?? this.acceptTerms,
  );
}

const Object _keep = Object();

class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutState();

  void update(CheckoutState Function(CheckoutState) f) => state = f(state);
  void reset() => state = const CheckoutState();

  void setPromo(String? code) => state = state.copyWith(
    promoCode: (code == null || code.trim().isEmpty) ? null : code.trim(),
  );

  /// Choosing another address may move the order to a different zone, which invalidates the slot choice.
  void setAddress({
    String? addressId,
    AddressInput? address,
    required String? zoneId,
  }) {
    final zoneChanged = zoneId != state.zoneId;
    state = state.copyWith(
      addressId: addressId,
      address: address,
      zoneId: zoneId,
      slot: zoneChanged ? null : state.slot,
      asap: zoneChanged ? false : state.asap,
    );
  }

  void chooseAsap() => state = state.copyWith(asap: true, slot: null);
  void chooseSlot(SlotChoice slot) =>
      state = state.copyWith(asap: false, slot: slot);
}

final checkoutProvider = NotifierProvider<CheckoutController, CheckoutState>(
  CheckoutController.new,
);

/// Authoritative quote for the current cart and checkout choices. Re-evaluated whenever either changes.
final quoteProvider = FutureProvider.autoDispose<Quote?>((ref) async {
  final lines = ref.watch(cartProvider);
  final c = ref.watch(checkoutProvider);
  if (lines.isEmpty) return null;
  return ref
      .watch(quoteRepositoryProvider)
      .quote(
        QuoteRequest(
          lines: lines,
          promoCode: c.promoCode,
          zoneId: c.zoneId,
          slot: c.slot,
          asap: c.asap,
          giftWrap: c.giftWrap,
        ),
      );
});
