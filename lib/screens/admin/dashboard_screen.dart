import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/app_routes.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/sales_chart.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/server_refresh.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/ui.dart';

class DashboardScreen extends StatelessWidget {
  final AppState state;
  final Function(int) onNavigate;

  const DashboardScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  static const _weekdays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static bool _isThisMonth(String date, DateTime now) {
    final d = parseAppDate(date);
    return d != null && d.month == now.month && d.year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final (amount: totalBalance, quotes: quotesWithBalance) = state.balanceDue;

    // Cifras del mes
    final monthQuotes = state.quotes
        .where(
          (q) => q.status != QuoteStatus.cancelada && _isThisMonth(q.date, now),
        )
        .toList();
    final quotedMonth = monthQuotes.fold<double>(0, (a, q) => a + q.total);
    final approvedMonth = monthQuotes
        .where((q) => q.status != QuoteStatus.pendiente)
        .fold<double>(0, (a, q) => a + q.total);
    final collectedMonth = state.payments
        .where((p) => _isThisMonth(p.date, now))
        .fold<double>(0, (a, p) => a + p.amount);

    final todayIso = AppState.todayIso();
    final todayVisits = state.visits.where((v) => v.date == todayIso).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final pendingQuotes = state.quotes
        .where((q) => q.status == QuoteStatus.pendiente)
        .toList();

    final dateLabel =
        '${_weekdays[now.weekday - 1]} ${now.day} de ${_months[now.month - 1]}'
            .toUpperCase();

    return Scaffold(
      appBar: TopBar(
        title: 'ALUMINIOS',
        showLogo: true,
        onAvatarTap: () => onNavigate(AdminScreen.perfil), // Perfil

      ),
      body: RefreshIndicator(
        // Deslizar hacia abajo trae del servidor solicitudes y cambios nuevos.
        onRefresh: () => refreshFromServer(context, state),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Text(dateLabel, style: AppText.label(color: AppColors.textMuted)),
            const SizedBox(height: 2),
            Text(
              'Resumen',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 18),

            // Lo que más se hace en el día, a un toque.
            Row(
              children: [
                _quickAction(
                  Icons.note_add_outlined,
                  'Nueva cotización',
                  () => onNavigate(AdminScreen.nuevaCotizacion),
                ),
                const SizedBox(width: 8),
                _quickAction(
                  Icons.payments_outlined,
                  'Registrar pago',
                  () => onNavigate(AdminScreen.pagos),
                ),
                const SizedBox(width: 8),
                _quickAction(
                  Icons.event_outlined,
                  todayVisits.isEmpty
                      ? 'Visitas de hoy'
                      : 'Visitas de hoy · ${todayVisits.length}',
                  () => onNavigate(AdminScreen.agenda),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (state.newRequestCount > 0) ...[
              AppCard(
                onTap: () => onNavigate(AdminScreen.solicitudes),
                child: Row(
                  children: [
                    IconBadge(Icons.inbox_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.newRequestCount == 1
                                ? '1 solicitud nueva'
                                : '${state.newRequestCount} solicitudes nuevas',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                          Text(
                            'Clientes que piden cotización',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            MetricPanel(
              label: 'Saldo por cobrar',
              value: AppState.formatMXN(totalBalance),
              caption: quotesWithBalance == 1
                  ? 'En 1 cotización aprobada'
                  : 'En $quotesWithBalance cotizaciones aprobadas',
              // Las tres cifras son solo del mes en curso.
              figuresLabel: 'Este mes · ${_months[now.month - 1]}',
              figures: [
                ('Cotizado', AppState.formatMXN(quotedMonth)),
                ('Aprobado', AppState.formatMXN(approvedMonth)),
                ('Cobrado', AppState.formatMXN(collectedMonth)),
              ],
              onTap: () => onNavigate(AdminScreen.pagos),
            ),
            const SizedBox(height: 24),

            SectionHeader(
              'Ventas · últimos 6 meses',
              action: 'Pagos',
              onAction: () => onNavigate(AdminScreen.pagos),
            ),
            SalesChart(data: monthlySales(state.quotes, state.payments, now)),
            const SizedBox(height: 24),

            SectionHeader(
              'Hoy',
              action: 'Agenda',
              onAction: () => onNavigate(AdminScreen.agenda),
            ),
            ListBox(
              children: todayVisits.isEmpty
                  ? [_emptyRow('Sin visitas agendadas para hoy')]
                  : [for (final v in todayVisits) _visitRow(v)],
            ),
            const SizedBox(height: 24),

            SectionHeader(
              'Por atender',
              action: 'Ver todas',
              onAction: () {
                state.setQuoteFilter('Pendiente');
                onNavigate(AdminScreen.cotizaciones);
              },
            ),
            ListBox(
              children: pendingQuotes.isEmpty
                  ? [_emptyRow('No hay cotizaciones pendientes')]
                  : [for (final q in pendingQuotes.take(4)) _quoteRow(q)],
            ),
            const SizedBox(height: 24),

            const SectionHeader('Módulos'),
            ListBox(
              children: [
                _moduleRow(
                  Icons.payments_outlined,
                  'Anticipos y pagos',
                  () => onNavigate(AdminScreen.pagos),
                ),
                _moduleRow(
                  Icons.calendar_today_outlined,
                  'Agenda de visitas',
                  () => onNavigate(AdminScreen.agenda),
                ),
                _moduleRow(
                  Icons.photo_library_outlined,
                  'Catálogo de trabajos',
                  () => onNavigate(AdminScreen.catalogo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, size: 22, color: AppColors.navy),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(fontSize: 12, color: AppColors.navy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyRow(String text) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visitRow(Visit v) {
    final client = state.clients.where((c) => c.id == v.clientId).firstOrNull;
    return BoxRow(
      leading: SizedBox(
        width: 44,
        child: Text(
          v.start,
          style: AppText.mono(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
        ),
      ),
      title: '${v.type} · ${client?.name ?? 'Cliente'}',
      subtitle: v.place,
      onTap: () => onNavigate(AdminScreen.agenda),
    );
  }

  Widget _quoteRow(Quote q) {
    final client = state.clients.where((c) => c.id == q.clientId).firstOrNull;
    return BoxRow(
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: StatusBadge.dotColor(q.status),
          shape: BoxShape.circle,
        ),
      ),
      title: client?.name ?? 'Cliente',
      subtitle: '${q.folio} · ${q.status.label}',
      trailing: MoneyText(AppState.formatMXN(q.total)),
      onTap: () {
        state.setSelectedQuoteId(q.id);
        onNavigate(AdminScreen.detalleCotizacion);
      },
    );
  }

  Widget _moduleRow(IconData icon, String title, VoidCallback onTap) {
    return BoxRow(
      leading: Icon(icon, size: 20, color: AppColors.navy),
      title: title,
      trailing: Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
