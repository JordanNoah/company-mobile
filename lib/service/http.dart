import 'dart:async';
import 'dart:convert' show base64Decode, jsonDecode;
import 'dart:io' show Directory;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';

typedef FromJson<T> = T Function(Map<String, dynamic> json);

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic data;
  ApiException({this.statusCode, required this.message, this.data});
  @override
  String toString() => 'ApiException($statusCode, $message)';
}

class Http {
  late final String baseUrl;
  late final Dio _dio;
  String? _token;
  String? get accessToken => _token;

  int? lastStatusCode;
  Map<String, List<String>>? lastHeaders;

  // ==== NEW: control de refresh concurrente ====
  Future<String?>? _refreshing;
  PersistCookieJar? _jar;

  Http() {
    baseUrl = dotenv.get('API_BASE_URL', fallback: 'http://10.0.2.2:3000');
    print('BASE_URL => ${baseUrl}');
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // === Interceptor: Authorization + auto-refresh 401 ===
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opts, handler) {
          final skipAuth = opts.extra['skipAuth'] == true;
          if (!skipAuth && _token?.isNotEmpty == true) {
            opts.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(opts);
        },
        onError: (e, handler) async {
          final status = e.response?.statusCode ?? 0;
          final alreadyRetried = e.requestOptions.extra['__retried__'] == true;
          final isRefreshCall = e.requestOptions.path.endsWith('/auth/refresh');
          final noRetry = e.requestOptions.extra['noRetry'] == true;

          if (status == 401 && !alreadyRetried && !isRefreshCall && !noRetry) {
            try {
              final newAccess = await _refreshAccessTokenOnce();
              if (newAccess != null && newAccess.isNotEmpty) {
                final req = e.requestOptions;
                req.headers['Authorization'] = 'Bearer $newAccess';
                req.extra['__retried__'] = true;
                final clone = await _dio.fetch(req);
                return handler.resolve(clone);
              }
            } catch (_) {
              // sigue al next
            }
          }
          handler.next(e);
        },
      ),
    );

    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );
  }

  void setAuthToken(String token) => _token = token;
  void clearAuthToken() => _token = null;

  // ========= PUBLIC HELPERS (opcional) =========
  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _jar = PersistCookieJar(storage: FileStorage('${dir.path}/.cookies'));
    _dio.interceptors.add(CookieManager(_jar!)); // << activa cookies para TODO
  }

  bool _isJwtValid(String? token, {int skewSeconds = 30}) {
    if (token == null || token.isEmpty) return false;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      String norm(String s) => s
          .padRight(s.length + (4 - s.length % 4) % 4, '=')
          .replaceAll('-', '+')
          .replaceAll('_', '/');
      final payload = String.fromCharCodes(base64Decode(norm(parts[1])));
      final map = Map<String, dynamic>.from(jsonDecode(payload));
      final exp = map['exp'];
      if (exp is! num) return false;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return (exp.toInt() - skewSeconds) > now;
    } catch (_) {
      return false;
    }
  }

  /// Llama en el arranque de la app para levantar sesión desde cookie `rt`.
  Future<bool> bootstrapSession() async {
    // 1) Si ya tengo un token válido, úsalo y no llames al backend
    if (_isJwtValid(_token)) {
      return true;
    }

    // 2) Intenta refrescar con cookie `rt` (si existe en el CookieJar)
    final access = await _refreshAccessTokenOnce();
    return access != null && access.isNotEmpty;
  }

  /// Intenta refrescar el access token (usa cookie HttpOnly `rt`).
  Future<String?> tryRefreshAccessToken() async {
    try {
      final res = await _dio.post(
        '/auth/refresh',
        options: Options(extra: {'skipAuth': true, 'noRetry': true}),
      );
      final access = (res.data is Map)
          ? res.data['accessToken'] as String?
          : null;
      if (access != null) {
        setAuthToken(access);
      }
      return access;
    } catch (_) {
      return null;
    }
  }

  /// Logout server + limpia token y cookies locales.
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
    clearAuthToken();
    await _clearCookies();
  }

  // ========= REQUESTS =========

  Future<T> getJson<T>({
    required String path,
    required FromJson<T> fromJson,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? unwrap = 'data',
  }) {
    return _request<T>(
      method: 'GET',
      path: path,
      query: query,
      headers: headers,
      fromJson: fromJson,
      unwrap: unwrap,
    );
  }

  Future<List<T>> getList<T>({
    required String path,
    required T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? unwrap = 'data',
  }) async {
    final res = await _rawRequest(
      method: 'GET',
      path: path,
      query: query,
      headers: headers,
    );

    final root = res.data;
    dynamic payload = root;
    if (unwrap != null &&
        root is Map<String, dynamic> &&
        root[unwrap] != null) {
      payload = root[unwrap];
    }

    if (payload is List) {
      return payload
          .whereType<Map<String, dynamic>>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw ApiException(
      statusCode: res.statusCode,
      message: 'Respuesta de lista inválida',
      data: root,
    );
  }

  Future<T> postJson<T>({
    required String path,
    required Map<String, dynamic> body,
    required FromJson<T> fromJson,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? unwrap = 'data',
  }) {
    return _request<T>(
      method: 'POST',
      path: path,
      body: body,
      query: query,
      headers: headers,
      fromJson: fromJson,
      unwrap: unwrap,
    );
  }

  Future<T> putJson<T>({
    required String path,
    required Map<String, dynamic> body,
    required FromJson<T> fromJson,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? unwrap = 'data',
  }) {
    return _request<T>(
      method: 'PUT',
      path: path,
      body: body,
      query: query,
      headers: headers,
      fromJson: fromJson,
      unwrap: unwrap,
    );
  }

  Future<T> patchJson<T>({
    required String path,
    required Map<String, dynamic> body,
    required FromJson<T> fromJson,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? unwrap = 'data',
  }) {
    return _request<T>(
      method: 'PATCH',
      path: path,
      body: body,
      query: query,
      headers: headers,
      fromJson: fromJson,
      unwrap: unwrap,
    );
  }

  Future<void> delete({
    required String path,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    await _rawRequest(
      method: 'DELETE',
      path: path,
      query: query,
      headers: headers,
    );
  }

  Future<(T, int)> getJsonWithCode<T>({
    required String path,
    required FromJson<T> fromJson,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? unwrap = 'data',
  }) async {
    final res = await _rawRequest(
      method: 'GET',
      path: path,
      query: query,
      headers: headers,
    );
    return (_parse<T>(res.data, fromJson, unwrap), res.statusCode ?? 0);
  }

  Future<(T, int)> postJsonWithCode<T>({
    required String path,
    required Map<String, dynamic> body,
    required FromJson<T> fromJson,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? unwrap = 'data',
  }) async {
    final res = await _rawRequest(
      method: 'POST',
      path: path,
      body: body,
      query: query,
      headers: headers,
    );
    return (_parse<T>(res.data, fromJson, unwrap), res.statusCode ?? 0);
  }

  Future<Response<dynamic>> postRaw({
    required String path,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) {
    return _rawRequest(
      method: 'POST',
      path: path,
      body: body,
      query: query,
      headers: headers,
    );
  }

  Future<(T, int)> putJsonWithCode<T>({
    required String path,
    required Map<String, dynamic> body,
    required FromJson<T> fromJson,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? unwrap = 'data',
  }) async {
    final res = await _rawRequest(
      method: 'PUT',
      path: path,
      body: body,
      query: query,
      headers: headers,
    );
    return (_parse<T>(res.data, fromJson, unwrap), res.statusCode ?? 0);
  }

  Future<(T, int)> patchJsonWithCode<T>({
    required String path,
    required Map<String, dynamic> body,
    required FromJson<T> fromJson,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? unwrap = 'data',
  }) async {
    final res = await _rawRequest(
      method: 'PATCH',
      path: path,
      body: body,
      query: query,
      headers: headers,
    );
    return (_parse<T>(res.data, fromJson, unwrap), res.statusCode ?? 0);
  }

  Future<int> deleteWithCode({
    required String path,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final res = await _rawRequest(
      method: 'DELETE',
      path: path,
      query: query,
      headers: headers,
    );
    return res.statusCode ?? 0;
  }

  // ========= Internos =========

  Future<T> _request<T>({
    required String method,
    required String path,
    required FromJson<T> fromJson,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? unwrap = 'data',
  }) async {
    final res = await _rawRequest(
      method: method,
      path: path,
      body: body,
      query: query,
      headers: headers,
    );
    return _parse<T>(res.data, fromJson, unwrap);
  }

  T _parse<T>(dynamic root, FromJson<T> fromJson, String? unwrap) {
    if (root is Map<String, dynamic>) {
      final payload = (unwrap != null && root[unwrap] is Map<String, dynamic>)
          ? Map<String, dynamic>.from(root[unwrap] as Map)
          : Map<String, dynamic>.from(root);
      return fromJson(payload);
    }
    throw ApiException(
      message: 'Respuesta inesperada del servidor',
      data: root,
    );
  }

  Future<Response<dynamic>> _rawRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.request(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: headers),
      );
      lastStatusCode = response.statusCode;
      lastHeaders = response.headers.map;
      return response;
    } on DioException catch (e) {
      lastStatusCode = e.response?.statusCode;
      lastHeaders = e.response?.headers.map;
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    String msg;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        msg = 'Tiempo de conexión agotado';
        break;
      case DioExceptionType.receiveTimeout:
        msg = 'Tiempo de respuesta agotado';
        break;
      case DioExceptionType.sendTimeout:
        msg = 'Tiempo de envío agotado';
        break;
      case DioExceptionType.cancel:
        msg = 'Solicitud cancelada';
        break;
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final data = e.response?.data;
        msg = (data is Map && data['message'] is String)
            ? data['message'] as String
            : 'Error HTTP $status';
        break;
      default:
        msg = 'Error de red';
    }
    return ApiException(
      statusCode: e.response?.statusCode,
      message: msg,
      data: e.response?.data,
    );
  }

  Dio get client => _dio;

  Future<String?> _refreshAccessTokenOnce() async {
    _refreshing ??= _refreshAccessToken();
    try {
      return await _refreshing;
    } finally {
      _refreshing = null;
    }
  }

  Future<String?> _refreshAccessToken() async {
    try {
      final res = await _dio.post(
        '/auth/refresh',
        options: Options(extra: {'skipAuth': true, 'noRetry': true}),
      );
      final access = (res.data is Map)
          ? res.data['accessToken'] as String?
          : null;
      if (access != null) setAuthToken(access);
      return access;
    } catch (e) {
      clearAuthToken();
      await _clearCookies();
      rethrow;
    }
  }

  Future<void> _clearCookies() async {
    if (kIsWeb) return; // en web no podemos borrar cookies HttpOnly
    try {
      final dir = await getApplicationSupportDirectory();
      final cookiesDir = Directory('${dir.path}/.cookies');
      if (cookiesDir.existsSync()) {
        cookiesDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> normalizeRtCookiePath() async {
    await this.debugRtCookieForRefresh();
    final jar =
        (client.interceptors.whereType<CookieManager>().first).cookieJar
            as PersistCookieJar;

    final uri = Uri.parse(baseUrl);
    final cookies = await jar.loadForRequest(uri);
    print('Cookies al iniciar: $cookies');
    print('BASE_URL => ${uri}');
    // elimina cualquier 'rt' con path distinto al correcto
    final bad = cookies
        .where((c) => c.name == 'rt' && c.path != '/api/v1/auth')
        .toList();
    if (bad.isNotEmpty) {
      // Borrado simple: elimina todo el directorio de cookies y deja que el back re-setee,
      // o rehidrata tú la correcta si guardas el refresh en secure storage.
      final dir = await getApplicationSupportDirectory();
      Directory('${dir.path}/.cookies').deleteSync(recursive: true);
    }
  }

  Future<void> debugRtCookieForRefresh() async {
    final jar =
        (client.interceptors.whereType<CookieManager>().first).cookieJar
            as PersistCookieJar;

    final origin = Uri.parse(baseUrl);
    // Asegura que preguntas por la URL donde la cookie SÍ aplica:
    final refreshUri = origin.replace(path: '/api/v1/auth/refresh');

    final cookies = await jar.loadForRequest(refreshUri);
    print('Cookies para /auth/refresh => $cookies');
    print('BASE_URL => $baseUrl');
  }
}
