import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/constants.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/sheet_message.dart';
import '../../widgets/top_bar.dart';

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

  String _formatIso(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  void _openNewVisitModal() {
    int? clientId = widget.state.clients.firstOrNull?.id;
    String type = 'Toma de medidas';
    final startCtrl = TextEditingController(text: '09:00');
    final endCtrl = TextEditingController(text: '10:30');
    final placeCtrl = TextEditingController(text: 'Mérida');
    DateTime date = _selectedDay;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Agendar Visita',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedIso = _formatIso(_selectedDay);
    final dayVisits = state.visits.where((v) => v.date == selectedIso).toList();

    return Scaffold(
      appBar: TopBar(
        title: 'Agenda de Visitas',
        showLogo: true,
        onAvatarTap: () => widget.onNavigate(8),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Monthly Calendar Card
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.hairline),
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2025, 1, 1),
              lastDay: DateTime.utc(2028, 12, 31),
              focusedDay: _focusedDay,
              currentDay: DateTime.now(),
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
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

          // Day's agenda
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'VISITAS DEL DÍA (${_selectedDay.day}/${_selectedDay.month})',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Text(
                '${dayVisits.length} agendada(s)',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (dayVisits.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Text(
                'Sin visitas agendadas para este día',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            )
          else
            for (final v in dayVisits) ...[
              Builder(
                builder: (ctx) {
                  final client = state.clients
                      .where((c) => c.id == v.clientId)
                      .firstOrNull;

                  Color dotColor = AppColors.accent;
                  if (v.type == 'Instalación') {
                    dotColor = AppColors.done;
                  } else if (v.type == 'Toma de medidas') {
                    dotColor = AppColors.pending;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${v.start} - ${v.end}',
                                style: TextStyle(
                                  fontSize: 11,
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
                                  color: isDark ? Colors.white : AppColors.navy,
                                ),
                              ),
                              Text(
                                '${client?.name ?? 'Cliente'} • ${v.place}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.black38,
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
                },
              ),
            ],
          const SizedBox(height: 12),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'Nueva visita en esta fecha',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: _openNewVisitModal,
          ),
        ],
      ),
    );
  }
}
