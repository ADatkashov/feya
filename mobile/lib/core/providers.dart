import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/repositories.dart';
import 'network/api_client.dart';
import 'storage/token_store.dart';

// Infrastructure -----------------------------------------------------------------------------

/// Must be overridden in `main()` (and in tests) with the real instance.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider'),
);

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

const supportedLocales = [Locale('ru'), Locale('kk'), Locale('en')];

class LocaleController extends Notifier<Locale> {
  static const _key = 'feya.locale';

  @override
  Locale build() {
    final saved = ref.read(sharedPrefsProvider).getString(_key);
    return supportedLocales.firstWhere(
      (l) => l.languageCode == saved,
      orElse: () => const Locale('ru'),
    );
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref.read(sharedPrefsProvider).setString(_key, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokens: ref.watch(tokenStoreProvider),
    language: () => ref.read(localeProvider).languageCode,
  );
});

// Repositories -------------------------------------------------------------------------------

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);
final catalogRepositoryProvider = Provider(
  (ref) => CatalogRepository(ref.watch(apiClientProvider)),
);
final quoteRepositoryProvider = Provider(
  (ref) => QuoteRepository(ref.watch(apiClientProvider)),
);
final addressRepositoryProvider = Provider(
  (ref) => AddressRepository(ref.watch(apiClientProvider)),
);
final deliveryRepositoryProvider = Provider(
  (ref) => DeliveryRepository(ref.watch(apiClientProvider)),
);
final orderRepositoryProvider = Provider(
  (ref) => OrderRepository(ref.watch(apiClientProvider)),
);
final paymentRepositoryProvider = Provider(
  (ref) => PaymentRepository(ref.watch(apiClientProvider)),
);
final notificationRepositoryProvider = Provider(
  (ref) => NotificationRepository(ref.watch(apiClientProvider)),
);
final cartStoreProvider = Provider(
  (ref) => CartStore(ref.watch(sharedPrefsProvider)),
);
