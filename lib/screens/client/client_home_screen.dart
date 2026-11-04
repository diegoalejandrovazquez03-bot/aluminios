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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.textOnDark : AppColors.carbon;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;
    final surface = isDark ? AppColors.surfaceDark : Colors.white;

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
                color: fg,
              ),
            ),
            const SizedBox(height: 18),

            if (active != null)
              _activeOrderCard(
                context,
                active,
                isDark,
                fg,
                surface,
                borderColor,
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sin pedidos activos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: fg,
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

            ..._visitsSection(context, fg, surface, borderColor, isDark),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedidos anteriores',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => onNavigate(ClientScreen.pedidos),
                  child: const Text(
                    'Ver todos',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(kRadius),
                border: Border.all(color: borderColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: others.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'Aún no tienes otros pedidos',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (int i = 0; i < others.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.divider,
                            ),
                          _orderRow(context, others[i], fg),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Mis visitas": las próximas (de la más cercana a la más lejana) y las
  /// 3 realizadas más recientes, con su estado.
  List<Widget> _visitsSection(
    BuildContext context,
    Color fg,
    Color surface,
    Color borderColor,
    bool isDark,
  ) {
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
      Row(
        children: [
          Expanded(
            child: Text(
              'Mis visitas',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          TextButton(
            onPressed: () => onNavigate(ClientScreen.catalogo),
            child: const Text('Solicitar', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: borderColor),
        ),
        child: shown.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'No tienes visitas. Puedes solicitar una visita técnica desde el catálogo.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              )
            : Column(
                children: [
                  for (int i = 0; i < shown.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.divider,
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shown[i].type,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: fg,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_visitDate(shown[i].date)} · ${shown[i].start}–${shown[i].end}',
                                  style: AppText.mono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                if (shown[i].place.isNotEmpty)
                                  Text(
                                    shown[i].place,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          VisitStatusChip(visit: shown[i]),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
      const SizedBox(height: 24),
    ];
  }

  static String _visitDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _activeOrderCard(
    BuildContext context,
    Quote q,
    bool isDark,
    Color fg,
    Color surface,
    Color borderColor,
  ) {
    final paid = state.paidOf(q.id);
    final rem = (q.total - paid).clamp(0, double.infinity);
    final progress = q.total > 0 ? (paid / q.total).clamp(0.0, 1.0) : 0.0;
    final step = _stepOf(q.status);

    return InkWell(
      onTap: () => _openOrder(context, q),
      borderRadius: BorderRadius.circular(kRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: borderColor),
        ),
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
                                  ? AppColors.accent
                                  : (isDark
                                        ? AppColors.borderDark
                                        : AppColors.divider),
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
                                  ? AppColors.accent
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
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? AppColors.borderDark : AppColors.divider,
            ),
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
                Text(
                  AppState.formatMXN(rem),
                  style: AppText.mono(fontSize: 22, color: fg),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: isDark
                    ? AppColors.borderDark
                    : AppColors.divider,
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
      ),
    );
  }

  Widget _orderRow(BuildContext context, Quote q, Color fg) {
    return InkWell(
      onTap: () => _openOrder(context, q),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: StatusBadge.dotColor(q.status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _orderTitle(q),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${q.folio} · ${q.status.label}',
                    style: AppText.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              AppState.formatMXN(q.total),
              style: AppText.mono(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
