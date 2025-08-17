import 'package:company/utils/rules.dart';
import 'package:flutter/material.dart';

class FieldConfig {
  final String name;                // <- clave para payload y errores
  final String label;
  final IconData icon;
  final TextInputType keyboard;
  final int? maxLength;
  final bool digitsOnly;
  final String? hintText;
  final List<Rule> rules;
  final int? errorMaxLines;

  const FieldConfig({
    required this.name,
    required this.label,
    required this.icon,
    this.keyboard = TextInputType.text,
    this.maxLength,
    this.digitsOnly = false,
    this.hintText,
    this.rules = const [],
    this.errorMaxLines,
  });
}
