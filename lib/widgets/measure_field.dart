import 'package:flutter/material.dart';

import '../core/input_rules.dart';

/// Campo de medida en cm: acepta enteros y decimales (coma o punto), conserva
/// lo escrito y deja espacio para la etiqueta, la unidad y el error sin que se
/// encimen aunque haya varios en una misma fila.
class MeasureField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const MeasureField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: MeasureInput.keyboard,
      inputFormatters: MeasureInput.formatters,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'cm',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        errorText: errorText,
        errorMaxLines: 2,
      ),
      onChanged: onChanged,
    );
  }
}
