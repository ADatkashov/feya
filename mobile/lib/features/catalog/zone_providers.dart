import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/models.dart';

/// Active delivery zones; also what the delivery-location selector lists.
final deliveryZonesProvider = FutureProvider.autoDispose<List<DeliveryZone>>((
  ref,
) async {
  ref.watch(localeProvider);
  final api = ref.watch(apiClientProvider);
  final raw = await api.get('/delivery/zones', auth: false) as List<dynamic>;
  return raw
      .map((e) => DeliveryZone.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// The zone the customer browses for. Null means "the default zone of the market" (decided by the backend).
class SelectedZone extends Notifier<String?> {
  static const _key = 'feya.zone';

  @override
  String? build() => ref.read(sharedPrefsProvider).getString(_key);

  Future<void> select(String? zoneId) async {
    state = zoneId;
    final prefs = ref.read(sharedPrefsProvider);
    if (zoneId == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, zoneId);
    }
  }
}

final selectedZoneIdProvider = NotifierProvider<SelectedZone, String?>(
  SelectedZone.new,
);
