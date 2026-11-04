import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Toma una foto con la cámara o la elige de la galería.
///
/// Permisos: en Android la app no declara el permiso de cámara, así que
/// image_picker abre la cámara del sistema sin pedirlo; en iOS el sistema lo
/// solicita la primera vez (textos en Info.plist). Si el usuario lo negó, se
/// explica cómo activarlo en lugar de fallar en silencio.
class PhotoPicker {
  /// La cámara solo existe en teléfonos (y en el navegador); en escritorio no.
  static bool get cameraAvailable =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Devuelve los bytes de la imagen, o null si el usuario canceló o no fue
  /// posible obtenerla (en ese caso ya se le mostró por qué).
  static Future<Uint8List?> pick(
    BuildContext context,
    ImageSource source, {
    double maxSize = 1600,
    int quality = 80,
  }) async {
    final isCamera = source == ImageSource.camera;
    if (isCamera && !cameraAvailable) {
      await _explain(
        context,
        'Cámara no disponible',
        'Este dispositivo no tiene cámara compatible. Elige una foto de la galería.',
      );
      return null;
    }
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: maxSize,
        maxHeight: maxSize,
        imageQuality: quality,
      );
      if (file == null) return null; // Canceló: no se cambia nada.
      return await file.readAsBytes();
    } on PlatformException catch (e) {
      debugPrint('PhotoPicker: ${e.code} ${e.message}');
      if (!context.mounted) return null;
      if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied') {
        await _explain(
          context,
          isCamera ? 'Permiso de cámara negado' : 'Permiso de fotos negado',
          'Para ${isCamera ? 'tomar fotografías' : 'elegir fotos'} activa el permiso:\n\n'
          '• Android: Ajustes › Aplicaciones › Aluminios › Permisos › '
          '${isCamera ? 'Cámara' : 'Fotos y videos'} › Permitir.\n'
          '• iPhone: Ajustes › Aluminios › ${isCamera ? 'Cámara' : 'Fotos'}.\n\n'
          'Después vuelve a intentarlo.',
        );
      } else {
        await _explain(
          context,
          isCamera
              ? 'No se pudo abrir la cámara'
              : 'No se pudo abrir la galería',
          'Inténtalo de nuevo. Si continúa, reinicia la app.\n(${e.code})',
        );
      }
      return null;
    } catch (e, stack) {
      debugPrint('PhotoPicker: $e\n$stack');
      if (!context.mounted) return null;
      await _explain(
        context,
        'No se pudo cargar la imagen',
        'Prueba con otra foto o inténtalo de nuevo.',
      );
      return null;
    }
  }

  static Future<void> _explain(
    BuildContext context,
    String title,
    String message,
  ) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
