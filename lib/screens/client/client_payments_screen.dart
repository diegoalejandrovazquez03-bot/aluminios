import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/payment_sheet.dart';
import '../../widgets/sales_chart.dart' show parseAppDate;

/// Historial de pagos del cliente: todos sus abonos, del más reciente al más
/// antiguo, con el recibo de cada uno.
class ClientPaymentsScreen extends StatelessWidget {
  final AppState state;

  const ClientPaymentsScreen({super.key, required this.state});

  static void open(BuildContext context, AppState state) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClientPaymentsScreen(state: state)),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final quotes = {for (final q in state.clientQuotes) q.id: q};
    final indexed = state.payments.indexed
        .where((e) => quotes.containsKey(e.$2.quoteId))
        .toList();
    // Más reciente primero; con la misma fecha, el último registrado arriba.
    indexed.sort((a, b) {
      final da = parseAppDate(a.$2.date) ?? DateTime(1970);
      final db = parseAppDate(b.$2.date) ?? DateTime(1970);
      final byDate = db.compareTo(da);
      return byDate != 0 ? byDate : b.$1.compareTo(a.$1);
    });
    final payments = indexed.map((e) => e.$2).toList();

    final totalPaid = payments.fold<double>(0, (a, p) => a + p.amount);
    var balance = 0.0;
    for (final q in quotes.values) {
      if (q.status == QuoteStatus.cancelada) continue;
      final rem = q.total - state.paidOf(q.id);
      if (rem > 0) balance += rem;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mis pagos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _figure(AppState.formatMXN(totalPaid), 'Total pagado'),
                Container(width: 1, height: 32, color: AppColors.divider),
                _figure(AppState.formatMXN(balance), 'Saldo pendiente'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (payments.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Text(
                'Aún no tienes pagos registrados.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else ...[
            Text(
              'TOCA UN PAGO PARA VER SU RECIBO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            for (final p in payments)
              _paymentRow(context, p, quotes[p.quoteId]!),
          ],
        ],
      ),
    );
  }

  Widget _figure(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.mono(fontSize: 16, color: AppColors.navy),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    ),
  );

  Widget _paymentRow(BuildContext context, Payment p, Quote quote) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: () => openReceipt(context, state, p),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.done,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido ${quote.folio}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        '${p.date} • ${p.method}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  AppState.formatMXN(p.amount),
                  style: AppText.mono(fontSize: 14, color: AppColors.done),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.receipt_long_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
