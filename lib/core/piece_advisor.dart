/// Sugerencias técnicas por pieza del cotizador, calculadas en el teléfono
/// (sin internet) a partir del tipo de producto y sus medidas en cm.
enum AdviceLevel { info, warning }

class PieceAdvice {
  final AdviceLevel level;
  final String text;

  const PieceAdvice(this.level, this.text);
}

enum _Kind { ventana, puerta, cancel, mosquitero, domo, otro }

class PieceAdvisor {
  static _Kind _kindOf(String name) {
    final n = name.toLowerCase();
    if (n.contains('mosquit')) return _Kind.mosquitero;
    if (n.contains('cancel') || n.contains('baño') || n.contains('ducha')) {
      return _Kind.cancel;
    }
    if (n.contains('puerta')) return _Kind.puerta;
    if (n.contains('domo') || n.contains('tragaluz')) return _Kind.domo;
    if (n.contains('ventana')) return _Kind.ventana;
    return _Kind.otro;
  }

  static String _m2(double area) => '${area.toStringAsFixed(2)} m²';

  static List<PieceAdvice> advise({
    required String productName,
    required double widthCm,
    required double heightCm,
  }) {
    if (widthCm <= 0 || heightCm <= 0) return const [];

    final advice = <PieceAdvice>[];
    final kind = _kindOf(productName);
    final area = widthCm * heightCm / 10000;
    final w = widthCm.round();
    final h = heightCm.round();

    // Medidas sospechosas: lo más común es capturar metros en lugar de cm.
    if (widthCm < 20 || heightCm < 20) {
      advice.add(
        const PieceAdvice(
          AdviceLevel.warning,
          'Medida muy pequeña: verifica que esté en centímetros y no en metros.',
        ),
      );
      return advice;
    }
    if (widthCm > 400 || heightCm > 300) {
      advice.add(
        const PieceAdvice(
          AdviceLevel.warning,
          'Medida fuera de lo común: confírmala en obra; puede requerir dividirse en módulos.',
        ),
      );
    }

    switch (kind) {
      case _Kind.cancel:
        advice.add(
          const PieceAdvice(
            AdviceLevel.info,
            'Cancel de baño: cristal templado obligatorio (6 mm corredizo, 9 mm abatible).',
          ),
        );
        if (heightCm < 180) {
          advice.add(
            PieceAdvice(
              AdviceLevel.warning,
              'Altura de $h cm: lo común en cancel es 180–200 cm. Confírmala.',
            ),
          );
        }
        if (widthCm > 160) {
          advice.add(
            PieceAdvice(
              AdviceLevel.info,
              'Ancho de $w cm: considera fijo + 2 corredizas para no cargar una sola hoja.',
            ),
          );
        }
        break;

      case _Kind.puerta:
        advice.add(
          PieceAdvice(
            AdviceLevel.info,
            area > 2.0
                ? 'Puerta de ${_m2(area)}: cristal templado de 8 mm.'
                : 'Puerta: cristal templado de 6 mm como mínimo.',
          ),
        );
        if (heightCm < 190) {
          advice.add(
            PieceAdvice(
              AdviceLevel.warning,
              'Altura de $h cm es baja para puerta (lo común es 200–210 cm).',
            ),
          );
        }
        if (widthCm > 110) {
          advice.add(
            PieceAdvice(
              AdviceLevel.info,
              'Ancho de $w cm: considera puerta doble o con fijo lateral.',
            ),
          );
        }
        break;

      case _Kind.mosquitero:
        if (area > 2.0) {
          advice.add(
            PieceAdvice(
              AdviceLevel.info,
              'Mosquitero de ${_m2(area)}: agrega travesaño de refuerzo.',
            ),
          );
        }
        break;

      case _Kind.domo:
        advice.add(
          const PieceAdvice(
            AdviceLevel.info,
            'Domo: policarbonato o cristal laminado; nunca cristal sencillo en techo.',
          ),
        );
        break;

      case _Kind.ventana:
      case _Kind.otro:
        if (area > 2.5) {
          advice.add(
            PieceAdvice(
              AdviceLevel.warning,
              'Pieza de ${_m2(area)}: usa templado de 10 mm o divídela con un fijo.',
            ),
          );
        } else if (area > 1.5) {
          advice.add(
            PieceAdvice(
              AdviceLevel.info,
              'Pieza de ${_m2(area)}: cristal templado de 8 mm por seguridad.',
            ),
          );
        } else if (area > 1.0) {
          advice.add(
            PieceAdvice(
              AdviceLevel.info,
              'Pieza de ${_m2(area)}: cristal claro de 6 mm es suficiente.',
            ),
          );
        } else {
          advice.add(
            PieceAdvice(
              AdviceLevel.info,
              'Pieza de ${_m2(area)}: cristal de 4 o 6 mm.',
            ),
          );
        }
        if (kind == _Kind.ventana && widthCm > 180) {
          advice.add(
            PieceAdvice(
              AdviceLevel.info,
              'Ancho de $w cm: considera 3 o 4 hojas (máx. ~90 cm por hoja).',
            ),
          );
        }
        break;
    }

    return advice;
  }
}
