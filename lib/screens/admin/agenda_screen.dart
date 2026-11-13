import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/constants.dart';
import '../../core/app_routes.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/sheet_message.dart';
import '../../widgets/server_refresh.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/ui.dart';
import '../../widgets/visit_status_chip.dart';

class AgendaScreen extends StatefulWidget {
  final AppState state;
  final Function(int) onNavigate;

  const AgendaScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _showPast = false; // Historial: false = próximas, true = realizadas

  static const _weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static const _monthNames = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime get _today => _dateOnly(DateTime.now());

  static String _longDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  static int? _minutes(String hhmm) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return h * 60 + min;
  }

  String _formatIso(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  void _openNewVisitModal() {
    int? clientId = widget.state.clients.firstOrNull?.id;
    String type = 'Toma de medidas';
    final startCtrl = TextEditingController(text: '09:00');
    final endCtrl = TextEditingController(text: '10:30');
    final placeCtrl = TextEditingController(text: 'Mérida');
    // No se agenda en el pasado: si el día seleccionado ya pasó, se propone hoy.
    DateTime date = _dateOnly(_selectedDay).isBefore(_today)
        ? _today
        : _dateOnly(_selectedDay);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHeader('Agendar visita'),
                  const SizedBox(height: 6),

                  // Fecha: el selector no permite días anteriores a hoy.
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text('Fecha: ${_longDate(_formatIso(date))}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: _today,
                        lastDate: DateTime(_today.year + 2, 12, 31),
                        helpText: 'Fecha de la visita',
                        cancelText: 'Cancelar',
                        confirmText: 'Aceptar',
                      );
                      if (picked != null) {
                        setModalState(() => date = _dateOnly(picked));
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    initialValue: clientId,
                    decoration: const InputDecoration(labelText: 'Cliente'),
                    items: widget.state.clients.map((c) {
                      return DropdownMenuItem(value: c.id, child: Text(c.name));
                    }).toList(),
                    onChanged: (val) => setModalState(() => clientId = val),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de visita',
                    ),
                    items: ['Toma de medidas', 'Instalación', 'Cotización'].map(
                      (t) {
                        return DropdownMenuItem(value: t, child: Text(t));
                      },
                    ).toList(),
                    onChanged: (val) =>
                        setModalState(() => type = val ?? 'Toma de medidas'),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Hora inicio',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: endCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Hora fin',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: placeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lugar / Dirección',
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      if (clientId == null) {
                        showSheetMessage(ctx, 'Selecciona un cliente');
                        return;
                      }
                      if (date.isBefore(_today)) {
                        showSheetMessage(
                          ctx,
                          'No se pueden agendar visitas en fechas pasadas',
                        );
                        return;
                      }
                      final start = _minutes(startCtrl.text);
                      final end = _minutes(endCtrl.text);
                      if (start == null || end == null) {
                        showSheetMessage(
                          ctx,
                          'Escribe las horas en formato 24 h, por ejemplo 09:00',
                        );
                        return;
                      }
                      if (end <= start) {
                        showSheetMessage(
                          ctx,
                          'La hora de fin debe ser después de la de inicio',
                        );
                        return;
                      }
                      final v = Visit(
                        id: DateTime.now().millisecondsSinceEpoch,
                        date: _formatIso(date),
                        start: startCtrl.text.trim(),
                        end: endCtrl.text.trim(),
                        type: type,
                        clientId: clientId!,
                        place: placeCtrl.text.trim(),
                      );
                      widget.state.addVisit(v);
                      setState(() {
                        _selectedDay = date;
                        _focusedDay = date;
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Visita agendada')),
                      );
                    },
                    child: const Text('Confirmar Visita'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final selectedIso = _formatIso(_selectedDay);
    final dayVisits = state.visits.where((v) => v.date == selectedIso).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    // Historial ordenado: próximas de la más cercana a la más lejana;
    // realizadas de la más reciente a la más antigua.
    final upcoming = state.visits.where((v) => !v.isDone).toList()
      ..sort(
        (a, b) => '${a.date} ${a.start}'.compareTo('${b.date} ${b.start}'),
      );
    final done = state.visits.where((v) => v.isDone).toList()
      ..sort(
        (a, b) => '${b.date} ${b.start}'.compareTo('${a.date} ${a.start}'),
      );
    final upcomingCount = upcoming.length;
    final doneCount = done.length;
    final history = _showPast ? done : upcoming;

    return Scaffold(
      appBar: TopBar(
        title: 'Agenda de visitas',
        showLogo: true,
        onAvatarTap: () => widget.onNavigate(AdminScreen.perfil),
      ),
      body: RefreshIndicator(
        // Deslizar hacia abajo trae del servidor las solicitudes nuevas.
        onRefresh: () => refreshFromServer(context, widget.state),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Monthly Calendar Card
            AppCard(
              padding: EdgeInsets.zero,
              child: TableCalendar(
                firstDay: DateTime.utc(2025, 1, 1),
                lastDay: DateTime.utc(2028, 12, 31),
                focusedDay: _focusedDay,
                currentDay: DateTime.now(),
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: CalendarFormat.month,
                // Solo deslizar a los lados (cambiar de mes); hacia arriba o abajo
                // desplaza la pantalla.
                availableGestures: AvailableGestures.horizontalSwipe,
                // En español sin depender del idioma del teléfono.
                startingDayOfWeek: StartingDayOfWeek.monday,
                daysOfWeekStyle: DaysOfWeekStyle(
                  dowTextFormatter: (date, locale) =>
                      _weekdays[date.weekday - 1],
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextFormatter: (date, locale) =>
                      '${_monthNames[date.month - 1]} ${date.year}',
                  titleTextStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.navy,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: AppColors.navy,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                eventLoader: (day) {
                  final iso = _formatIso(day);
                  return state.visits.where((v) => v.date == iso).toList();
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return null;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: events.take(3).map((e) {
                        final v = e as Visit;
                        Color dotColor = AppColors.accent;
                        if (v.type == 'Instalación') dotColor = AppColors.done;
                        if (v.type == 'Toma de medidas') {
                          dotColor = AppColors.pending;
                        }
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dotColor,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),

            SectionHeader(
              'Visitas del ${_longDate(selectedIso)} · ${dayVisits.length}',
            ),
            if (dayVisits.isEmpty)
              const EmptyState(
                icon: Icons.event_available_outlined,
                title: 'Sin visitas agendadas para este día',
              )
            else
              for (final v in dayVisits) _visitCard(v),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.add),
              label: Text(
                _dateOnly(_selectedDay).isBefore(_today)
                    ? 'Agendar nueva visita'
                    : 'Nueva visita en esta fecha',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: _openNewVisitModal,
            ),
            const SizedBox(height: 28),

            // Historial: próximas (de hoy en adelante) y realizadas (ya pasaron).
            const SectionHeader('Historial de visitas'),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text('Próximas ($upcomingCount)'),
                  icon: const Icon(Icons.schedule, size: 18),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Realizadas ($doneCount)'),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                ),
              ],
              selected: {_showPast},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _showPast = s.first),
            ),
            const SizedBox(height: 12),
            if (history.isEmpty)
              EmptyState(
                icon: _showPast ? Icons.history : Icons.schedule,
                title: _showPast
                    ? 'Aún no hay visitas realizadas'
                    : 'No hay visitas próximas agendadas',
              )
            else
              for (final v in history) _visitCard(v, showDate: true),
          ],
        ),
      ),
    );
  }

  /// Tarjeta de una visita. Con [showDate] muestra la fecha completa (historial).
  Widget _visitCard(Visit v, {bool showDate = false}) {
    final state = widget.state;
    final client = state.clients.where((c) => c.id == v.clientId).firstOrNull;
    final done = v.isDone;

    Color typeColor = AppColors.accent;
    if (v.type == 'Instalación') {
      typeColor = AppColors.done;
    } else if (v.type == 'Toma de medidas') {
      typeColor = AppColors.pending;
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showDate
                      ? '${_longDate(v.date)} · ${v.start} – ${v.end}'
                      : '${v.start} – ${v.end}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  v.type,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  '${client?.name ?? 'Cliente'} • ${v.place}',
                  style: TextStyle(fontSize: 12, color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                // Estado claramente diferenciado: por confirmar, confirmada o realizada.
                Row(
                  children: [
                    VisitStatusChip(visit: v),
                    if (v.isRequested) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () {
                          state.confirmVisit(v.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Visita confirmada')),
                          );
                        },
                        child: const Text('Confirmar'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!done)
            IconButton(
              tooltip: 'Eliminar visita',
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.textMuted,
              ),
              onPressed: () {
                state.deleteVisit(v.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Visita eliminada')),
                );
              },
            ),
        ],
      ),
    );
  }
}
