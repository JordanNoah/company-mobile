import 'package:company/models/company.dart';
import 'package:company/core/di.dart';
import 'package:company/models/image.dart';
import 'package:company/models/image_context.dart';
import 'package:company/models/image_typeof.dart';
import 'package:company/service/http.dart';

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

Future<String?> fetchImageUrlByPost({required ImageContext contextType, required String contextId, required ImageTypeof type}) async {
  try {
    final res = await http.postRaw(
      path: '/image', // 👈 ajusta al path real en tu API
      body: {
        'context': contextType.value,
        'contextId': int.tryParse(contextId) ?? contextId,
        'typeOf': type.value
      },
    );

    // Tu controlador devuelve la entidad de imagen (no envuelve en {data: ...})
    if (res.statusCode == 200 && res.data is Map) {
      final item = Image.fromJson(Map<String, dynamic>.from(res.data));
      return item.url.isNotEmpty ? item.url : null;
    }

    // 404 => sin imagen
    if (res.statusCode == 404) return null;

    return null;
  } on ApiException catch (e) {
    // 404 (Image not found) —> null
    if (e.statusCode == 404) return null;
    rethrow;
  }
}