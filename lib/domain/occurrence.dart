import 'dates.dart';
import 'entry.dart';

/// Jedno konkretne wystąpienie wpisu (dla wpisu bez powtarzania jest dokładnie jedno).
class Occurrence {
  const Occurrence(this.entry, this.startDate, this.endDate);

  final Entry entry;
  final DateTime startDate;
  final DateTime endDate;

  /// Klucz, pod którym wpis trzyma odhaczenia i pominięcia tego wystąpienia.
  String get key => dateKey(startDate);

  bool get isDone => entry.doneDates.contains(key);
  Set<String> get checkedItems => entry.checks[key] ?? const {};

  int get checklistDone =>
      entry.checklist.where((i) => checkedItems.contains(i.id)).length;

  bool coversDay(DateTime day) {
    final d = dateOnly(day);
    return !d.isBefore(startDate) && !d.isAfter(endDate);
  }

  /// Wpis bez godzin: cały dzień albo zadanie bez pory.
  bool get hasNoTime => entry.allDay || entry.startMinutes == null;

  /// Początek w minutach od północy dla danego dnia (0, gdy wpis trwa od wcześniejszego dnia).
  int startMinutesOn(DateTime day) =>
      sameDay(day, startDate) ? (entry.startMinutes ?? 0) : 0;

  /// Koniec w minutach od północy dla danego dnia (1440, gdy wpis trwa do następnego dnia).
  int endMinutesOn(DateTime day) =>
      sameDay(day, endDate) ? (entry.endMinutes ?? 1440) : 1440;
}

const _maxIterations = 100000;

/// Daty początków kolejnych wystąpień, od pierwszej, w rosnącej kolejności.
/// Strumień kończy się przy końcu reguły (do daty albo po N wystąpieniach).
/// Uwaga: pominięte dni też liczą się do limitu wystąpień.
Iterable<DateTime> recurrenceStarts(Entry e) sync* {
  final r = e.recurrence;
  final first = e.date;
  if (r == null) {
    yield first;
    return;
  }
  final step = r.interval < 1 ? 1 : r.interval;
  var emitted = 0;

  bool finished(DateTime d) =>
      (r.until != null && d.isAfter(r.until!)) ||
      (r.count != null && emitted >= r.count!);

  switch (r.freq) {
    case RepeatFreq.daily:
      for (var k = 0; k < _maxIterations; k++) {
        final d = addDays(first, k * step);
        if (finished(d)) return;
        emitted++;
        yield d;
      }
    case RepeatFreq.weekly:
      final days = (r.weekdays.isEmpty ? {first.weekday} : r.weekdays).toList()
        ..sort();
      final week0 = mondayOf(first);
      for (var k = 0; k < _maxIterations; k++) {
        final weekStart = addDays(week0, 7 * k * step);
        if (r.until != null && weekStart.isAfter(r.until!)) return;
        for (final wd in days) {
          final d = addDays(weekStart, wd - 1);
          if (d.isBefore(first)) continue;
          if (finished(d)) return;
          emitted++;
          yield d;
        }
      }
    case RepeatFreq.monthly:
      for (var k = 0; k < _maxIterations; k++) {
        final monthIndex = first.month - 1 + k * step;
        final y = first.year + monthIndex ~/ 12;
        final m = monthIndex % 12 + 1;
        // 31. dnia w krótszych miesiącach wypada w ostatni dzień miesiąca.
        final d = DateTime(y, m, first.day.clamp(1, daysInMonth(y, m)));
        if (finished(d)) return;
        emitted++;
        yield d;
      }
    case RepeatFreq.yearly:
      for (var k = 0; k < _maxIterations; k++) {
        final y = first.year + k * step;
        final d = DateTime(
          y,
          first.month,
          first.day.clamp(1, daysInMonth(y, first.month)),
        );
        if (finished(d)) return;
        emitted++;
        yield d;
      }
  }
}

