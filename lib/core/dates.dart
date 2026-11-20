/// Fechas de la app en un solo lugar: leerlas, mostrarlas y los nombres de
/// meses y días en español.
library;

const monthNames = [
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
const monthAbbr = [
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
const weekdayNames = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const weekdayAbbr = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

String _two(int n) => n.toString().padLeft(2, '0');

/// Acepta fechas 'dd/MM/yyyy' (también d/M/yyyy) o ISO 'yyyy-MM-dd...'.
DateTime? parseAppDate(String date) {
  final text = date.trim();
  final dmy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text);
  if (dmy != null) {
    return DateTime(
      int.parse(dmy.group(3)!),
      int.parse(dmy.group(2)!),
      int.parse(dmy.group(1)!),
    );
  }
  return DateTime.tryParse(text);
}

/// "19/11/2026".
String dmyDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// "2026-11-19".
String isoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// "19/11/2026 · 14:05".
String dmyDateTime(DateTime d) =>
    '${dmyDate(d)} · ${_two(d.hour)}:${_two(d.minute)}';

/// Cualquier fecha guardada (dd/mm/aaaa o ISO) mostrada como dd/mm/aaaa; si
/// no se entiende, se deja como vino.
String displayDate(String date) {
  final d = parseAppDate(date);
  if (d == null) return date;
  return dmyDate(d.isUtc ? d.toLocal() : d);
}

/// "noviembre" → "Noviembre".
String capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
