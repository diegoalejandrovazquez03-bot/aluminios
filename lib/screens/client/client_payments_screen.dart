import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/payment_sheet.dart';
import '../../widgets/sales_chart.dart' show parseAppDate;
import '../../widgets/ui.dart';

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
          MetricPanel(
            label: 'Saldo pendiente',
            value: AppState.formatMXN(balance),
            figures: [
              ('Total pagado', AppState.formatMXN(totalPaid)),
              ('Pagos', '${payments.length}'),
            ],
          ),
          const SizedBox(height: 20),
          if (payments.isEmpty)
            const EmptyState(
              icon: Icons.payments_outlined,
              title: 'Aún no tienes pagos registrados',
            )
          else ...[
            const SectionHeader('Toca un pago para ver su recibo'),
            ListBox(
              children: [
                for (final p in payments)
                  BoxRow(
                    leading: IconBadge(
                      Icons.check_circle_rounded,
                      color: AppColors.done,
                      background: AppColors.completedBg,
                    ),
                    title: 'Pedido ${quotes[p.quoteId]!.folio}',
                    subtitle: '${AppState.displayDate(p.date)} · ${p.method}',
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
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                    onTap: () => openReceipt(context, state, p),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
