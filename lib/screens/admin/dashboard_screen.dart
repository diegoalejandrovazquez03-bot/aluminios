import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/top_bar.dart';

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

  /// Acepta fechas 'dd/MM/yyyy' o 'yyyy-MM-dd'.
  static bool _isThisMonth(String date, DateTime now) {
    final dmy = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(date);
    if (dmy != null) {
      return int.parse(dmy.group(2)!) == now.month &&
          int.parse(dmy.group(3)!) == now.year;
    }
    final iso = DateTime.tryParse(date);
    return iso != null && iso.month == now.month && iso.year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    // Saldo por cobrar
    double totalBalance = 0;
    int quotesWithBalance = 0;
    for (final q in state.quotes) {
      if (q.status == QuoteStatus.cancelada ||
          q.status == QuoteStatus.pendiente) {
        continue;
      }
      final rem = q.total - state.paidOf(q.id);
      if (rem > 0) {
        totalBalance += rem;
        quotesWithBalance++;
      }
    }

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
        onAvatarTap: () => onNavigate(8), // Perfil
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Text(dateLabel, style: AppText.label()),
          const SizedBox(height: 2),
          Text(
            'Resumen',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textOnDark : AppColors.carbon,
            ),
          ),
          const SizedBox(height: 18),

          // Cifra principal en carbón
          InkWell(
            onTap: () => onNavigate(5), // Pagos
            borderRadius: BorderRadius.circular(kRadius),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.carbon,
                borderRadius: BorderRadius.circular(kRadius),
                border: isDark ? Border.all(color: AppColors.borderDark) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saldo por cobrar',
                    style: TextStyle(fontSize: 13, color: AppColors.aluminum),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppState.formatMXN(totalBalance),
                    style: AppText.mono(
                      fontSize: 30,
                      color: AppColors.textOnDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    quotesWithBalance == 1
                        ? 'En 1 cotización aprobada'
                        : 'En $quotesWithBalance cotizaciones aprobadas',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.aluminum,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.borderDark),
                      ),
                    ),
                    child: Row(
                      children: [
                        _monthFigure('Cotizado', quotedMonth, first: true),
                        _monthFigure('Aprobado', approvedMonth),
                        _monthFigure('Cobrado', collectedMonth),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          _sectionHeader('Hoy', 'Agenda', () => onNavigate(6), isDark),
          _listBox(
            isDark: isDark,
            children: todayVisits.isEmpty
                ? [_emptyRow('Sin visitas agendadas para hoy')]
                : [
                    for (final v in todayVisits)
                      _visitRow(v, isDark, () => onNavigate(6)),
                  ],
          ),
          const SizedBox(height: 24),

          _sectionHeader('Por atender', 'Ver todas', () {
            state.setQuoteFilter('Pendiente');
            onNavigate(3);
          }, isDark),
          _listBox(
            isDark: isDark,
            children: pendingQuotes.isEmpty
                ? [_emptyRow('No hay cotizaciones pendientes')]
                : [
                    for (final q in pendingQuotes.take(4))
                      _quoteRow(q, isDark, () {
                        state.setSelectedQuoteId(q.id);
                        onNavigate(9); // Detalle de la cotización
                      }),
                  ],
          ),
          const SizedBox(height: 24),

          _sectionHeader('Módulos', null, null, isDark),
          _listBox(
            isDark: isDark,
            children: [
              _moduleRow(
                Icons.payments_outlined,
                'Anticipos y pagos',
                () => onNavigate(5),
                isDark,
              ),
              _moduleRow(
                Icons.calendar_today_outlined,
                'Agenda de visitas',
                () => onNavigate(6),
                isDark,
              ),
              _moduleRow(
                Icons.photo_library_outlined,
                'Catálogo de trabajos',
                () => onNavigate(7),
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthFigure(String label, double value, {bool first = false}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.only(left: first ? 0 : 12),
        decoration: first
            ? null
            : const BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.borderDark)),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.aluminum),
            ),
            const SizedBox(height: 2),
            Text(
              AppState.formatMXN(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.mono(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textOnDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
    String title,
    String? action,
    VoidCallback? onAction,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textOnDark : AppColors.carbon,
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: isDark
                    ? const Color(0xFF7FA6CC)
                    : AppColors.accent,
                minimumSize: const Size(44, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(action, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _listBox({required bool isDark, required List<Widget> children}) {
    final divider = isDark ? AppColors.borderDark : AppColors.divider;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: divider),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _emptyRow(String text) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _visitRow(Visit v, bool isDark, VoidCallback onTap) {
    final client = state.clients.where((c) => c.id == v.clientId).firstOrNull;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Text(
                v.start,
                style: AppText.mono(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${v.type} · ${client?.name ?? 'Cliente'}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textOnDark : AppColors.carbon,
                    ),
                  ),
                  if (v.place.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      v.place,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quoteRow(Quote q, bool isDark, VoidCallback onTap) {
    final client = state.clients.where((c) => c.id == q.clientId).firstOrNull;
    return InkWell(
      onTap: onTap,
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
                    client?.name ?? 'Cliente',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textOnDark : AppColors.carbon,
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
                color: isDark ? AppColors.textOnDark : AppColors.carbon,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moduleRow(
    IconData icon,
    String title,
    VoidCallback onTap,
    bool isDark,
  ) {
    final fg = isDark ? AppColors.textOnDark : AppColors.carbon;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
