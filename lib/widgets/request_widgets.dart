import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants.dart';
import '../core/input_rules.dart';
import '../core/photo_picker.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'app_image.dart';
import 'image_viewer.dart';

/// Estado de una solicitud de cotización con su punto de color, igual que
/// [StatusBadge] en las cotizaciones.
class RequestStatusBadge extends StatelessWidget {
  final QuoteRequest request;

  /// El cliente ve textos explicados ("Aceptada · en preparación").
  final bool forClient;

  const RequestStatusBadge(this.request, {super.key, this.forClient = false});

  static Color dotColor(String status) => switch (status) {
    QuoteRequest.sent => AppColors.pending,
    QuoteRequest.accepted => AppColors.progress,
    QuoteRequest.quoted => AppColors.done,
    _ => AppColors.cancelled,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = request.status;
    final label = forClient
        ? request.clientLabel
        : status == QuoteRequest.sent
        ? 'Nueva'
        : status;
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
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.textOnDark
                : status == QuoteRequest.sent
                ? AppColors.pendingText
                : dotColor(status),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Medidas y cantidad de una solicitud en una línea ("120 × 100 cm · 2
/// piezas"), o null si el cliente no las dio.
String? requestMeasures(QuoteRequest r) {
  final parts = <String>[
    if (r.width != null && r.height != null)
      '${MeasureInput.format(r.width)} × ${MeasureInput.format(r.height)} cm',
    if (r.qty > 1) '${r.qty} piezas',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Cuadrícula de fotos de una solicitud. Con [onChanged] se pueden agregar
/// (hasta [maxPhotos]) y quitar; sin él solo se ven.
class RequestPhotos extends StatelessWidget {
  final List<String> photos;
  final String title;
  final ValueChanged<List<String>>? onChanged;
  static const maxPhotos = 4;

  const RequestPhotos({
    super.key,
    required this.photos,
    required this.title,
    this.onChanged,
  });

  Future<void> _add(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (PhotoPicker.cameraAvailable)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tomar fotografía'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
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
    if (source == null || !context.mounted) return;
    final bytes = await PhotoPicker.pick(
      context,
      source,
      maxSize: 1200,
      quality: 70,
    );
    if (bytes == null) return;
    onChanged!([...photos, 'data:image/jpeg;base64,${base64Encode(bytes)}']);
  }

  @override
  Widget build(BuildContext context) {
    final editable = onChanged != null;
    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (int i = 0; i < photos.length; i++)
          Stack(
            fit: StackFit.expand,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(kRadius),
                onTap: () =>
                    showImageViewer(context, images: photos, title: title),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(kRadius),
                  child: AppImage(photos[i]),
                ),
              ),
              if (editable)
                Positioned(
                  top: 2,
                  right: 2,
                  child: InkWell(
                    onTap: () => onChanged!(List.of(photos)..removeAt(i)),
                    child: Semantics(
                      label: 'Quitar foto',
                      button: true,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        if (editable && photos.length < maxPhotos)
          OutlinedButton(
            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => _add(context),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_a_photo_outlined, size: 20),
                SizedBox(height: 2),
                Text('Agregar', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
      ],
    );
  }
}
