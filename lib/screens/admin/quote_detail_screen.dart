import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';

import '../../core/external_links.dart';
import '../../core/quote_pdf_service.dart';
import '../../core/constants.dart';
import '../../core/photo_picker.dart';
import '../../core/app_routes.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/app_image.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/whatsapp_draft_sheet.dart';

class QuoteDetailScreen extends StatelessWidget {
  final AppState state;
  final Function(int) onNavigate;

  const QuoteDetailScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  void _openWhatsApp(
    BuildContext context,
    String phone,
    Quote quote,
    Client? client,
  ) {
    WhatsAppDraftSheet.show(
      context,
      state: state,
      quote: quote,
      client: client,
      phone: phone,
    );
  }

  void _showStatusPicker(BuildContext context, Quote quote) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Actualizar estado del pedido',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 14),
              for (final s in QuoteStatus.values)
                ListTile(
                  title: Row(
                    children: [
                      StatusBadge(status: s),
                      const SizedBox(width: 8),
                      if (s == quote.status)
                        Icon(Icons.check, color: AppColors.navy, size: 18),
                    ],
                  ),
                  onTap: () {
                    if (s == QuoteStatus.cancelada) {
                      state.archiveQuote(quote);
                    } else {
                      state.updateQuote(quote.copyWith(status: s));
                    }
                    Navigator.pop(ctx);
                    if (s == QuoteStatus.cancelada) {
                      onNavigate(AdminScreen.cotizaciones);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Estado actualizado a ${s.label}'),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportSheet(
    BuildContext context,
    Quote quote,
    Client? client,
    double paid,
    double saldo,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(ctx).size.height * 0.8,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cotización ${quote.folio}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.settings.bizName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${state.settings.bizAddress} • Tel: ${state.settings.bizPhone}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cliente: ${client?.name ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Fecha: ${quote.date}  •  Vigencia: 15 días',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'DESGLOSE DE PIEZAS',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final it in quote.items) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${it.qty}x ${it.width.round()}×${it.height.round()} cm',
                            ),
                            Text(
                              AppState.formatMXN(it.subtotal),
                              style: TextStyle(
                                fontFamily: AppText.monoFamily,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:'),
                          Text(AppState.formatMXN(quote.subtotal)),
                        ],
                      ),
                      if (quote.discount > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Descuento (${quote.discount.round()}%):'),
                            Text(
                              '- ${AppState.formatMXN(quote.discountAmount)}',
                              style: TextStyle(color: AppColors.cancelled),
                            ),
                          ],
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            AppState.formatMXN(quote.total),
                            style: TextStyle(
                              fontFamily: AppText.monoFamily,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (paid > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Anticipos pagados:'),
                            Text(
                              AppState.formatMXN(paid),
                              style: TextStyle(
                                fontFamily: AppText.monoFamily,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                color: AppColors.done,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Saldo restante:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              AppState.formatMXN(saldo),
                              style: TextStyle(
                                fontFamily: AppText.monoFamily,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                fontWeight: FontWeight.w600,
                                color: AppColors.pending,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.done,
                  foregroundColor: AppColors.onInk,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text(
                  'Generar y compartir PDF',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final file = await QuotePdfService.create(
                      quote,
                      client,
                      state.settings.bizName,
                      state.settings.bizPhone,
                      state.settings.bizAddress,
                      (id) =>
                          state.products
                              .where((product) => product.id == id)
                              .firstOrNull
                              ?.name ??
                          'Producto',
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await QuotePdfService.share(file);
                  } catch (error) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'No se pudo generar o compartir el PDF: $error',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final quote = state.selectedQuote;
    if (quote == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle')),
        body: const Center(child: Text('No hay cotización seleccionada')),
      );
    }

    final client = state.clients
        .where((c) => c.id == quote.clientId)
        .firstOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paid = state.paidOf(quote.id);
    final saldo = (quote.total - paid).clamp(0.0, double.infinity);

    return Scaffold(
      appBar: TopBar(title: quote.folio),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card with folio & status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.folio,
                      style: TextStyle(
                        fontFamily: AppText.monoFamily,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Fecha: ${quote.date}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _showStatusPicker(context, quote),
                  child: Row(
                    children: [
                      StatusBadge(status: quote.status),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Client Contact Card
          if (client != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  AvatarWidget(name: client.name, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppColors.navy,
                          ),
                        ),
                        Text(
                          client.phone,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.phone, size: 18),
                    onPressed: () => ExternalLinks.call(context, client.phone),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.done,
                    ),
                    icon: Icon(Icons.chat, color: AppColors.onInk, size: 18),
                    onPressed: () =>
                        _openWhatsApp(context, client.phone, quote, client),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Products Breakdown Table
          Text(
            'PRODUCTOS COTIZADOS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: [
                for (int i = 0; i < quote.items.length; i++) ...[
                  if (i > 0) const Divider(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${quote.items[i].qty}x',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.products
                                      .where(
                                        (p) => p.id == quote.items[i].productId,
                                      )
                                      .firstOrNull
                                      ?.name ??
                                  'Pieza de aluminio',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${quote.items[i].width.round()} × ${quote.items[i].height.round()} cm  •  ${AppState.formatMXN(quote.items[i].unitPrice)} c/u',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        AppState.formatMXN(quote.items[i].subtotal),
                        style: TextStyle(
                          fontFamily: AppText.monoFamily,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Financial Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      AppState.formatMXN(quote.subtotal),
                      style: TextStyle(
                        fontFamily: AppText.monoFamily,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (quote.discount > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Descuento (${quote.discount.round()}%)',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '- ${AppState.formatMXN(quote.discountAmount)}',
                        style: TextStyle(
                          color: AppColors.cancelled,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Cotizado',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      AppState.formatMXN(quote.total),
                      style: TextStyle(
                        fontFamily: AppText.monoFamily,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                  ],
                ),
                if (paid > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Anticipos pagados',
                        style: TextStyle(color: AppColors.done, fontSize: 13),
                      ),
                      Text(
                        AppState.formatMXN(paid),
                        style: TextStyle(
                          fontFamily: AppText.monoFamily,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: AppColors.done,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Saldo pendiente',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.pending,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        AppState.formatMXN(saldo),
                        style: TextStyle(
                          fontFamily: AppText.monoFamily,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontWeight: FontWeight.w600,
                          color: AppColors.pending,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Fotos del avance: el cliente las ve en el detalle de su pedido.
          _progressPhotos(context, quote),
          const SizedBox(height: 20),

          // Export and Share Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.share),
            label: const Text(
              'Exportar y compartir cotización',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () =>
                _showExportSheet(context, quote, client, paid, saldo),
          ),
        ],
      ),
    );
  }

  /// Fotos del avance o de la instalación. Se toman con la cámara o se
  /// eligen de la galería; mantener presionada una foto la quita.
  Widget _progressPhotos(BuildContext context, Quote quote) {
    Future<void> add() async {
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
      state.setQuotePhotos(quote.id, [
        ...quote.photos,
        'data:image/jpeg;base64,${base64Encode(bytes)}',
      ]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto agregada. El cliente la verá en su pedido.'),
          ),
        );
      }
    }

    Future<void> remove(int index) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Quitar esta foto?'),
          content: const Text('El cliente dejará de verla.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Quitar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      state.setQuotePhotos(quote.id, [...quote.photos]..removeAt(index));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'FOTOS DEL AVANCE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: const Text('Agregar'),
              onPressed: add,
            ),
          ],
        ),
        if (quote.photos.isEmpty)
          Text(
            'Sin fotos. Agrega fotos de la fabricación o la instalación para que el cliente vea el avance.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          )
        else ...[
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (int i = 0; i < quote.photos.length; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(kRadius),
                  onTap: () => showImageViewer(
                    context,
                    images: quote.photos,
                    title: 'Avance de ${quote.folio}',
                  ),
                  onLongPress: () => remove(i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(kRadius),
                    child: AppImage(quote.photos[i]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Mantén presionada una foto para quitarla.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}
