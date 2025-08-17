import 'package:company/utils/rules.dart';
import 'package:flutter/material.dart';

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final List<Rule> rules;
  final int? errorMaxLines;                 // ← opcional
  final AutovalidateMode autovalidateMode;  // ← opcional

  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Contraseña',
    this.rules = const [],
    this.errorMaxLines,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;
  void _toggle() => setState(() => _obscure = !_obscure);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      autovalidateMode: widget.autovalidateMode,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: _toggle,
        ),
        // permite varias líneas de error
        errorMaxLines: widget.errorMaxLines ?? widget.rules.length.clamp(1, 10),
      ),
      validator: (v) {
        final errors = <String>[];
        for (final rule in widget.rules) {
          final res = rule(v);
          if (res != null && res.isNotEmpty) {
            errors.add('• $res'); // bullets bonitas
          }
        }
        return errors.isEmpty ? null : errors.join('\n');
      },
    );
  }
}
