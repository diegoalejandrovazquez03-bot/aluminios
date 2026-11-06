import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/constants.dart';
import '../core/quote_pdf_service.dart';

/// Abre la vista previa del PDF ya generado; desde ahí se comparte.
Future<void> showPdfPreview(
  BuildContext context, {
  required File file,
  required String title,
  String shareText = 'Cotización en PDF',
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          PdfPreviewScreen(file: file, title: title, shareText: shareText),
    ),
  );
}

class PdfPreviewScreen extends StatelessWidget {
  final File file;
  final String title;

  /// Texto que acompaña al archivo al compartirlo.
  final String shareText;

  const PdfPreviewScreen({
    super.key,
    required this.file,
    required this.title,
    this.shareText = 'Cotización en PDF',
  });

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await QuotePdfService.share(file, text: shareText);
    } catch (error) {
      debugPrint('No se pudo compartir el PDF: $error');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo compartir el PDF. Inténtalo de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Compartir',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(context),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) => file.readAsBytes(),
        pdfFileName: file.uri.pathSegments.last,
        // Solo vista: compartir va en el botón propio de abajo.
        useActions: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        scrollViewDecoration: BoxDecoration(
          color: isDark ? AppColors.bgDark : AppColors.backgroundLight,
        ),
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
        ),
        loadingWidget: const Center(child: CircularProgressIndicator()),
        onError: (context, error) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No se pudo mostrar la vista previa. Puedes compartir el PDF '
              'con el botón de abajo.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.onInk,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.share_outlined),
            label: const Text(
              'Compartir PDF',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () => _share(context),
          ),
        ),
      ),
    );
  }
}
