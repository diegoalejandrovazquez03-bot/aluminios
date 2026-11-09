import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/app_routes.dart';
import '../../core/external_links.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/notices_button.dart';
import '../../widgets/server_refresh.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/ui.dart';
import '../../widgets/visit_status_chip.dart';
import 'client_order_detail_screen.dart';

class ClientHomeScreen extends StatelessWidget {
  final AppState state;
  final Function(int) onNavigate;

  const ClientHomeScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  static const _steps = ['Aprobado', 'Fabricación', 'Entrega'];

  /// Paso actual del pedido según su estado (-1 = aún sin aprobar).
  static int _stepOf(QuoteStatus s) {
    switch (s) {
      case QuoteStatus.aprobada:
        return 0;
      case QuoteStatus.enProceso:
        return 1;
      case QuoteStatus.completado:
        return 2;
      case QuoteStatus.entregado:
        return 3;
      case QuoteStatus.pendiente:
      case QuoteStatus.cancelada:
        return -1;
    }
  }

  String _orderTitle(Quote q) {
    if (q.items.isEmpty) return 'Pedido ${q.folio}';
    final first = state.products
        .where((p) => p.id == q.items.first.productId)
        .firstOrNull;
    final name = first?.name ?? 'Pedido';
    return q.items.length > 1 ? '$name y ${q.items.length - 1} más' : name;
  }

  void _openOrder(BuildContext context, Quote q) {
    state.setSelectedQuoteId(q.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientOrderDetailScreen(quote: q, state: state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = state.currentClient;
    final quotes = state.clientQuotes;

    // Pedido activo: el más reciente que no esté entregado ni cancelado
    final active = quotes
        .where(
          (q) =>
              q.status != QuoteStatus.entregado &&
              q.status != QuoteStatus.cancelada,
        )
        .firstOrNull;
    final others = quotes.where((q) => q != active).take(3).toList();

    double balance = 0;
    for (final q in quotes) {
      if (q.status == QuoteStatus.cancelada) continue;
      final rem = q.total - state.paidOf(q.id);
      if (rem > 0) balance += rem;
    }

    return Scaffold(
      appBar: TopBar(
        title: 'ALUMINIOS',
        showLogo: true,
        actions: [NoticesButton(state: state)],
        onAvatarTap: () =>
            onNavigate(ClientScreen.perfil), // Perfil del cliente
      ),
      body: RefreshIndicator(
        // Deslizar hacia abajo trae los cambios del taller (estados, abonos, visitas).
        onRefresh: () => refreshFromServer(context, state),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Text('MI CUENTA', style: AppText.label()),
            const SizedBox(height: 2),
            Text(
              client?.name ?? 'Cliente',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 18),

            if (active != null)
              _activeOrderCard(context, active)
            else
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sin pedidos activos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      balance > 0
                          ? 'Saldo pendiente: ${AppState.formatMXN(balance)}'
                          : 'Revisa el catálogo y pide una cotización.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Escribir al taller'),
                    onPressed: () => ExternalLinks.whatsApp(
                      context,
                      state.settings.bizPhone,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        onNavigate(ClientScreen.catalogo), // Catálogo
                    child: const Text('Pedir cotización'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            ..._visitsSection(),

            SectionHeader(
              'Pedidos anteriores',
              action: 'Ver todos',
              onAction: () => onNavigate(ClientScreen.pedidos),
            ),
            ListBox(
              children: [
                if (others.isEmpty)
                  const BoxRow(title: 'Aún no tienes otros pedidos'),
                for (final q in others) _orderRow(context, q),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "Mis visitas": las próximas (de la más cercana a la más lejana) y las
  /// 3 realizadas más recientes, con su estado.
  List<Widget> _visitsSection() {
    final clientId = state.session?.clientId;
    final mine = state.visits.where((v) => v.clientId == clientId).toList();
    final upcoming = mine.where((v) => !v.isDone).toList()
      ..sort(
        (a, b) => '${a.date} ${a.start}'.compareTo('${b.date} ${b.start}'),
      );
    final done = mine.where((v) => v.isDone).toList()
      ..sort(
        (a, b) => '${b.date} ${b.start}'.compareTo('${a.date} ${a.start}'),
      );
    final shown = [...upcoming, ...done.take(3)];

    return [
      SectionHeader(
        'Mis visitas',
        action: 'Solicitar',
        onAction: () => onNavigate(ClientScreen.catalogo),
      ),
      ListBox(
        children: [
          if (shown.isEmpty)
            const BoxRow(
              title: 'No tienes visitas',
              subtitle:
                  'Puedes solicitar una visita técnica desde el catálogo.',
            ),
          for (final v in shown)
            BoxRow(
              title: v.type,
              subtitle: [
                '${_visitDate(v.date)} · ${v.start}–${v.end}',
                if (v.place.isNotEmpty) v.place,
              ].join('\n'),
              trailing: VisitStatusChip(visit: v),
            ),
        ],
      ),
      const SizedBox(height: 24),
    ];
  }

  static String _visitDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _activeOrderCard(BuildContext context, Quote q) {
    final paid = state.paidOf(q.id);
    final rem = (q.total - paid).clamp(0, double.infinity);
    final progress = q.total > 0 ? (paid / q.total).clamp(0.0, 1.0) : 0.0;
    final step = _stepOf(q.status);
    final fg = AppColors.navy;

    return AppCard(
      onTap: () => _openOrder(context, q),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido activo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _orderTitle(q),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${q.folio} · ${q.date}',
                      style: AppText.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: q.status),
            ],
          ),
          if (step >= 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                for (int i = 0; i < _steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: i < step
                                ? fg
                                : i == step
                                ? AppColors.blue
                                : AppColors.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _steps[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: i == step
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: i == step
                                ? AppColors.blue
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Saldo pendiente',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
              MoneyText(AppState.formatMXN(rem), fontSize: 22),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation(fg),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pagado ${AppState.formatMXN(paid)} de ${AppState.formatMXN(q.total)}',
            style: AppText.mono(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderRow(BuildContext context, Quote q) {
    return BoxRow(
      onTap: () => _openOrder(context, q),
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: StatusBadge.dotColor(q.status),
          shape: BoxShape.circle,
        ),
      ),
      title: _orderTitle(q),
      subtitle: '${q.folio} · ${q.status.label}',
      trailing: MoneyText(AppState.formatMXN(q.total)),
    );
  }
}
