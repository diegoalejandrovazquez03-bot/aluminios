import 'package:flutter/material.dart';

import '../../core/dates.dart';

import '../../core/theme.dart';

import '../../core/constants.dart';
import '../../core/app_routes.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/server_refresh.dart';
import '../../widgets/request_widgets.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/ui.dart';
import 'client_order_detail_screen.dart';
import 'client_request_screen.dart';

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
    // Las ya cotizadas se ven como pedido; aquí solo las que siguen en
    // revisión o no se aceptaron.
    final requests = state.clientRequests
        .where((r) => r.status != QuoteRequest.quoted)
        .toList();
    void newRequest() => openRequestForm(
      context,
      state,
      onOpenCatalog: () => onNavigate(ClientScreen.catalogo),
    );

    return Scaffold(
      appBar: TopBar(title: 'Mis pedidos', showLogo: true),
      // Deslizar hacia abajo trae los cambios del taller (estado, abonos).
      body: RefreshIndicator(
        onRefresh: () => refreshFromServer(context, state),
        child: quotes.isEmpty && requests.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 80),
                children: [
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No tienes pedidos registrados',
                    message:
                        'Describe lo que necesitas y el taller te enviará '
                        'la cotización.',
                    actionLabel: 'Solicitar cotización',
                    onAction: newRequest,
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Solicitar cotización'),
                    onPressed: newRequest,
                  ),
                  const SizedBox(height: 20),
                  if (requests.isNotEmpty) ...[
                    const SectionHeader('Mis solicitudes'),
                    ListBox(
                      children: [
                        for (final r in requests)
                          BoxRow(
                            title: r.type,
                            subtitle:
                                '${displayDate(r.date)} · ${r.description}',
                            trailing: RequestStatusBadge(r, forClient: true),
                            onTap: () => showClientRequest(context, r),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (quotes.isNotEmpty) ...[
                    const SectionHeader('Mis pedidos'),
                    for (final q in quotes) _orderCard(context, q),
                  ],
                ],
              ),
      ),
    );
  }

  /// Tarjeta de un pedido: folio y estado arriba; fecha, piezas, saldo
  /// restante y total abajo.
  Widget _orderCard(BuildContext context, Quote q) {
    final saldo = state.remainingOf(q);

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
            '${displayDate(q.date)} · ${AppState.plural(q.items.length, 'pieza', 'piezas')}',
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
