import 'package:flutter/services.dart';

/// Reglas de captura compartidas: medidas en cm y teléfonos de 10 dígitos.
class MeasureInput {
  /// Medida máxima aceptada (cm). Más que eso casi siempre es un error de captura.
  static const double maxCm = 1000;

  static const keyboard = TextInputType.numberWithOptions(decimal: true);

  /// Solo dígitos y un separador decimal (coma o punto; la coma se convierte
  /// en punto). Hasta 4 enteros y 2 decimales. El texto nunca se reescribe
  /// mientras se teclea, así que no se pierden dígitos.
  static final _pattern = RegExp(r'^\d{0,4}(\.\d{0,2})?$');

  static final List<TextInputFormatter> formatters = [
    TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text.replaceAll(',', '.');
      // Si la tecla no forma una medida válida se ignora y se conserva lo
      // que ya estaba escrito (nunca se borra el campo).
      return _pattern.hasMatch(text) ? newValue.copyWith(text: text) : oldValue;
    }),
  ];

  /// Valor en cm, o null si está vacío o no es una medida válida.
  static double? parse(String text) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0 || value > maxCm) return null;
    return value;
  }

  /// Mensaje de error para mostrar bajo el campo (null si es válida).
  static String? validate(String text) {
    if (text.trim().isEmpty) return 'Requerido';
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    if (value == null) return 'Número no válido';
    if (value <= 0) return 'Debe ser mayor a 0';
    if (value > maxCm) return 'Máximo ${maxCm.toStringAsFixed(0)} cm';
    return null;
  }

  /// Texto inicial de un campo: sin ".0" sobrante.
  static String format(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
  }
}

class PhoneInput {
  static const int length = 10;

  /// Solo dígitos 0-9 (sin signos, letras ni espacios) y máximo 10.
  static final List<TextInputFormatter> formatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(length),
  ];

  /// Mensaje de error, o null si son exactamente 10 dígitos.
  static String? validate(String text) {
    final value = text.trim();
    if (value.isEmpty) return 'Escribe el teléfono';
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'Usa solo números del 0 al 9';
    }
    if (value.length != length) {
      return 'El teléfono debe tener exactamente $length dígitos';
    }
    return null;
  }
}

class AccountInput {
  static const int minPassword = 6;
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Mensaje de error, o null si el correo tiene un formato válido.
  static String? validateEmail(String text) {
    final value = text.trim();
    if (value.isEmpty) return 'Escribe tu correo electrónico';
    if (!_email.hasMatch(value)) return 'Escribe un correo válido';
    return null;
  }

  /// Mensaje de error, o null si la contraseña cumple el mínimo.
  static String? validatePassword(String text) {
    if (text.isEmpty) return 'Escribe una contraseña';
    if (text.length < minPassword) {
      return 'La contraseña debe tener al menos $minPassword caracteres';
    }
    return null;
  }
}
