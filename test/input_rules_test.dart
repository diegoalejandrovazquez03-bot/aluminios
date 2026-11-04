import 'package:aluminios_app/core/input_rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Aplica los formateadores como si el usuario tecleara [typed] sobre [before].
String typeWith(
  List<TextInputFormatter> formatters,
  String before,
  String typed,
) {
  var oldValue = TextEditingValue(text: before);
  var newValue = TextEditingValue(
    text: typed,
    selection: TextSelection.collapsed(offset: typed.length),
  );
  for (final f in formatters) {
    newValue = f.formatEditUpdate(oldValue, newValue);
  }
  return newValue.text;
}

void main() {
  group('Teléfono', () {
    test('acepta exactamente 10 dígitos', () {
      expect(PhoneInput.validate('9993409396'), isNull);
    });
    test('rechaza menos de 10, letras y signos', () {
      expect(PhoneInput.validate('99934'), isNotNull);
      expect(PhoneInput.validate('99934093a6'), isNotNull);
      expect(PhoneInput.validate('-999340939'), isNotNull);
      expect(PhoneInput.validate(''), isNotNull);
    });
    test('el campo solo deja escribir dígitos y máximo 10', () {
      // Letras y signos se descartan; solo quedan los dígitos.
      expect(typeWith(PhoneInput.formatters, '', '99a-9'), '999');
      expect(typeWith(PhoneInput.formatters, '999', '9994'), '9994');
      expect(
        typeWith(PhoneInput.formatters, '9993409396', '99934093961'),
        '9993409396',
      );
    });
  });

  group('Medidas', () {
    test('permite escribir decimales sin perder dígitos', () {
      expect(typeWith(MeasureInput.formatters, '120', '120.'), '120.');
      expect(typeWith(MeasureInput.formatters, '120.', '120.5'), '120.5');
      expect(typeWith(MeasureInput.formatters, '120', '120,'), '120.');
    });
    test('rechaza letras, signos y más de 2 decimales', () {
      expect(typeWith(MeasureInput.formatters, '12', '12a'), '12');
      expect(typeWith(MeasureInput.formatters, '', '-5'), '');
      expect(typeWith(MeasureInput.formatters, '1.25', '1.255'), '1.25');
    });
    test('valida rango para los cálculos', () {
      expect(MeasureInput.parse('120.5'), 120.5);
      expect(MeasureInput.parse('0'), isNull);
      expect(MeasureInput.parse('1500'), isNull);
      expect(MeasureInput.validate(''), 'Requerido');
      expect(MeasureInput.format(120), '120');
      expect(MeasureInput.format(120.5), '120.5');
    });
  });
}
