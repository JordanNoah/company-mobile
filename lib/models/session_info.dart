class SessionInfo {
  final String userId;
  final String? companyId; // puede ser null si el usuario no tiene compañía
  final String email;
  final String? name;
  final List<String> roles;

  SessionInfo({
    required this.userId,
    required this.email,
    this.companyId,
    this.name,
    this.roles = const [],
  });

  factory SessionInfo.fromJson(Map<String, dynamic> j) {
    // ajusta las claves a tu payload real
    return SessionInfo(
      userId: (j['userId'] ?? j['id'] ?? j['sub']).toString(),
      email: j['email']?.toString() ?? '',
      companyId: j['companyId']?.toString(),
      name: j['name']?.toString(),
      roles: (j['roles'] is List)
          ? List<String>.from(j['roles'])
          : const [],
    );
  }
}