/// Wystąpienia wpisu zahaczające o dni od `from` do `to` włącznie, bez pominiętych.
List<Occurrence> occurrencesInRange(Entry e, DateTime from, DateTime to) {
  final lo = dateOnly(from);
  final hi = dateOnly(to);
  final span = e.spanDays;
  final out = <Occurrence>[];
  for (final start in recurrenceStarts(e)) {
    if (start.isAfter(hi)) break;
    final end = addDays(start, span);
    if (end.isBefore(lo)) continue;
    final occ = Occurrence(e, start, end);
    if (e.skipped.contains(occ.key)) continue;
    out.add(occ);
    if (!e.isRecurring) break;
  }
  return out;
}

int _compareForDay(Occurrence a, Occurrence b, DateTime day) {
  if (a.hasNoTime != b.hasNoTime) return a.hasNoTime ? -1 : 1;
  final byStart = a.startMinutesOn(day).compareTo(b.startMinutesOn(day));
  if (byStart != 0) return byStart;
  return a.entry.title.toLowerCase().compareTo(b.entry.title.toLowerCase());
}

/// Wszystkie wystąpienia w danym dniu: najpierw całodniowe, potem wg godziny.
List<Occurrence> occurrencesOnDay(Iterable<Entry> entries, DateTime day) {
  final d = dateOnly(day);
  final out = [for (final e in entries) ...occurrencesInRange(e, d, d)];
  out.sort((a, b) => _compareForDay(a, b, d));
  return out;
}

/// Zadania bez powtarzania, których termin minął, a nie są odhaczone.
List<Occurrence> overdueOccurrences(Iterable<Entry> entries, DateTime today) {
  final t = dateOnly(today);
  final out = <Occurrence>[];
  for (final e in entries) {
    if (!e.isTask || e.isRecurring) continue;
    final occ = Occurrence(e, e.date, e.endDate);
    if (occ.endDate.isBefore(t) && !occ.isDone) out.add(occ);
  }
  out.sort((a, b) => a.startDate.compareTo(b.startDate));
  return out;
}

/// Wpis ułożony w pionowej osi godzin: `lane` z `lanes` to kolumna wśród wpisów nachodzących na siebie.
class PositionedOccurrence {
  PositionedOccurrence(this.occurrence, this.start, this.end);

  final Occurrence occurrence;
  final int start;
  final int end;
  int lane = 0;
  int lanes = 1;
}

/// Układ wpisów z godzinami w jednym dniu. Wpisy, które się nakładają, trafiają obok siebie.
List<PositionedOccurrence> layoutDay(
  List<Occurrence> occurrences,
  DateTime day,
) {
  final items = [
    for (final o in occurrences)
      if (!o.hasNoTime)
        PositionedOccurrence(
          o,
          o.startMinutesOn(day),
          // Wpis o zerowej długości dostaje minimum 15 minut, żeby dało się go dotknąć.
          o.endMinutesOn(day) <= o.startMinutesOn(day)
              ? o.startMinutesOn(day) + 15
              : o.endMinutesOn(day),
        ),
  ]..sort((a, b) => a.start != b.start ? a.start - b.start : b.end - a.end);

  var cluster = <PositionedOccurrence>[];
  var clusterEnd = -1;
  void flush() {
    if (cluster.isEmpty) return;
    final laneEnds = <int>[];
    for (final it in cluster) {
      var lane = laneEnds.indexWhere((end) => end <= it.start);
      if (lane == -1) {
        laneEnds.add(it.end);
        lane = laneEnds.length - 1;
      } else {
        laneEnds[lane] = it.end;
      }
      it.lane = lane;
    }
    for (final it in cluster) {
      it.lanes = laneEnds.length;
    }
    cluster = [];
  }

  for (final it in items) {
    if (cluster.isNotEmpty && it.start >= clusterEnd) flush();
    cluster.add(it);
    clusterEnd = cluster.length == 1
        ? it.end
        : (it.end > clusterEnd ? it.end : clusterEnd);
  }
  flush();
  return items;
}
