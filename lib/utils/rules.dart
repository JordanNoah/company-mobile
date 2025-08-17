// lib/utils/rules.dart
typedef Rule = String? Function(String? value);

class Rules {
  static Rule required([String msg = 'Este campo es obligatorio']) {
    return (v) => (v == null || v.trim().isEmpty) ? msg : null;
  }

  static Rule email([String msg = 'Correo inválido']) {
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return (v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return null; // deja que 'required' se encargue
      return re.hasMatch(s) ? null : msg;
    };
  }

  static Rule digitsOnly([String msg = 'Solo dígitos']) {
    final re = RegExp(r'^\d+$');
    return (v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return null;
      return re.hasMatch(s) ? null : msg;
    };
  }

  static Rule minLength(int n, [String? msg]) {
    return (v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return null;
      return s.length < n ? (msg ?? 'Mínimo $n caracteres') : null;
    };
  }

  static Rule maxLength(int n, [String? msg]) {
    return (v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return null;
      return s.length > n ? (msg ?? 'Máximo $n caracteres') : null;
    };
  }

  static Rule lengthIs(int n, [String? msg]) {
    return (v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return null;
      return s.length == n ? null : (msg ?? 'Debe tener $n caracteres');
    };
  }

  static Rule password([String msg = 'Contraseña inválida']) {
    return (v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return null;
      final hasUpper = s.contains(RegExp(r'[A-Z]'));
      final hasLower = s.contains(RegExp(r'[a-z]'));
      final hasNumber = s.contains(RegExp(r'[0-9]'));
      return (hasUpper && hasLower && hasNumber) ? null : msg;
    };
  }

  static Rule lengthIn(Set<int> lengths, [String? msg]) {
    final sorted = (lengths.toList()..sort());
    final def = sorted.length == 1
        ? 'Debe tener ${sorted.first} caracteres'
        : 'Debe tener ${sorted.join(" o ")} caracteres';
    return (v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return null;
      return lengths.contains(s.length) ? null : (msg ?? def);
    };
  }

  // Combinador: válido si CUALQUIERA de las reglas pasa.
  static Rule any(List<Rule> alternatives, [String msg = 'Valor inválido']) {
    return (v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return null;
      for (final r in alternatives) {
        if (r(s) == null) return null;
      }
      return msg;
    };
  }
}
