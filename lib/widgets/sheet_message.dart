import 'package:flutter/material.dart';

/// Muestra un aviso breve por encima de todo, incluidas las hojas inferiores.
/// Un SnackBar normal queda oculto detrás de un showModalBottomSheet,
/// por eso las validaciones de los formularios en hojas usan esto.
void showSheetMessage(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      top: MediaQuery.of(ctx).padding.top + 12,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Material(
          color: const Color(0xFF323232),
          elevation: 6,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 2500), () {
    if (entry.mounted) entry.remove();
  });
}
