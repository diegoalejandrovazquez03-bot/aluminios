import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/constants.dart';

/// Imagen desde URL o desde `data:image/...;base64` (fotos tomadas en la app),
/// con indicador de carga y un ícono si no se puede mostrar.
class AppImage extends StatelessWidget {
  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppImage(
    this.source, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('data:image/')) {
      try {
        return Image.memory(
          base64Decode(source.split(',').last),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => _placeholder(),
        );
      } catch (_) {
        return _placeholder();
      }
    }
    if (source.isEmpty) return _placeholder();
    return Image.network(
      source,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : SizedBox(
              width: width,
              height: height,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    width: width,
    height: height,
    color: AppColors.border,
    child: const Icon(
      Icons.image_not_supported_outlined,
      color: Colors.black38,
    ),
  );
}
