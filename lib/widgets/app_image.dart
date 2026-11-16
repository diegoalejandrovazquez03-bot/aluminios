import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/constants.dart';

/// Imagen desde URL o desde `data:image/...;base64` (fotos tomadas en la app),
/// con indicador de carga y un ícono si no se puede mostrar.
///
/// Las fotos guardadas como texto se convierten una sola vez (ver
/// [_DataImages]) y todas se decodifican al tamaño en que se muestran, no a
/// su resolución completa: así una lista de miniaturas no rehace el trabajo
/// en cada redibujado ni ocupa memoria de más.
class AppImage extends StatelessWidget {
  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Qué mostrar si no hay foto o no se puede abrir; por defecto, el recuadro
  /// gris con ícono.
  final Widget? fallback;

  const AppImage(
    this.source, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) return _placeholder();
    final w = width, h = height;
    if (w != null && w.isFinite && (h == null || h.isFinite)) {
      return _image(context, math.max(w, h ?? 0));
    }
    // Sin medida fija: se toma la del espacio disponible.
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0,
        );
        return _image(context, side);
      },
    );
  }

  Widget _image(BuildContext context, double side) {
    final provider = _provider(context, side);
    if (provider == null) return _placeholder();
    return Image(
      image: provider,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      loadingBuilder: source.startsWith('data:image/')
          ? null
          : (context, child, progress) => progress == null
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

  ImageProvider? _provider(BuildContext context, double side) {
    final ImageProvider base;
    if (source.startsWith('data:image/')) {
      final bytes = _DataImages.bytes(source);
      if (bytes == null) return null;
      base = MemoryImage(bytes);
    } else {
      base = NetworkImage(source);
    }
    if (side <= 0) return base;
    // El doble del lado mayor: alcanza para recortar (BoxFit.cover) fotos
    // de hasta 2:1 sin que se vean borrosas.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth = (side * dpr * 2).round();
    return ResizeImage(
      base,
      width: decodeWidth,
      policy: ResizeImagePolicy.fit,
      allowUpscaling: false,
    );
  }

  Widget _placeholder() =>
      fallback ??
      Container(
        width: width,
        height: height,
        // Igual que el recuadro "sin foto" de Productos y Catálogo, en ambos modos.
        color: AppColors.dark ? AppColors.borderDark : AppColors.dividerLight,
        child: Icon(Icons.image_outlined, color: AppColors.textMuted),
      );
}

/// Fotos guardadas como texto ya convertidas a bytes. Siempre se entrega el
/// mismo objeto para la misma foto, así el caché de imágenes de Flutter la
/// reconoce y no la vuelve a decodificar.
class _DataImages {
  static const _max = 60;
  static final _cache = <String, Uint8List?>{}; // Conserva el orden de uso.

  static Uint8List? bytes(String source) {
    if (_cache.containsKey(source)) {
      // Se mueve al final: es la más reciente.
      final bytes = _cache.remove(source);
      _cache[source] = bytes;
      return bytes;
    }
    Uint8List? bytes;
    try {
      bytes = base64Decode(source.substring(source.indexOf(',') + 1));
    } catch (_) {
      bytes = null;
    }
    _cache[source] = bytes;
    if (_cache.length > _max) _cache.remove(_cache.keys.first);
    return bytes;
  }
}
