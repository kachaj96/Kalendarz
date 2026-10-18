import 'package:intl/intl.dart';

import '../domain/dates.dart';
import '../domain/entry.dart';

const weekdayShort = ['pon', 'wt', 'śr', 'czw', 'pt', 'sob', 'nd'];
const weekdayLetter = ['P', 'W', 'Ś', 'C', 'P', 'S', 'N'];

final _dayMonth = DateFormat('d MMMM', 'pl');
final _weekdayLong = DateFormat('EEEE', 'pl');
final _monthYear = DateFormat('LLLL y', 'pl');
final _monthOnly = DateFormat('LLLL', 'pl');
final _shortMonth = DateFormat('MMM', 'pl');

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "20 października"
String dayMonth(DateTime d) => _dayMonth.format(d);

/// "wtorek"
String weekdayName(DateTime d) => _weekdayLong.format(d);

/// "Wtorek, 20 października"
String fullDate(DateTime d) => '${capitalize(weekdayName(d))}, ${dayMonth(d)}';

/// "Październik 2026"
String monthYear(DateTime d) => capitalize(_monthYear.format(d));

String monthName(DateTime d) => capitalize(_monthOnly.format(d));

/// "pon 19 paź"
String shortDate(DateTime d) =>
    '${weekdayShort[d.weekday - 1]} ${d.day} ${_shortMonth.format(d).replaceAll('.', '')}';

String timeRange(int startMinutes, int endMinutes) =>
    '${formatMinutes(startMinutes)} - ${formatMinutes(endMinutes)}';

const reminderPresets = <(int, String, String)>[
  (0, 'W chwili', 'W chwili rozpoczęcia'),
  (10, '10 min', '10 min wcześniej'),
  (30, '30 min', '30 min wcześniej'),
  (60, '1 godz.', '1 godz. wcześniej'),
  (1440, '1 dzień', '1 dzień wcześniej'),
];

String reminderLabel(int minutes) {
  for (final p in reminderPresets) {
    if (p.$1 == minutes) return p.$3;
  }
  return '$minutes min wcześniej';
}

/// Opis powtarzania, np. "Co tydzień: wt, czw" albo "Co 2 miesiące".
String repeatDescription(Entry e) {
  final r = e.recurrence;
  if (r == null) return 'Nie powtarza się';
  final n = r.interval;
  String every(String one, String few, String many) {
    if (n == 1) return one;
    final lastTwo = n % 100;
    final last = n % 10;
    final word = (last >= 2 && last <= 4 && !(lastTwo >= 12 && lastTwo <= 14))
        ? few
        : many;
    return 'Co $n $word';
  }

  final base = switch (r.freq) {
    RepeatFreq.daily => every('Codziennie', 'dni', 'dni'),
    RepeatFreq.weekly => every('Co tydzień', 'tygodnie', 'tygodni'),
    RepeatFreq.monthly => every('Co miesiąc', 'miesiące', 'miesięcy'),
    RepeatFreq.yearly => every('Co rok', 'lata', 'lat'),
  };
  final days = r.freq == RepeatFreq.weekly && r.weekdays.isNotEmpty
      ? ': ${(r.weekdays.toList()..sort()).map((d) => weekdayShort[d - 1]).join(', ')}'
      : '';
  final end = r.until != null
      ? ', do ${dayMonth(r.until!)} ${r.until!.year}'
      : r.count != null
      ? ', ${r.count} razy'
      : '';
  return '$base$days$end';
}

/// Termin wpisu w jednej linii, np. "17:30 - 18:30" albo "Cały dzień".
String whenText(Entry e, DateTime day) {
  if (e.allDay || e.startMinutes == null) return 'Cały dzień';
  final start = formatMinutes(e.startMinutes!);
  final end = e.endMinutes == null ? null : formatMinutes(e.endMinutes!);
  return end == null ? start : '$start - $end';
}
