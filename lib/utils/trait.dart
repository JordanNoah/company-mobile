import 'dart:convert';

Map<String, dynamic>? decodeJwt(String? token) {
  if (token == null || token.isEmpty) return null;
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    String norm(String s) => s
        .padRight(s.length + (4 - s.length % 4) % 4, '=')
        .replaceAll('-', '+')
        .replaceAll('_', '/');
    final payload = String.fromCharCodes(base64Decode(norm(parts[1])));
    return Map<String, dynamic>.from(jsonDecode(payload));
  } catch (_) {
    return null;
  }
}
