import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState(this.status, [this.user]);
  final AuthStatus status;
  final UserProfile? user;
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    ref.read(apiClientProvider).onSessionExpired = sessionExpired;
    Future.microtask(_bootstrap);
    return const AuthState(AuthStatus.unknown);
  }

  Future<void> _bootstrap() async {
    final tokens = ref.read(tokenStoreProvider);
    if (await tokens.readRefresh() == null) {
      state = const AuthState(AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await ref.read(authRepositoryProvider).me();
      await _applyUser(user);
    } on ApiException catch (e) {
      if (e.isNetwork) {
        // Offline at launch: stay signed in, details load once the network is back.
        state = const AuthState(AuthStatus.authenticated);
      } else {
        state = const AuthState(AuthStatus.unauthenticated);
      }
    }
  }

  Future<void> _applyUser(UserProfile user) async {
    state = AuthState(AuthStatus.authenticated, user);
    final lang = user.language;
    if (supportedLocales.any((l) => l.languageCode == lang) &&
        ref.read(localeProvider).languageCode != lang) {
      await ref.read(localeProvider.notifier).set(Locale(lang));
    }
  }

  Future<OtpChallenge> requestOtp(String phone) =>
      ref.read(authRepositoryProvider).requestOtp(phone);

  Future<void> verifyOtp(String phone, String code) async {
    final session = await ref
        .read(authRepositoryProvider)
        .verifyOtp(phone, code);
    await ref
        .read(tokenStoreProvider)
        .save(access: session.accessToken, refresh: session.refreshToken);
    await _applyUser(session.user);
  }

  Future<void> logout() async {
    final tokens = ref.read(tokenStoreProvider);
    final refresh = await tokens.readRefresh();
    if (refresh != null) await ref.read(authRepositoryProvider).logout(refresh);
    await tokens.clear();
    state = const AuthState(AuthStatus.unauthenticated);
  }

  void sessionExpired() {
    state = const AuthState(AuthStatus.unauthenticated);
  }

  Future<void> reloadUser() async {
    final user = await ref.read(authRepositoryProvider).me();
    state = AuthState(AuthStatus.authenticated, user);
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? language,
    bool? notifyPush,
    bool? notifyOrderUpdates,
    bool? notifyPromotions,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .updateProfile(
          name: name,
          email: email,
          language: language,
          notifyPush: notifyPush,
          notifyOrderUpdates: notifyOrderUpdates,
          notifyPromotions: notifyPromotions,
        );
    state = AuthState(AuthStatus.authenticated, user);
  }

  Future<void> deleteAccountRequest() async {
    await ref.read(authRepositoryProvider).requestAccountDeletion();
    await ref.read(tokenStoreProvider).clear();
    state = const AuthState(AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
