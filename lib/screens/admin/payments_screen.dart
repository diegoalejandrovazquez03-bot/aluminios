import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/app_routes.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/payment_sheet.dart';
import '../../widgets/sales_chart.dart' show parseAppDate;
import '../../widgets/top_bar.dart';
import '../../widgets/ui.dart';

class PaymentsScreen extends StatefulWidget {
  final AppState state;
  final Function(int) onNavigate;

  const PaymentsScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  void _openNewPaymentModal() => showPaymentSheet(context, widget.state);

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    final totalCollected = state.payments.fold<double>(
      0,
      (a, p) => a + p.amount,
    );
    final balance = state.balanceDue;
    // Historial del más reciente al más antiguo, por fecha del pago.
    final payments = [...state.payments]
      ..sort((a, b) {
        final da = parseAppDate(a.date) ?? DateTime(0);
        final db = parseAppDate(b.date) ?? DateTime(0);
        return db.compareTo(da);
      });

    return Scaffold(
      appBar: TopBar(
        title: 'Anticipos y pagos',
        showLogo: true,
        onAvatarTap: () => widget.onNavigate(AdminScreen.perfil),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MetricPanel(
            label: 'Saldo por cobrar',
            value: AppState.formatMXN(balance.amount),
            caption: balance.quotes == 1
                ? 'En 1 cotización aprobada'
                : 'En ${balance.quotes} cotizaciones aprobadas',
            figures: [
              ('Total cobrado', AppState.formatMXN(totalCollected)),
              ('Pagos registrados', '${state.payments.length}'),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Registrar nuevo anticipo'),
            onPressed: _openNewPaymentModal,
          ),
          const SizedBox(height: 20),
          const SectionHeader('Historial de anticipos'),
          if (state.payments.isEmpty)
            EmptyState(
              icon: Icons.payments_outlined,
              title: 'Sin pagos registrados',
              message: 'Los anticipos y abonos aparecerán aquí.',
            )
          else
            ListBox(children: [for (final p in payments) _paymentRow(p)]),
        ],
      ),
    );
  }

  /// Renglón de un pago; al tocarlo abre su recibo.
  Widget _paymentRow(Payment p) {
    final state = widget.state;
    final q = state.quotes.where((x) => x.id == p.quoteId).firstOrNull;
    final c = q != null
        ? state.clients.where((x) => x.id == q.clientId).firstOrNull
        : null;

    return BoxRow(
      leading: IconBadge(
        Icons.check_circle_rounded,
        color: AppColors.done,
        background: AppColors.completedBg,
      ),
      title: '${q?.folio ?? 'Cotización'} · ${c?.name ?? 'Cliente'}',
      subtitle: '${p.date} · ${p.method}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyText(AppState.formatMXN(p.amount), color: AppColors.done),
          const SizedBox(width: 4),
          Icon(
            Icons.receipt_long_outlined,
            size: 18,
            color: AppColors.textMuted,
          ),
        ],
      ),
      onTap: () => openReceipt(context, state, p),
    );
  }
}
