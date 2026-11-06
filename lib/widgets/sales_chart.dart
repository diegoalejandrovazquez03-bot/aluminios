import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';

/// Totales de un mes: lo aprobado (cotizaciones que ya no están pendientes
/// ni canceladas, por su fecha) y lo cobrado (pagos registrados ese mes).
class MonthSales {
  final int year;
  final int month;
  final double approved;
  final double collected;

  const MonthSales(this.year, this.month, this.approved, this.collected);
}

/// Acepta fechas 'dd/MM/yyyy' o 'yyyy-MM-dd'.
DateTime? parseAppDate(String date) {
  final dmy = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(date);
  if (dmy != null) {
    return DateTime(
      int.parse(dmy.group(3)!),
      int.parse(dmy.group(2)!),
      int.parse(dmy.group(1)!),
    );
  }
  return DateTime.tryParse(date);
}

/// Los últimos [months] meses (el actual al final) con sus totales.
List<MonthSales> monthlySales(
  List<Quote> quotes,
  List<Payment> payments,
  DateTime now, {
  int months = 6,
}) {
  final result = <MonthSales>[];
  for (int i = months - 1; i >= 0; i--) {
    final first = DateTime(now.year, now.month - i);
    bool inMonth(String date) {
      final d = parseAppDate(date);
      return d != null && d.year == first.year && d.month == first.month;
    }

    final approved = quotes
        .where(
          (q) =>
              q.status != QuoteStatus.pendiente &&
              q.status != QuoteStatus.cancelada &&
              inMonth(q.date),
        )
        .fold<double>(0, (a, q) => a + q.total);
    final collected = payments
        .where((p) => inMonth(p.date))
        .fold<double>(0, (a, p) => a + p.amount);
    result.add(MonthSales(first.year, first.month, approved, collected));
  }
  return result;
}

/// Gráfica de barras de Inicio: aprobado contra cobrado por mes.
class SalesChart extends StatelessWidget {
  final List<MonthSales> data;

  const SalesChart({super.key, required this.data});

  static const _monthShort = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  /// $12,500 → "12.5k" para que quepa en el eje.
  static String _compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) {
      final k = value / 1000;
      return '${k >= 10 ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final approvedColor = isDark ? AppColors.aluminum : AppColors.carbon;
    final collectedColor = isDark ? AppColors.accentDark : AppColors.accent;
    final gridColor = isDark ? AppColors.borderDark : AppColors.dividerLight;

    final peak = data.fold<double>(
      0,
      (a, m) => math.max(a, math.max(m.approved, m.collected)),
    );
    final hasData = peak > 0;
    // Tope redondo con aire arriba de la barra más alta.
    final maxY = hasData ? peak * 1.15 : 1000.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 14, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Wrap(
              spacing: 16,
              children: [
                _legend('Aprobado', approvedColor),
                _legend('Cobrado', collectedColor),
              ],
            ),
          ),
          SizedBox(
            height: 170,
            child: Stack(
              children: [
                BarChart(
                  BarChartData(
                    maxY: maxY,
                    alignment: BarChartAlignment.spaceAround,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 4,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: gridColor, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: hasData,
                          reservedSize: 36,
                          interval: maxY / 4,
                          getTitlesWidget: (value, meta) {
                            // Sin la etiqueta del tope: no es un valor redondo.
                            if (value == meta.max) return const SizedBox();
                            return Text(
                              _compact(value),
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= data.length) {
                              return const SizedBox();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _monthShort[data[i].month - 1],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      enabled: hasData,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => AppColors.carbon,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final m = data[group.x];
                          return BarTooltipItem(
                            '${_monthShort[m.month - 1]} ${m.year}\n',
                            const TextStyle(
                              color: AppColors.aluminum,
                              fontSize: 11,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    '${rodIndex == 0 ? 'Aprobado' : 'Cobrado'}: '
                                    '${AppState.formatMXN(rod.toY)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    barGroups: [
                      for (int i = 0; i < data.length; i++)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 3,
                          barRods: [
                            _rod(data[i].approved, approvedColor),
                            _rod(data[i].collected, collectedColor),
                          ],
                        ),
                    ],
                  ),
                ),
                if (!hasData)
                  Center(
                    child: Text(
                      'Aún no hay ventas en los últimos meses',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BarChartRodData _rod(double value, Color color) => BarChartRodData(
    toY: value,
    color: color,
    width: 10,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
  );

  Widget _legend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
    ],
  );
}
