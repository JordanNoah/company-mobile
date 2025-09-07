import 'dart:async';
import 'dart:convert' show base64Decode, jsonDecode;
import 'dart:io' show Directory;
import 'package:company/models/session_info.dart';
import 'package:company/utils/trait.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  late final String _refreshPath; // p.ej. '/auth/refresh'
  late final String _refreshBasePath; // p.ej. '/auth'
  late final Dio _dio;

  // Estado de sesión
  String? _token;
  String? get accessToken => _token;

  // Cache de sesión en memoria
  SessionInfo? _sessionCache;

  int? lastStatusCode;
  Map<String, List<String>>? lastHeaders;

  // Control de refresh concurrente
  Future<String?>? _refreshing;

  // Cookies
  PersistCookieJar? _jar;

  // Init guard
  bool _initialized = false;

  // Almacenamiento seguro del access token (solo móvil/desktop)
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Http() {
    baseUrl = dotenv.get('API_BASE_URL', fallback: 'http://10.0.2.2:3000');
    // Permite configurar el path por .env si tu backend usa prefijos
    _refreshPath = dotenv.get('REFRESH_PATH', fallback: '/auth/refresh');
    // Base para el Path de la cookie (todo lo que empieza por aquí enviará la cookie)
    _refreshBasePath = dotenv.get('REFRESH_BASE_PATH', fallback: '/auth');

    print('BASE_URL => $baseUrl');
    print('REFRESH_PATH => $_refreshPath');
    print('REFRESH_BASE_PATH => $_refreshBasePath');

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Interceptor: Authorization + auto-refresh 401
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
          final isRefreshCall = e.requestOptions.path.endsWith(_refreshPath);
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
              // cae al next
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

  // ======== Init / ensureInit ========

  Future<void> init() async {
    if (_initialized) return;

    // Montar CookieJar persistente
    final dir = await getApplicationSupportDirectory();
    _jar = PersistCookieJar(storage: FileStorage('${dir.path}/.cookies'));
    _dio.interceptors.add(CookieManager(_jar!));

    // Rehidratar access token persistido (si existe)
    if (!kIsWeb) {
      final saved = await _storage.read(key: 'access_token');
      if (saved != null && saved.isNotEmpty) {
        _token = saved;
      }
    }

    _initialized = true;
  }

  Future<void> _ensureInit() async {
    if (!_initialized) {
      await init();
    }
  }

  // ======== Token helpers ========

  void setAuthToken(String token) {
    _token = token;
    if (!kIsWeb) {
      _storage.write(key: 'access_token', value: token);
    }
  }

  void clearAuthToken() {
    _token = null;
    if (!kIsWeb) {
      _storage.delete(key: 'access_token');
    }
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

  // ======== Sesión ========

  /// Llama al arranque de la app para levantar sesión desde cookie `rt`.
  Future<bool> bootstrapSession() async {
    await _ensureInit();

    // 1) Si ya tengo un token válido, úsalo y no llames al backend
    if (_isJwtValid(_token)) {
      return true;
    }

    // 2) Intenta refrescar con cookie `rt` (si existe en el CookieJar)
    final access = await _refreshAccessTokenOnce();
    return access != null && access.isNotEmpty;
  }

  /// Devuelve la sesión actual (cacheada). Hace refresh si hace falta.
  Future<SessionInfo?> getSessionInfo() async {
    await _ensureInit();

    // Si ya hay cache, úsala
    if (_sessionCache != null) return _sessionCache;

    // Asegura access token válido (usa cookie rt si hace falta)
    if (!_isJwtValid(_token)) {
      final ok = await bootstrapSession();
      if (!ok) return null;
    }

    // Llama a tu endpoint de sesión/perfil
    // Ajusta la ruta y el "unwrap" según tu API
    try {
      // A) Si tu API responde { data: { ... } }
      final (info, code) = await getJsonWithCode<SessionInfo>(
        path: '/auth/me', // <--- AJUSTA si tu endpoint es otro
        fromJson: (m) => SessionInfo.fromJson(m),
        unwrap: 'data',
      );
      if (code == 200) {
        _sessionCache = info;
        return info;
      }
    } catch (_) {
      // B) Si tu API responde plano: { ... }
      try {
        final (info, code) = await getJsonWithCode<SessionInfo>(
          path: '/auth/me',
          fromJson: (m) => SessionInfo.fromJson(m),
          unwrap: null, // sin 'data'
        );
        if (code == 200) {
          _sessionCache = info;
          return info;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Acceso directo al companyId (contextId) desde la sesión
  Future<String?> getCompanyId() async {
    // 1) quick path desde el token (si viene en el JWT)
    final fromToken = contextIdFromToken;
    if (fromToken != null && fromToken.isNotEmpty) return fromToken;

    // 2) si no está en el token, consulta /auth/me y cachea
    final s = await getSessionInfo();
    return s?.companyId;
  }

  /// Intenta refrescar el access token (usa cookie HttpOnly `rt`).
  Future<String?> tryRefreshAccessToken() async {
    await _ensureInit();
    try {
      final res = await _dio.post(
        _refreshPath,
        options: Options(extra: {'skipAuth': true, 'noRetry': true}),
      );
      final access = (res.data is Map)
          ? res.data['accessToken'] as String?
          : null;
      if (access != null) setAuthToken(access);
      return access;
    } catch (_) {
      return null;
    }
  }

  /// Logout server + limpia token y cookies locales.
  Future<void> logout() async {
    await _ensureInit();
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
    clearAuthToken();
    _sessionCache = null; // <-- limpia cache de sesión
    await _clearCookies();
  }

  // ======== Requests ========

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

  // ======== Internos ========

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
    await _ensureInit(); // 👈 garantiza CookieJar y token rehidratado

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

  Map<String, dynamic>? get sessionPayload => decodeJwt(_token);

  String? get contextIdFromToken {
    final payload = sessionPayload;
    return payload?['companyId']?.toString();
  }

  // ======== Refresh ========

  Future<String?> _refreshAccessTokenOnce() async {
    _refreshing ??= _refreshAccessToken();
    try {
      return await _refreshing;
    } finally {
      _refreshing = null;
    }
  }

  Future<String?> _refreshAccessToken() async {
    await _ensureInit();
    try {
      final res = await _dio.post(
        _refreshPath,
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

  // ======== Cookies & Debug ========

  Future<void> _clearCookies() async {
    if (kIsWeb) return; // no se puede borrar HttpOnly en web
    try {
      final dir = await getApplicationSupportDirectory();
      final cookiesDir = Directory('${dir.path}/.cookies');
      if (cookiesDir.existsSync()) {
        cookiesDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  }

  /// Diagnóstico: imprime si hay access token y si es válido
  Future<void> printSessionStatus() async {
    await _ensureInit();
    final hasAccess = _token != null && _token!.isNotEmpty;
    final valid = _isJwtValid(_token);
    // No imprimimos el token por seguridad
    // ignore: avoid_print
    print(
      'Access token: ${hasAccess ? (valid ? "presente y válido" : "presente pero vencido") : "no presente"}',
    );
  }

  /// Diagnóstico: lista cookies aplicables al endpoint de refresh y verifica 'rt'
  Future<void> debugRtCookieForRefresh() async {
    await _ensureInit();
    final jar =
        (_dio.interceptors.whereType<CookieManager>().first).cookieJar
            as PersistCookieJar;

    final origin = Uri.parse(baseUrl);
    final refreshUri = origin.replace(path: _refreshPath);

    final cookies = await jar.loadForRequest(refreshUri);
    // ignore: avoid_print
    print('Cookies para ${refreshUri.path} => $cookies');
    // ignore: avoid_print
    print('BASE_URL => $baseUrl');

    final hasRt = cookies.any((c) => c.name == 'rt');
    // ignore: avoid_print
    print(hasRt ? '✅ Hay cookie rt' : '❌ No hay cookie rt');
  }

  /// Normaliza cookies 'rt' cuyo path no coincida con la base esperada.
  /// Usa REFRESH_BASE_PATH (default '/auth') para decidir qué mantener.
  Future<void> normalizeRtCookiePath() async {
    await _ensureInit();
    final jar =
        (_dio.interceptors.whereType<CookieManager>().first).cookieJar
            as PersistCookieJar;

    final origin = Uri.parse(baseUrl);
    final cookies = await jar.loadForRequest(
      origin.replace(path: _refreshPath),
    );
    // ignore: avoid_print
    print('Cookies al iniciar: $cookies');
    // ignore: avoid_print
    print('BASE_URL => $origin');

    final bad = cookies
        .where(
          (c) =>
              c.name == 'rt' && !(c.path == _refreshBasePath || c.path == '/'),
        )
        .toList();

    if (bad.isNotEmpty) {
      // Borrado sencillo: elimina todo el directorio de cookies y deja que el back re-setee
      final dir = await getApplicationSupportDirectory();
      Directory('${dir.path}/.cookies').deleteSync(recursive: true);
      // ignore: avoid_print
      print(
        '🧹 CookieJar reseteado por path inconsistente de rt (esperado: $_refreshBasePath o "/").',
      );
    }
  }
}
