import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/quote_pdf_service.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/app_image.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/payment_sheet.dart';
import '../../widgets/pdf_preview_screen.dart';
import '../../widgets/status_badge.dart';

class ClientOrderDetailScreen extends StatelessWidget {
  final Quote quote;
  final AppState state;

  const ClientOrderDetailScreen({
    super.key,
    required this.quote,
    required this.state,
  });

  // Se redibuja con cada cambio: al aprobar, al actualizar desde el servidor
  // o cuando el taller agrega fotos.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    // Versión actual de la cotización (no la copia con la que se abrió).
    final quote =
        state.quotes.where((q) => q.id == this.quote.id).firstOrNull ??
        this.quote;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paid = state.paidOf(quote.id);
    final saldo = (quote.total - paid).clamp(0.0, double.infinity);
    final quotePayments = state.payments
        .where((p) => p.quoteId == quote.id)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text('Detalle de ${quote.folio}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Order Header Card
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.folio,
                        style: TextStyle(
                          fontFamily: AppText.monoFamily,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.navy,
                        ),
                      ),
                      Text(
                        'Fecha de solicitud: ${quote.date}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(status: quote.status),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (quote.status == QuoteStatus.pendiente) ...[
            _responseCard(context, quote),
            const SizedBox(height: 16),
          ],

          // Items List
          Text(
            'PIEZAS INCLUIDAS',
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
                  if (i > 0) const Divider(height: 18),
                  Builder(
                    builder: (ctx) {
                      final item = quote.items[i];
                      final prod = state.products
                          .where((p) => p.id == item.productId)
                          .firstOrNull;

                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.lightBlue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.qty}x',
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
                                  prod?.name ?? 'Pieza',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${item.width.round()} × ${item.height.round()} cm • ${prod?.material ?? ''}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            AppState.formatMXN(item.subtotal),
                            style: TextStyle(
                              fontFamily: AppText.monoFamily,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      );
                    },
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
                    const Expanded(
                      child: Text(
                        'Total del pedido',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      AppState.formatMXN(quote.total),
                      style: TextStyle(
                        fontFamily: AppText.monoFamily,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Total abonado',
                        style: TextStyle(color: AppColors.done),
                      ),
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
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saldo restante',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.pending,
                      ),
                    ),
                    Text(
                      AppState.formatMXN(saldo),
                      style: TextStyle(
                        fontFamily: AppText.monoFamily,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.pending,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Payments history if any
          if (quotePayments.isNotEmpty) ...[
            Text(
              'ABONOS REGISTRADOS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            for (final p in quotePayments)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                // Tocar un abono abre su recibo.
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => openReceipt(context, state, p),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${p.date} • ${p.method}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          Text(
                            AppState.formatMXN(p.amount),
                            style: TextStyle(
                              fontFamily: AppText.monoFamily,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              fontWeight: FontWeight.w600,
                              color: AppColors.done,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
          if (quote.photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            _photosSection(context, quote),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Ver o compartir PDF'),
            onPressed: () => _sharePdf(context, quote),
          ),
        ],
      ),
    );
  }

  /// Recuadro para que el cliente apruebe o rechace la cotización pendiente.
  Widget _responseCard(BuildContext context, Quote quote) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¿Aceptas esta cotización?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Al aprobarla, el taller agenda la fabricación. Si la rechazas, quedará cancelada.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respond(context, quote, approve: false),
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respond(context, quote, approve: true),
                  child: const Text('Aprobar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    Quote quote, {
    required bool approve,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? '¿Aprobar cotización?' : '¿Rechazar cotización?'),
        content: Text(
          approve
              ? 'Confirmas la cotización ${quote.folio} por ${AppState.formatMXN(quote.total)}.'
              : 'La cotización ${quote.folio} quedará cancelada. Esta acción no se puede deshacer desde la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Aprobar' : 'Rechazar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = state.respondToQuote(quote.id, approve: approve);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              (approve
                  ? 'Cotización aprobada. El taller te contactará.'
                  : 'Cotización rechazada.'),
        ),
      ),
    );
  }

  /// Fotos del avance que subió el taller; al tocarlas se ven en grande.
  Widget _photosSection(BuildContext context, Quote quote) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'FOTOS DEL AVANCE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
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
                  subtitle: 'Foto ${i + 1} de ${quote.photos.length}',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(kRadius),
                  child: AppImage(quote.photos[i]),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Genera el PDF de la cotización y abre la vista previa para enviarlo.
  Future<void> _sharePdf(BuildContext context, Quote quote) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await QuotePdfService.create(
        quote,
        state.clients.where((c) => c.id == quote.clientId).firstOrNull,
        state.settings.bizName,
        state.settings.bizPhone,
        state.settings.bizAddress,
        (id) =>
            state.products.where((p) => p.id == id).firstOrNull?.name ??
            'Producto',
      );
      if (context.mounted) {
        await showPdfPreview(
          context,
          file: file,
          title: 'Cotización ${quote.folio}',
        );
      }
    } catch (error) {
      debugPrint('No se pudo generar el PDF: $error');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo generar el PDF. Inténtalo de nuevo.'),
        ),
      );
    }
  }
}
