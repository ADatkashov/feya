import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/models.dart';
import '../auth/auth_controller.dart';

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) {
  if (!ref.watch(authProvider.select((a) => a.isAuthenticated))) return 0;
  return ref.watch(notificationRepositoryProvider).unreadCount();
});

final notificationsProvider =
    FutureProvider.autoDispose<PageData<AppNotification>>((ref) {
      return ref.watch(notificationRepositoryProvider).list();
    });
