import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static final TokenStorage _i = TokenStorage._();
  TokenStorage._();
  factory TokenStorage() => _i;

  final _secure = const FlutterSecureStorage();
  String? _accessInMemory;

  Future<void> saveAccessToken(String token) async {
    _accessInMemory = token;
    // opcional: persiste si lo necesitas
    // await _secure.write(key: 'access', value: token);
  }

  String? get accessToken => _accessInMemory;

  Future<void> clear() async {
    _accessInMemory = null;
    // await _secure.delete(key: 'access');
  }
}
