import '../models/models.dart';
import '../state/app_state.dart';
import 'api_client.dart';

/// Mensaje de WhatsApp para enviar una cotización: redactado por el asistente
/// del backend (Claude) o, si no está disponible, con una plantilla fija.
class QuoteMessageService {
  static String _productName(AppState state, int productId) =>
      state.products.where((p) => p.id == productId).firstOrNull?.name ??
      'Pieza';

  static String _cm(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  static String template(AppState state, Quote quote, Client? client) {
    final paid = state.paidOf(quote.id);
    final biz = state.settings.bizName;
    final b = StringBuffer()
      ..writeln('Hola, ${client?.name ?? ''}.'.replaceAll(' .', '.'))
      ..writeln()
      ..writeln('Le comparto la cotización ${quote.folio} de $biz:')
      ..writeln();
    for (final it in quote.items) {
      b.writeln(
        '• ${_productName(state, it.productId)}: ${_cm(it.width)} × ${_cm(it.height)} cm, '
        '${it.qty} pza — ${AppState.formatMXN(it.subtotal)}',
      );
    }
    b.writeln();
    if (quote.discount > 0) {
      b.writeln('Descuento: ${quote.discount.toStringAsFixed(0)}%');
    }
    b.writeln('Total: *${AppState.formatMXN(quote.total)}*');
    if (paid > 0) {
      b
        ..writeln('Pagado: ${AppState.formatMXN(paid)}')
        ..writeln(
          'Saldo: ${AppState.formatMXN((quote.total - paid).clamp(0, double.infinity))}',
        );
    }
    b
      ..writeln()
      ..writeln(
        'Quedamos atentos para confirmar su pedido o resolver cualquier duda.',
      )
      ..write(biz);
    if (state.settings.bizPhone.isNotEmpty) {
      b.write(' · ${state.settings.bizPhone}');
    }
    return b.toString();
  }

  /// Devuelve el mensaje redactado por el asistente, o null si el backend o la
  /// IA no están disponibles (sin clave, sin conexión, error o tiempo agotado).
  static Future<String?> draftWithAssistant(
    AppState state,
    Quote quote,
    Client? client,
  ) async {
    try {
      final result = await ApiClient.request(
        'asistente',
        method: 'POST',
        action: 'mensaje-whatsapp',
        timeout: const Duration(seconds: 45),
        body: {
          'cliente': client?.name ?? 'Cliente',
          'folio': quote.folio,
          'fecha': quote.date,
          'estado': quote.status.label,
          'piezas': [
            for (final it in quote.items)
              {
                'producto': _productName(state, it.productId),
                'ancho': it.width,
                'alto': it.height,
                'cantidad': it.qty,
                'importe': it.subtotal,
              },
          ],
          'subtotal': quote.subtotal,
          'descuento': quote.discount,
          'total': quote.total,
          'pagado': state.paidOf(quote.id),
          'negocio': state.settings.bizName,
          'telefonoNegocio': state.settings.bizPhone,
        },
      );
      final text = (result is Map ? result['mensaje'] : null) as String?;
      return (text == null || text.trim().isEmpty) ? null : text.trim();
    } catch (_) {
      return null;
    }
  }
}
