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
import '../../widgets/payment_sheet.dart';
import '../../widgets/pdf_preview_screen.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/ui.dart';
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
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(ctx).size.height * 0.8,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader('Cotización ${quote.folio}'),
              Divider(color: AppColors.divider),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.settings.bizName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        '${state.settings.bizAddress} · Tel: ${state.settings.bizPhone}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cliente: ${client?.name ?? ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        'Fecha: ${quote.date} · Vigencia: 15 días',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SectionHeader('Desglose de piezas'),
                      for (final it in quote.items)
                        SummaryLine(
                          '${it.qty}x ${it.width.round()}×${it.height.round()} cm',
                          AppState.formatMXN(it.subtotal),
                        ),
                      Divider(height: 24, color: AppColors.divider),
                      SummaryLine(
                        'Subtotal',
                        AppState.formatMXN(quote.subtotal),
                      ),
                      if (quote.discount > 0)
                        SummaryLine(
                          'Descuento (${quote.discount.round()}%)',
                          '- ${AppState.formatMXN(quote.discountAmount)}',
                          color: AppColors.cancelled,
                        ),
                      SummaryLine(
                        'Total',
                        AppState.formatMXN(quote.total),
                        strong: true,
                      ),
                      if (paid > 0) ...[
                        SummaryLine(
                          'Anticipos pagados',
                          AppState.formatMXN(paid),
                          color: AppColors.done,
                        ),
                        SummaryLine(
                          'Saldo restante',
                          AppState.formatMXN(saldo),
                          color: AppColors.pendingText,
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
                  'Ver y compartir PDF',
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
                    if (context.mounted) {
                      await showPdfPreview(
                        context,
                        file: file,
                        title: 'Cotización ${quote.folio}',
                      );
                    }
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
        body: const Center(
          child: EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No hay cotización seleccionada',
          ),
        ),
      );
    }

    final client = state.clients
        .where((c) => c.id == quote.clientId)
        .firstOrNull;
    final paid = state.paidOf(quote.id);
    final saldo = (quote.total - paid).clamp(0.0, double.infinity);

    return Scaffold(
      appBar: TopBar(title: quote.folio),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Folio, fecha y estado (tocar el estado lo cambia).
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
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
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
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(kRadius),
                  onTap: () => _showStatusPicker(context, quote),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        StatusBadge(status: quote.status),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Contacto del cliente
          if (client != null) ...[
            AppCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: AppColors.navy,
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
                    tooltip: 'Llamar',
                    icon: const Icon(Icons.phone, size: 18),
                    onPressed: () => ExternalLinks.call(context, client.phone),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: 'WhatsApp',
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
            const SizedBox(height: 20),
          ],

          const SectionHeader('Productos cotizados'),
          ListBox(children: [for (final item in quote.items) _itemRow(item)]),
          const SizedBox(height: 12),

          // Resumen de dinero
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                SummaryLine('Subtotal', AppState.formatMXN(quote.subtotal)),
                if (quote.discount > 0)
                  SummaryLine(
                    'Descuento (${quote.discount.round()}%)',
                    '- ${AppState.formatMXN(quote.discountAmount)}',
                    color: AppColors.cancelled,
                  ),
                Divider(height: 18, color: AppColors.divider),
                SummaryLine(
                  'Total cotizado',
                  AppState.formatMXN(quote.total),
                  strong: true,
                ),
                if (paid > 0) ...[
                  const SizedBox(height: 4),
                  SummaryLine(
                    'Anticipos pagados',
                    AppState.formatMXN(paid),
                    color: AppColors.done,
                  ),
                  SummaryLine(
                    'Saldo pendiente',
                    AppState.formatMXN(saldo),
                    color: AppColors.pendingText,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          _paymentsSection(context, quote, client, paid, saldo),
          const SizedBox(height: 20),

          // Fotos del avance: el cliente las ve en el detalle de su pedido.
          _progressPhotos(context, quote),
          const SizedBox(height: 20),

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

  /// Renglón de una pieza: cantidad, producto, medidas, precio unitario y
  /// subtotal.
  Widget _itemRow(QuoteItem item) {
    final name =
        state.products.where((p) => p.id == item.productId).firstOrNull?.name ??
        'Pieza de aluminio';
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
      title: item.note.isEmpty ? name : '$name · ${item.note}',
      subtitle: AppState.itemDetail(item),
      trailing: MoneyText(AppState.formatMXN(item.subtotal)),
    );
  }

  /// Mensaje de recordatorio de saldo para WhatsApp (editable antes de enviar).
  static String reminderMessage({
    required String bizName,
    required Quote quote,
    required Client client,
    required double paid,
    required double balance,
  }) {
    final firstName = client.name.trim().split(RegExp(r'\s+')).first;
    final b = StringBuffer()
      ..writeln('Hola $firstName, le saludamos de $bizName.')
      ..writeln()
      ..writeln(
        'Le recordamos que su pedido ${quote.folio} tiene un saldo '
        'pendiente de *${AppState.formatMXN(balance)}*.',
      )
      ..writeln('Total: ${AppState.formatMXN(quote.total)}');
    if (paid > 0) b.writeln('Abonado: ${AppState.formatMXN(paid)}');
    b
      ..writeln()
      ..write(
        'Puede pagar en efectivo, transferencia o tarjeta. '
        'Cualquier duda estamos a sus órdenes. ¡Gracias!',
      );
    return b.toString();
  }

  Future<void> _sendReminder(
    BuildContext context,
    Quote quote,
    Client client,
    double paid,
    double balance,
  ) async {
    final ctrl = TextEditingController(
      text: reminderMessage(
        bizName: state.settings.bizName,
        quote: quote,
        client: client,
        paid: paid,
        balance: balance,
      ),
    );
    final message = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recordatorio de saldo'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: ctrl,
            minLines: 6,
            maxLines: 12,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              helperText: 'Puedes editar el mensaje antes de enviarlo.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Abrir WhatsApp'),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (message == null || message.isEmpty || !context.mounted) return;
    await ExternalLinks.whatsApp(context, client.phone, message: message);
  }

  /// Abonos de la cotización (tocar uno abre su recibo), registrar un abono
  /// nuevo y mandar al cliente un recordatorio del saldo.
  Widget _paymentsSection(
    BuildContext context,
    Quote quote,
    Client? client,
    double paid,
    double saldo,
  ) {
    final payments = state.payments
        .where((p) => p.quoteId == quote.id)
        .toList();
    final canPay = quote.status != QuoteStatus.cancelada && saldo > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Pagos',
          action: canPay ? 'Registrar abono' : null,
          actionIcon: Icons.add,
          onAction: () => showPaymentSheet(context, state, quoteId: quote.id),
        ),
        if (payments.isEmpty)
          Text(
            canPay ? 'Sin abonos todavía.' : 'Sin abonos registrados.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          )
        else
          ListBox(
            children: [
              for (final p in payments)
                BoxRow(
                  leading: IconBadge(
                    Icons.check_circle_rounded,
                    color: AppColors.done,
                    background: AppColors.completedBg,
                  ),
                  title: AppState.formatMXN(p.amount),
                  monoTitle: true,
                  subtitle: '${p.date} · ${p.method}',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Recibo',
                        style: TextStyle(fontSize: 12, color: AppColors.blue),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.blue,
                      ),
                    ],
                  ),
                  onTap: () => openReceipt(context, state, p),
                ),
            ],
          ),
        if (canPay && client != null && client.phone.isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('Recordar saldo por WhatsApp'),
            onPressed: () => _sendReminder(context, quote, client, paid, saldo),
          ),
        ],
      ],
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
        SectionHeader(
          'Fotos del avance',
          action: 'Agregar',
          actionIcon: Icons.add_a_photo_outlined,
          onAction: add,
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
