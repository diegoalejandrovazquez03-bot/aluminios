import 'package:aluminios_app/core/piece_advisor.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _texts(String name, double w, double h) => PieceAdvisor.advise(
  productName: name,
  widthCm: w,
  heightCm: h,
).map((a) => a.text).toList();

void main() {
  test('ventana chica sugiere cristal de 4 o 6 mm', () {
    expect(_texts('Ventana corrediza', 120, 80).single, contains('4 o 6 mm'));
  });

  test('ventana de más de 1.5 m² sugiere templado de 8 mm', () {
    expect(_texts('Ventana corrediza', 150, 120).first, contains('8 mm'));
  });

  test('ventana muy ancha sugiere más hojas', () {
    expect(_texts('Ventana corrediza', 200, 100), contains(contains('hojas')));
  });

  test('cancel de baño siempre pide templado y avisa altura baja', () {
    final t = _texts('Cancel de baño', 120, 150);
    expect(t.first, contains('templado'));
    expect(t, contains(contains('180–200')));
  });

  test('medidas en metros por error se marcan como advertencia', () {
    final a = PieceAdvisor.advise(
      productName: 'Puerta de aluminio',
      widthCm: 0.9,
      heightCm: 2.1,
    );
    expect(a.single.level, AdviceLevel.warning);
    expect(a.single.text, contains('centímetros'));
  });

  test('mosquitero chico no genera sugerencias', () {
    expect(_texts('Mosquitero', 100, 100), isEmpty);
  });
}
