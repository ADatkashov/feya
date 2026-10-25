import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/models.dart';
import '../auth/auth_controller.dart';

final ordersProvider = FutureProvider.autoDispose<PageData<OrderSummary>>((
  ref,
) {
  ref.watch(authProvider.select((a) => a.isAuthenticated));
  return ref.watch(orderRepositoryProvider).list();
});

final orderDetailProvider = FutureProvider.autoDispose
    .family<OrderDetail, String>((ref, id) {
      return ref.watch(orderRepositoryProvider).get(id);
    });

/// Live tracking: SSE where available, polling otherwise (see OrderRepository.watchTracking).
final trackingProvider = StreamProvider.autoDispose.family<Tracking, String>((
  ref,
  id,
) {
  return ref.watch(orderRepositoryProvider).watchTracking(id);
});
