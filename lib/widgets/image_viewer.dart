import 'package:flutter/material.dart';

import 'app_image.dart';

/// Visor de fotos a pantalla casi completa: deslizar entre fotos,
/// pellizcar para hacer zoom, botón de cerrar y datos del trabajo/producto.
Future<void> showImageViewer(
  BuildContext context, {
  required List<String> images,
  required String title,
  String? subtitle,
  String? details,
  Widget? action,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => _ImageViewer(
      images: images.isEmpty ? [''] : images,
      title: title,
      subtitle: subtitle,
      details: details,
      action: action,
    ),
  );
}

class _ImageViewer extends StatefulWidget {
  final List<String> images;
  final String title;
  final String? subtitle;
  final String? details;
  final Widget? action;

  const _ImageViewer({
    required this.images,
    required this.title,
    this.subtitle,
    this.details,
    this.action,
  });

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.55;

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: height,
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: widget.images.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => InteractiveViewer(
                    maxScale: 4,
                    child: Center(
                      child: AppImage(
                        widget.images[i],
                        width: double.infinity,
                        height: height,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton.filled(
                    tooltip: 'Cerrar',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                if (widget.images.length > 1)
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_page + 1} / ${widget.images.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (widget.subtitle != null)
                        Text(
                          widget.subtitle!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      if (widget.details != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            widget.details!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.action != null) widget.action!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
