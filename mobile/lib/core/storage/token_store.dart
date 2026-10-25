import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the session tokens. Backed by the platform keystore/keychain (never plain SharedPreferences).
abstract class TokenStore {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> save({required String access, required String refresh});
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _s = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;

  @override
  Future<String?> readAccess() => _s.read(key: 'feya.access');
  @override
  Future<String?> readRefresh() => _s.read(key: 'feya.refresh');
  @override
  Future<void> save({required String access, required String refresh}) async {
    await _s.write(key: 'feya.access', value: access);
    await _s.write(key: 'feya.refresh', value: refresh);
  }

  @override
  Future<void> clear() async {
    await _s.delete(key: 'feya.access');
    await _s.delete(key: 'feya.refresh');
  }
}

/// In-memory implementation for tests.
class MemoryTokenStore implements TokenStore {
  String? _a;
  String? _r;
  @override
  Future<String?> readAccess() async => _a;
  @override
  Future<String?> readRefresh() async => _r;
  @override
  Future<void> save({required String access, required String refresh}) async {
    _a = access;
    _r = refresh;
  }

  @override
  Future<void> clear() async {
    _a = null;
    _r = null;
  }
}
