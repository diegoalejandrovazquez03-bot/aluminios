import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/status_badge.dart';

class ClientOrderDetailScreen extends StatelessWidget {
  final Quote quote;
  final AppState state;

  const ClientOrderDetailScreen({
    super.key,
    required this.quote,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
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
                Column(
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
                StatusBadge(status: quote.status),
              ],
            ),
          ),
          const SizedBox(height: 16),

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
                    const Text(
                      'Total del pedido',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
                    Text(
                      'Total abonado',
                      style: TextStyle(color: AppColors.done),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${p.date} • ${p.method}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      AppState.formatMXN(p.amount),
                      style: TextStyle(
                        fontFamily: AppText.monoFamily,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                        color: AppColors.done,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
