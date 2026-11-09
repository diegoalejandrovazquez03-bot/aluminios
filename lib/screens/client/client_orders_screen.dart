import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/constants.dart';
import '../../core/app_routes.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/notices_button.dart';
import '../../widgets/server_refresh.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/ui.dart';
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

    return Scaffold(
      appBar: TopBar(
        title: 'Mis Pedidos',
        showLogo: true,
        actions: [NoticesButton(state: state)],
        onAvatarTap: () => onNavigate(ClientScreen.perfil),
      ),
      // Deslizar hacia abajo trae los cambios del taller (estado, abonos).
      body: RefreshIndicator(
        onRefresh: () => refreshFromServer(context, state),
        child: quotes.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 80),
                children: [
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No tienes pedidos registrados',
                    message: 'Revisa el catálogo y pide tu cotización.',
                    actionLabel: 'Explorar catálogo',
                    onAction: () => onNavigate(ClientScreen.catalogo),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: quotes.length,
                itemBuilder: (context, i) => _orderCard(context, quotes[i]),
              ),
      ),
    );
  }

  /// Tarjeta de un pedido: folio y estado arriba; fecha, piezas, saldo
  /// restante y total abajo.
  Widget _orderCard(BuildContext context, Quote q) {
    final paid = state.paidOf(q.id);
    final saldo = (q.total - paid).clamp(0.0, double.infinity);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientOrderDetailScreen(quote: q, state: state),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  q.folio,
                  style: AppText.mono(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
              StatusBadge(status: q.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${q.date} · ${q.items.length} pieza(s)',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          Divider(height: 20, color: AppColors.divider),
          SummaryLine(
            'Saldo restante',
            AppState.formatMXN(saldo),
            color: saldo > 0 ? AppColors.pendingText : AppColors.done,
          ),
          SummaryLine('Total del pedido', AppState.formatMXN(q.total)),
        ],
      ),
    );
  }
}
