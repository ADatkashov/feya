import 'package:flutter/foundation.dart';

/// Build-time configuration. Override with `--dart-define=KEY=value`; nothing secret belongs here.
class AppConfig {
  AppConfig._();

  /// Backend origin without the `/api/v1` suffix.
  static const String _apiBase = String.fromEnvironment('API_BASE_URL');

  /// Demo backend used by release builds when `API_BASE_URL` is not given, so a plainly built APK works on a phone.
  static const String demoApiBase = 'https://feya-backend-sea8.onrender.com';

  static String get apiBaseUrl {
    if (_apiBase.isNotEmpty) return _apiBase.replaceAll(RegExp(r'/+$'), '');
    if (kReleaseMode) return demoApiBase;
    if (kIsWeb) return 'http://localhost:8080';
    if (defaultTargetPlatform == TargetPlatform.android)
      return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }

  static String get apiUrl => '$apiBaseUrl/api/v1';

  /// Template for opening a coordinate in a maps app. `{lat}` and `{lng}` are substituted.
  /// Default: 2GIS (widely used in Kazakhstan). Any provider's URL scheme can be configured.
  static const String mapLinkTemplate = String.fromEnvironment(
    'MAP_LINK_TEMPLATE',
    defaultValue: 'https://2gis.kz/almaty/geo/{lng},{lat}',
  );

  static const String supportPhone = String.fromEnvironment(
    'SUPPORT_PHONE',
    defaultValue: '+77000000004',
  );
  static const String supportWhatsapp = String.fromEnvironment(
    'SUPPORT_WHATSAPP',
  );
  static const String privacyUrl = String.fromEnvironment('PRIVACY_URL');
  static const String termsUrl = String.fromEnvironment('TERMS_URL');

  /// Resolves image paths returned by the API (relative `/media/...` or absolute URLs).
  static String? resolveMedia(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$apiBaseUrl${url.startsWith('/') ? '' : '/'}$url';
  }
}
