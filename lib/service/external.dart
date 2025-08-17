import 'package:company/models/company.dart';
import 'package:company/core/di.dart';

Future<({Company company, int status, String accessToken, String refreshToken})> signup(Map<String, dynamic> data) async {
  final res = await http.postRaw(path: '/company', body: data);

  final Map<String, dynamic> root = Map<String, dynamic>.from(res.data as Map);
  final company = Company.fromJson(
    Map<String, dynamic>.from(root['company'] ?? root),
  );

  final access = root['accessToken'] as String;
  final refreshToken = root['refreshToken'] as String;
  return (company: company, status: res.statusCode ?? 0, accessToken: access, refreshToken: refreshToken);
}

Future<({Company company, int status, String accessToken, String refreshToken})> login(Map<String, dynamic> data) async {
  final res = await http.postRaw(path: '/company/login', body: data);

  final Map<String, dynamic> root = Map<String, dynamic>.from(res.data as Map);
  final company = Company.fromJson(
    Map<String, dynamic>.from(root['company'] ?? root),
  );

  final access = root['accessToken'] as String;
  final refreshToken = root['refreshToken'] as String;

  return (company: company, status: res.statusCode ?? 0, accessToken: access, refreshToken: refreshToken);
}