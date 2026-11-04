import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/models.dart';

/// Estado de una visita, con un color distinto para cada uno:
/// Por confirmar (ámbar), Confirmada (azul) y Realizada (verde).
class VisitStatusChip extends StatelessWidget {
  final Visit visit;

  const VisitStatusChip({super.key, required this.visit});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = visit.isDone
        ? (AppColors.completedBg, AppColors.done)
        : visit.isRequested
        ? (AppColors.pendingBg, AppColors.pendingText)
        : (AppColors.approvedBg, AppColors.blue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        visit.statusLabel,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
