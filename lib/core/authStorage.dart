import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _k = FlutterSecureStorage();
  
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  // Guardar tokens
  static Future<void> saveAccessToken(String token) =>
      _k.write(key: _accessKey, value: token);

  static Future<void> saveRefreshToken(String token) =>
      _k.write(key: _refreshKey, value: token);

  // Leer tokens
  static Future<String?> getAccessToken() =>
      _k.read(key: _accessKey);

  static Future<String?> getRefreshToken() =>
      _k.read(key: _refreshKey);

  // Borrar tokens
  static Future<void> clear() async {
    await _k.delete(key: _accessKey);
    await _k.delete(key: _refreshKey);
  }

  static Future<void> saveToken(String token) => saveAccessToken(token);
}
