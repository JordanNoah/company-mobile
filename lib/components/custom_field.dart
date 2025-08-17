// custom_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:company/models/field_config.dart';

class CustomTextField extends StatelessWidget {
  final FieldConfig config;
  final TextEditingController controller;
  final String? serverError;              // <- error del backend
  final bool alwaysValidate;
  final ValueChanged<String>? onChanged;  // <- para limpiar el error al teclear

  const CustomTextField({
    super.key,
    required this.config,
    required this.controller,
    this.serverError,
    this.alwaysValidate = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: config.keyboard,
      maxLength: config.maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      inputFormatters: config.digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      autovalidateMode: alwaysValidate ? AutovalidateMode.always : AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: config.label,
        hintText: config.hintText,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(config.icon),
        errorMaxLines: config.errorMaxLines ?? (config.rules.length + (serverError == null ? 0 : 1)).clamp(1, 10),
      ),
      validator: (v) {
        final msgs = <String>[];
        for (final r in config.rules) {
          final res = r(v);
          if (res != null && res.isNotEmpty) msgs.add('• $res');
        }
        if (serverError != null && serverError!.isNotEmpty) {
          msgs.add('• $serverError'); // <- agrega el error del backend
        }
        return msgs.isEmpty ? null : msgs.join('\n');
      },
      onChanged: onChanged,
    );
  }
}
