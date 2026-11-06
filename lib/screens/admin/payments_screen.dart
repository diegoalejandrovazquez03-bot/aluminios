import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/app_routes.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/payment_sheet.dart';
import '../../widgets/top_bar.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double monthTotal = 0.0;
    for (final p in state.payments) {
      monthTotal += p.amount;
    }

    double pendingBalance = 0.0;
    for (final q in state.quotes) {
      if (q.status != QuoteStatus.cancelada) {
        final paid = state.paidOf(q.id);
        final rem = q.total - paid;
        if (rem > 0) pendingBalance += rem;
      }
    }

    return Scaffold(
      appBar: TopBar(
        title: 'Anticipos y Pagos',
        showLogo: true,
        onAvatarTap: () => widget.onNavigate(AdminScreen.perfil),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Metrics Cards Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Cobrado',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppState.formatMXN(monthTotal),
                        style: TextStyle(
                          fontFamily: AppText.monoFamily,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.done,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saldo por Cobrar',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppState.formatMXN(pendingBalance),
                        style: TextStyle(
                          fontFamily: AppText.monoFamily,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pending,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Register button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'Registrar nuevo anticipo',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: _openNewPaymentModal,
          ),
          const SizedBox(height: 20),

          Text(
            'HISTORIAL DE ANTICIPOS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),

          if (state.payments.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Sin pagos registrados',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            for (final p in state.payments.reversed) ...[
              Builder(
                builder: (ctx) {
                  final q = state.quotes
                      .where((x) => x.id == p.quoteId)
                      .firstOrNull;
                  final c = q != null
                      ? state.clients
                            .where((x) => x.id == q.clientId)
                            .firstOrNull
                      : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    // Tocar un pago abre su recibo.
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => openReceipt(context, state, p),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.completedBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.done,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${q?.folio ?? 'Cotización'} • ${c?.name ?? 'Cliente'}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.navy,
                                      ),
                                    ),
                                    Text(
                                      '${p.date} • ${p.method}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
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
                                  fontSize: 15,
                                  color: AppColors.done,
                                ),
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
                },
              ),
            ],
        ],
      ),
    );
  }
}
