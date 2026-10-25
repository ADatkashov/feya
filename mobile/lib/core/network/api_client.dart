import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';

typedef LanguageGetter = String Function();

/// Thin typed wrapper around Dio: bearer auth, single-flight token refresh, language header, GET retry.
class ApiClient {
  ApiClient({
    required this._tokens,
    required this._language,
    Dio? dio,
    Dio? refreshDio,
    this.onSessionExpired,
    String? baseUrl,
  }) : _dio = dio ?? Dio(),
       _refreshDio = refreshDio ?? Dio() {
    final url = baseUrl ?? AppConfig.apiUrl;
    _dio.options
      ..baseUrl = url
      ..connectTimeout = const Duration(seconds: 12)
      ..receiveTimeout = const Duration(seconds: 25)
      ..headers = {'Accept': 'application/json'};
    _refreshDio.options
      ..baseUrl = url
      ..connectTimeout = const Duration(seconds: 12)
      ..receiveTimeout = const Duration(seconds: 25);
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  final Dio _dio;
  final Dio _refreshDio;
  final TokenStore _tokens;
  final LanguageGetter _language;
  void Function()? onSessionExpired;

  Future<String?>? _refreshing;

  Future<void> _onRequest(RequestOptions o, RequestInterceptorHandler h) async {
    o.headers['Accept-Language'] = _language();
    if (o.extra['auth'] != false) {
      final token = await _tokens.readAccess();
      if (token != null) o.headers['Authorization'] = 'Bearer $token';
    }
    h.next(o);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler h) async {
    final o = e.requestOptions;
    // 1) one retry-with-refresh on expired access tokens
    if (e.response?.statusCode == 401 &&
        o.extra['auth'] != false &&
        o.extra['retried'] != true &&
        o.headers.containsKey('Authorization')) {
      final fresh = await _refreshAccessToken();
      if (fresh != null) {
        o.extra['retried'] = true;
        o.headers['Authorization'] = 'Bearer $fresh';
        try {
          return h.resolve(await _dio.fetch<dynamic>(o));
        } on DioException catch (e2) {
          return h.next(e2);
        }
      }
    }
    // 2) transient network failures on idempotent GETs: two quick retries
    final transient =
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout;
    final attempts = (o.extra['attempts'] as int?) ?? 0;
    if (transient && o.method == 'GET' && attempts < 2) {
      o.extra['attempts'] = attempts + 1;
      await Future<void>.delayed(Duration(milliseconds: 400 * (attempts + 1)));
      try {
        return h.resolve(await _dio.fetch<dynamic>(o));
      } on DioException catch (e2) {
        return h.next(e2);
      }
    }
    h.next(e);
  }

  /// Concurrent 401s share one refresh call.
  Future<String?> _refreshAccessToken() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh() async {
    final refresh = await _tokens.readRefresh();
    if (refresh == null) {
      onSessionExpired?.call();
      return null;
    }
    try {
      final res = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final d = res.data!;
      await _tokens.save(
        access: d['accessToken'] as String,
        refresh: d['refreshToken'] as String,
      );
      return d['accessToken'] as String;
    } on DioException catch (e) {
      // A definitive rejection ends the session; a network blip keeps the tokens for the next try.
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await _tokens.clear();
        onSessionExpired?.call();
      }
      return null;
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    try {
      final res = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          extra: {'auth': auth},
          headers: headers,
        ),
      );
      return res.data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) => _send('GET', path, query: query, auth: auth);
  Future<dynamic> post(
    String path, {
    Object? body,
    bool auth = true,
    Map<String, String>? headers,
  }) => _send('POST', path, body: body, auth: auth, headers: headers);
  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);
  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);
  Future<dynamic> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  /// Server-sent events. Emits decoded JSON payloads; ends (or errors) when the connection drops, so callers
  /// must fall back to polling. Not available on Flutter web, where it throws immediately.
  Stream<Map<String, dynamic>> events(
    String path, {
    CancelToken? cancel,
  }) async* {
    final token = await _tokens.readAccess();
    try {
      final res = await _dio.get<ResponseBody>(
        path,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 35),
          headers: {
            'Accept': 'text/event-stream',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      final lines = res.data!.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      final data = StringBuffer();
      await for (final line in lines) {
        if (line.startsWith('data:')) {
          data.write(line.substring(5).trimLeft());
        } else if (line.isEmpty && data.isNotEmpty) {
          final decoded = jsonDecode(data.toString());
          data.clear();
          if (decoded is Map<String, dynamic>) yield decoded;
        }
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
