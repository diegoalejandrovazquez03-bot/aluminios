import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/constants.dart';
import '../../state/app_state.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/top_bar.dart';
import 'client_order_detail_screen.dart';

class ClientOrdersScreen extends StatelessWidget {
  final AppState state;
  final Function(int) onNavigate;

  const ClientOrdersScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final quotes = state.clientQuotes;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: TopBar(
        title: 'Mis Pedidos',
        showLogo: true,
        onAvatarTap: () => onNavigate(3),
      ),
      body: quotes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 54,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No tienes pedidos registrados',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => onNavigate(1), // Catálogo
                    child: const Text('Explorar Catálogo'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: quotes.length,
              itemBuilder: (context, i) {
                final q = quotes[i];
                final paid = state.paidOf(q.id);
                final saldo = (q.total - paid).clamp(0.0, double.infinity);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ClientOrderDetailScreen(quote: q, state: state),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  q.folio,
                                  style: TextStyle(
                                    fontFamily: AppText.monoFamily,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.navy,
                                  ),
                                ),
                                StatusBadge(status: q.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Fecha: ${q.date} • ${q.items.length} pieza(s)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Saldo restante',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    Text(
                                      AppState.formatMXN(saldo),
                                      style: TextStyle(
                                        fontFamily: AppText.monoFamily,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: saldo > 0
                                            ? AppColors.pending
                                            : AppColors.done,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Total pedido',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    Text(
                                      AppState.formatMXN(q.total),
                                      style: TextStyle(
                                        fontFamily: AppText.monoFamily,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.navy,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
