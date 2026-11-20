import 'package:flutter/material.dart';

import '../core/dates.dart';

import '../core/constants.dart';
import '../models/models.dart';

/// Avance de un pedido en cuatro pasos: Aprobada → Fabricación →
/// Instalación → Entregada, con la fecha estimada de entrega abajo.
///
/// No se muestra en cotizaciones pendientes o canceladas: ahí todavía
/// (o ya) no hay pedido que seguir.
class OrderProgress extends StatelessWidget {
  final Quote quote;

  /// Si se da, junto a la fecha aparece "Cambiar" (solo el taller la edita).
  final VoidCallback? onEditDate;

  const OrderProgress({super.key, required this.quote, this.onEditDate});

  static const steps = ['Aprobada', 'Fabricación', 'Instalación', 'Entregada'];

  /// Paso en que va el pedido (0 a 3), o null si no aplica.
  static int? stepOf(QuoteStatus status) => switch (status) {
    QuoteStatus.aprobada => 0,
    QuoteStatus.enProceso => 1,
    QuoteStatus.completado => 2,
    QuoteStatus.entregado => 3,
    _ => null,
  };

  /// "28 de noviembre" a partir de aaaa-mm-dd.
  static String friendlyDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return displayDate(iso);
    return '${d.day} de ${monthNames[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final current = stepOf(quote.status);
    if (current == null) return const SizedBox.shrink();
    final delivered = current == steps.length - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idle = isDark ? AppColors.borderDark : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              _dot(i, current, idle),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    color: i < current ? AppColors.done : idle,
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (int i = 0; i < steps.length; i++)
              Expanded(
                child: Text(
                  steps[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == steps.length - 1
                      ? TextAlign.right
                      : TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == current
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: i <= current ? AppColors.navy : AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
        if (!delivered) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.event_available_outlined,
                size: 18,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  quote.deliveryDate.isEmpty
                      ? 'Fecha de entrega por definir'
                      : 'Entrega estimada: ${friendlyDate(quote.deliveryDate)}',
                  style: TextStyle(fontSize: 13, color: AppColors.navy),
                ),
              ),
              if (onEditDate != null)
                TextButton(
                  onPressed: onEditDate,
                  child: Text(
                    quote.deliveryDate.isEmpty ? 'Definir' : 'Cambiar',
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _dot(int i, int current, Color idle) {
    final done = i < current || (i == current && i == steps.length - 1);
    final active = i == current && !done;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? AppColors.done
            : active
            ? AppColors.blue
            : Colors.transparent,
        border: Border.all(
          color: done
              ? AppColors.done
              : active
              ? AppColors.blue
              : idle,
          width: 2,
        ),
      ),
      child: done
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }
}
