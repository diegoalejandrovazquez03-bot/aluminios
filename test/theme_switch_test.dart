import 'package:aluminios_app/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Botones y controles que se redibujan durante el cambio de tema.
Widget _sample(ThemeData theme, {Duration duration = kThemeAnimationDuration}) {
  return AnimatedTheme(
    data: theme,
    duration: duration,
    child: MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextButton(onPressed: () {}, child: const Text('Texto')),
            OutlinedButton(onPressed: () {}, child: const Text('Contorno')),
            ElevatedButton(onPressed: () {}, child: const Text('Elevado')),
            const Chip(label: Text('Etiqueta')),
            const TextField(decoration: InputDecoration(labelText: 'Campo')),
          ],
        ),
      ),
    ),
  );
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('Cambiar de claro a oscuro con animación no falla', (
    tester,
  ) async {
    await tester.pumpWidget(_sample(AppTheme.lightTheme()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_sample(AppTheme.darkTheme()));
    // Recorre la animación cuadro por cuadro (ahí estaba el error).
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Y de regreso a claro.
    await tester.pumpWidget(_sample(AppTheme.lightTheme()));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('Los dos temas definen los mismos estilos de texto', () {
    final light = AppTheme.lightTheme();
    final dark = AppTheme.darkTheme();
    // Interpolar todo el tema no debe fallar en ningún punto.
    for (final t in [0.0, 0.3, 0.6, 1.0]) {
      expect(() => ThemeData.lerp(light, dark, t), returnsNormally);
    }
    expect(
      dark.textButtonTheme.style?.textStyle != null,
      light.textButtonTheme.style?.textStyle != null,
    );
    expect(
      dark.outlinedButtonTheme.style?.textStyle != null,
      light.outlinedButtonTheme.style?.textStyle != null,
    );
    expect(
      dark.chipTheme.labelStyle != null,
      light.chipTheme.labelStyle != null,
    );
  });
}
