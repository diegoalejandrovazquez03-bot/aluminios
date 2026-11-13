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
import '../../widgets/ui.dart';

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
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.folio,
                        style: AppText.mono(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
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

          const SectionHeader('Piezas incluidas'),
          ListBox(children: [for (final item in quote.items) _itemRow(item)]),
          const SizedBox(height: 16),

          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                SummaryLine(
                  'Total del pedido',
                  AppState.formatMXN(quote.total),
                ),
                SummaryLine(
                  'Total abonado',
                  AppState.formatMXN(paid),
                  color: AppColors.done,
                ),
                Divider(height: 16, color: AppColors.divider),
                SummaryLine(
                  'Saldo restante',
                  AppState.formatMXN(saldo),
                  color: saldo > 0 ? AppColors.pendingText : AppColors.done,
                  strong: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (quotePayments.isNotEmpty) ...[
            const SectionHeader('Abonos registrados'),
            ListBox(
              children: [
                for (final p in quotePayments)
                  // Tocar un abono abre su recibo.
                  BoxRow(
                    title: p.date,
                    subtitle: p.method,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MoneyText(
                          AppState.formatMXN(p.amount),
                          color: AppColors.done,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                    onTap: () => openReceipt(context, state, p),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (quote.photos.isNotEmpty) ...[
            _photosSection(context, quote),
            const SizedBox(height: 16),
          ],
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Ver o compartir PDF'),
            onPressed: () => _sharePdf(context, quote),
          ),
        ],
      ),
    );
  }

  /// Renglón de una pieza: cantidad, nombre, medidas y subtotal.
  Widget _itemRow(QuoteItem item) {
    final prod = state.products
        .where((p) => p.id == item.productId)
        .firstOrNull;
    return BoxRow(
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.lightBlue,
          borderRadius: BorderRadius.circular(kRadius),
        ),
        child: Text(
          '${item.qty}x',
          style: AppText.mono(fontSize: 12, color: AppColors.navy),
        ),
      ),
      title: item.note.isEmpty
          ? prod?.name ?? 'Pieza'
          : '${prod?.name ?? 'Pieza'} · ${item.note}',
      subtitle: AppState.itemDetail(item),
      trailing: MoneyText(AppState.formatMXN(item.subtotal)),
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
        const SectionHeader('Fotos del avance'),
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
        state.settings,
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
