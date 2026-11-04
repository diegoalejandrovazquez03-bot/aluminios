import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/photo_picker.dart';
import 'image_viewer.dart';

/// Menú de la foto de perfil: tomar foto, elegir de la galería, ver la actual
/// o cancelar. Muestra una vista previa antes de guardar; si el usuario
/// cancela en cualquier paso, la foto actual no cambia.
///
/// [onSave] recibe la nueva foto como `data:image/jpeg;base64,...`.
Future<void> showProfilePhotoOptions(
  BuildContext context, {
  required String currentUrl,
  required void Function(String dataUrl) onSave,
}) async {
  final hasPhoto = currentUrl.isNotEmpty;
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Foto de perfil',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (PhotoPicker.cameraAvailable)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar fotografía'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.zoom_in),
              title: const Text('Ver foto actual'),
              onTap: () => Navigator.pop(ctx, 'view'),
            ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancelar'),
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  if (choice == 'view') {
    await showImageViewer(
      context,
      images: [currentUrl],
      title: 'Foto de perfil',
    );
    return;
  }

  final bytes = await PhotoPicker.pick(
    context,
    choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    maxSize: 1200,
    quality: 70,
  );
  if (bytes == null || !context.mounted) return; // Conserva la foto actual.

  final save = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Usar esta foto?'),
      content: ClipOval(
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  if (save != true) return;
  onSave('data:image/jpeg;base64,${base64Encode(bytes)}');
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Foto de perfil actualizada')));
  }
}
