// lib/core/authStorage.dart
import 'dart:convert';
import 'package:company/models/company.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _storage = FlutterSecureStorage();
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kCompanyId = 'company_id';
  static const _kCompany = 'company_json';

  // tokens
  static Future<void> saveAccessToken(String v) => _storage.write(key: _kAccess, value: v);
  static Future<void> saveRefreshToken(String v) => _storage.write(key: _kRefresh, value: v);
  static Future<String?> getAccessToken() => _storage.read(key: _kAccess);
  static Future<String?> getRefreshToken() => _storage.read(key: _kRefresh);
  static Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kCompanyId);
    await _storage.delete(key: _kCompany);
  }

  // company
  static Future<void> saveCompanyId(String id) => _storage.write(key: _kCompanyId, value: id);
  static Future<String?> getCompanyId() => _storage.read(key: _kCompanyId);

  static Future<void> saveCompanyJson(Map<String, dynamic> company) =>
      _storage.write(key: _kCompany, value: jsonEncode(company));
  static Future<Company?> getCompanyJson() async {
    final raw = await _storage.read(key: _kCompany);
    if (raw == null) return null;
    return companyFromJson(raw);
  }
}
