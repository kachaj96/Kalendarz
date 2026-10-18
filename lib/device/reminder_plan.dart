import '../domain/dates.dart';
import '../domain/entry.dart';
import '../domain/maps_links.dart';
import '../domain/occurrence.dart';

/// Godzina, o której przypominamy o wpisach bez godziny (cały dzień, zadanie bez pory).
const allDayReminderMinutes = 9 * 60;

/// Na ile dni do przodu planujemy alarmy. Resztę dołoży kolejne przeliczenie.
const reminderHorizonDays = 21;

/// Android ma limit alarmów na aplikację (ok. 500), zostawiamy duży zapas.
const maxScheduledReminders = 150;

class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.entryId,
    required this.occurrenceKey,
  });

  /// Stabilny identyfikator: ten sam wpis, wystąpienie i wyprzedzenie dają ten sam numer.
  final int id;
  final DateTime at;
  final String title;
  final String body;
  final String entryId;

  /// Data początku wystąpienia (klucz rrrr-mm-dd), żeby po dotknięciu otworzyć właściwy dzień.
  final String occurrenceKey;

  String get payload => '$entryId|$occurrenceKey';
}

/// 31-bitowy skrót FNV-1a, stabilny między uruchomieniami (w przeciwieństwie do String.hashCode).
int stableId(String s) {
  var h = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h & 0x7FFFFFFF;
}

DateTime _atMinutes(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

String _dayPhrase(DateTime day, DateTime now) {
  final diff = daysBetween(dateOnly(now), day);
  if (diff == 0) return 'Dziś';
  if (diff == 1) return 'Jutro';
  const names = [
    'poniedziałek',
    'wtorek',
    'środa',
    'czwartek',
    'piątek',
    'sobota',
    'niedziela',
  ];
  return '${names[day.weekday - 1][0].toUpperCase()}${names[day.weekday - 1].substring(1)}, ${day.day}.${day.month.toString().padLeft(2, '0')}';
}

/// Lista alarmów do ustawienia: od teraz do [reminderHorizonDays] dni, najbliższe najpierw.
/// Pomija zrobione zadania i chwile z przeszłości.
List<PlannedReminder> planReminders(Iterable<Entry> entries, DateTime now) {
  final from = dateOnly(now);
  // Przypomnienie "1 dzień wcześniej" dla wpisu tuż za horyzontem nadal mieści się w oknie.
  final to = addDays(from, reminderHorizonDays + 1);
  final out = <PlannedReminder>[];

  for (final e in entries) {
    if (e.reminders.isEmpty) continue;
    for (final occ in occurrencesInRange(e, from, to)) {
      if (e.isTask && occ.isDone) continue;
      final noTime = occ.hasNoTime;
      final start = _atMinutes(
        occ.startDate,
        noTime ? allDayReminderMinutes : e.startMinutes!,
      );
      final when = noTime
          ? 'cały dzień'
          : (e.endMinutes == null
                ? formatMinutes(e.startMinutes!)
                : '${formatMinutes(e.startMinutes!)} - ${formatMinutes(e.endMinutes!)}');
      final place = e.location.trim().isEmpty
          ? ''
          : ' · ${locationLabel(e.location)}';
      for (final offset in e.reminders.toSet()) {
        final at = start.subtract(Duration(minutes: offset));
        if (!at.isAfter(now)) continue;
        if (daysBetween(from, at) > reminderHorizonDays) continue;
        out.add(
          PlannedReminder(
            id: stableId('${e.id}|${occ.key}|$offset'),
            at: at,
            title: e.title,
            body: '${_dayPhrase(occ.startDate, at)}, $when$place',
            entryId: e.id,
            occurrenceKey: occ.key,
          ),
        );
      }
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out.length > maxScheduledReminders
      ? out.sublist(0, maxScheduledReminders)
      : out;
}
