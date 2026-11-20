import 'package:flutter/material.dart';

import '../../core/dates.dart';

import '../../core/constants.dart';
import '../../core/app_routes.dart';
import '../../core/external_links.dart';
import '../../core/input_rules.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import 'client_request_screen.dart';
import '../../widgets/app_image.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/order_progress.dart';
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

    final balance = state.clientBalance;

    return Scaffold(
      appBar: TopBar(title: 'ALUMINIOS', showLogo: true),
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

            // La acción principal del cliente, grande y a la vista.
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.request_quote_outlined),
                label: const Text(
                  'Pedir cotización',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: () => openRequestForm(
                  context,
                  state,
                  onOpenCatalog: () => onNavigate(ClientScreen.catalogo),
                ),
              ),
            ),
            const SizedBox(height: 24),

            ..._worksSection(context),

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
            const SizedBox(height: 24),

            _workshopCard(context),
          ],
        ),
      ),
    );
  }

  /// "Nuestros trabajos": fotos de trabajos terminados del taller, en una
  /// tira que se desliza de lado. Tocar una la abre en grande.
  List<Widget> _worksSection(BuildContext context) {
    final works = state.works
        .where((w) => !w.custom && w.clientId == null && w.img.isNotEmpty)
        .take(8)
        .toList();
    if (works.isEmpty) return const [];
    return [
      const SectionHeader('Nuestros trabajos'),
      SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: works.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final w = works[i];
            return GestureDetector(
              onTap: () => showImageViewer(
                context,
                images: [w.img, ...w.photos],
                title: w.title,
              ),
              child: SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(kRadius),
                      child: AppImage(w.img, width: 140, height: 110),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      w.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.navy),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  /// Datos del taller: horario, dirección (abre el mapa) y WhatsApp.
  Widget _workshopCard(BuildContext context) {
    final s = state.settings;
    Widget row(IconData icon, String text, {VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 13, color: AppColors.navy),
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(s.bizName.isEmpty ? 'El taller' : s.bizName),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.bizHours.isNotEmpty) row(Icons.schedule, s.bizHours),
              if (s.bizAddress.isNotEmpty)
                row(
                  Icons.place_outlined,
                  s.bizAddress,
                  onTap: () => ExternalLinks.maps(context, s.bizAddress),
                ),
              if (s.bizPhone.isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: AppColors.done,
                  ),
                  label: Text('WhatsApp ${PhoneInput.display(s.bizPhone)}'),
                  onPressed: () => ExternalLinks.whatsApp(context, s.bizPhone),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// "Mis visitas": las próximas (de la más cercana a la más lejana) y las
  /// 3 realizadas más recientes, con su estado.
  List<Widget> _visitsSection() {
    final mine = state.clientVisits;
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
                '${displayDate(v.date)} · ${v.start}–${v.end}',
                if (v.place.isNotEmpty) v.place,
              ].join('\n'),
              trailing: VisitStatusChip(visit: v),
            ),
        ],
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _activeOrderCard(BuildContext context, Quote q) {
    final paid = state.paidOf(q.id);
    final rem = state.remainingOf(q);
    final progress = q.total > 0 ? (paid / q.total).clamp(0.0, 1.0) : 0.0;
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
                      state.itemsSummary(q),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${q.folio} · ${displayDate(q.date)}',
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
          if (q.isOrder) ...[
            const SizedBox(height: 16),
            OrderProgress(quote: q),
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
      leading: StatusBadge.dot(q.status),
      title: state.itemsSummary(q),
      subtitle: '${q.folio} · ${q.status.label}',
      trailing: MoneyText(AppState.formatMXN(q.total)),
    );
  }
}
