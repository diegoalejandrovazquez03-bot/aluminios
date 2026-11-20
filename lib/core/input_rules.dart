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

/// Montos en pesos: hasta 7 enteros y 2 centavos (coma o punto decimal).
class MoneyInput {
  static const keyboard = TextInputType.numberWithOptions(decimal: true);

  static final _pattern = RegExp(r'^\d{0,7}(\.\d{0,2})?$');

  static final List<TextInputFormatter> formatters = [
    TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text.replaceAll(',', '.');
      return _pattern.hasMatch(text) ? newValue.copyWith(text: text) : oldValue;
    }),
  ];

  /// Monto mayor a 0, o null si está vacío o no es válido.
  static double? parse(String text) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    return value == null || value <= 0 ? null : value;
  }

  /// Texto para rellenar un campo: sin ".0" sobrante y con 2 centavos si hay.
  static String format(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(2);
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

  /// Solo los dígitos: "(614) 123-4567" → "6141234567".
  static String digits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  /// Para mostrar: "6141234567" → "614 123 4567". Si no son 10 dígitos se
  /// deja como está.
  static String display(String phone) {
    final d = digits(phone);
    if (d.length != length) return phone;
    return '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
  }
}

/// Nombres de persona con mayúscula inicial: "juan pérez" → "Juan Pérez".
/// Solo cambia la primera letra de cada palabra (el resto se respeta) y las
/// palabras de enlace ("de", "la", "del") quedan como se escribieron.
String displayName(String name) {
  const linking = {'de', 'del', 'la', 'las', 'los', 'y'};
  final words = name.trim().split(RegExp(r'\s+'));
  return [
    for (int i = 0; i < words.length; i++)
      if (words[i].isEmpty || (i > 0 && linking.contains(words[i])))
        words[i]
      else
        words[i][0].toUpperCase() + words[i].substring(1),
  ].join(' ');
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

/// Para buscar: minúsculas y sin acentos, así "Martínez" se encuentra
/// escribiendo "martinez".
String normalizeSearch(String text) {
  const from = 'áéíóúüñ';
  const to = 'aeiouun';
  var out = text.toLowerCase().trim();
  for (int i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}
