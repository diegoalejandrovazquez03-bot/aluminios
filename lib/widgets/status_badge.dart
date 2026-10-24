import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/models.dart';

class StatusBadge extends StatelessWidget {
  final QuoteStatus status;

  const StatusBadge({super.key, required this.status});

  /// Color del punto de estado: 4 colores con significado.
  static Color dotColor(QuoteStatus status) {
    switch (status) {
      case QuoteStatus.pendiente:
        return AppColors.pending;
      case QuoteStatus.aprobada:
      case QuoteStatus.enProceso:
        return AppColors.progress;
      case QuoteStatus.completado:
      case QuoteStatus.entregado:
        return AppColors.done;
      case QuoteStatus.cancelada:
        return AppColors.cancelled;
    }
  }

  static Color textColor(QuoteStatus status, {bool isDark = false}) {
    if (isDark) return AppColors.textOnDark;
    if (status == QuoteStatus.pendiente) return AppColors.pendingText;
    return dotColor(status);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor(status),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          status.label,
          style: TextStyle(
            color: textColor(status, isDark: isDark),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
