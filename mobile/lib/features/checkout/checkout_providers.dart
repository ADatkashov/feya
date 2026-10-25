import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/models.dart';

final addressesProvider = FutureProvider.autoDispose<List<SavedAddress>>((ref) {
  return ref.watch(addressRepositoryProvider).list();
});

/// Delivery slots actually offered by the backend for a zone (nothing is invented client-side).
final slotsProvider = FutureProvider.autoDispose.family<SlotsResponse, String>((
  ref,
  zoneId,
) {
  return ref.watch(deliveryRepositoryProvider).slots(zoneId);
});

final paymentMethodsProvider = FutureProvider.autoDispose<PaymentMethods>((
  ref,
) {
  return ref.watch(paymentRepositoryProvider).methods();
});

final zoneForCityProvider = FutureProvider.autoDispose
    .family<DeliveryZone, String>((ref, city) {
      return ref.watch(deliveryRepositoryProvider).resolve(city);
    });
