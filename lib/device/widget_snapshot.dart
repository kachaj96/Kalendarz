import 'dart:convert';

import '../domain/category.dart';
import '../domain/dates.dart';
import '../domain/entry.dart';
import '../domain/occurrence.dart';

/// Dni wstecz i w przód zapisywane dla widżetów. Widżet sam wybiera "dziś" z zegara telefonu,
/// więc dane wystarczą nawet wtedy, gdy aplikacja długo nie odświeżała ich w tle.
const snapshotDaysBack = 7;
const snapshotDaysAhead = 45;

/// Dane dla widżetów na ekranie głównym: płaska lista wystąpień po dniach, w JSON.
/// Klucze są krótkie, bo plik czyta kod Kotlina przy każdym rysowaniu widżetu.
String buildWidgetSnapshot(
  Iterable<Entry> entries,
  Map<String, Category> categories,
  DateTime now,
) {
  final today = dateOnly(now);
  final items = <Map<String, Object>>[];
  for (var i = -snapshotDaysBack; i <= snapshotDaysAhead; i++) {
    final day = addDays(today, i);
    for (final o in occurrencesOnDay(entries, day)) {
      final e = o.entry;
      items.add({
        'd': dateKey(day),
        's': o.hasNoTime ? -1 : o.startMinutesOn(day),
        'e': o.hasNoTime ? -1 : o.endMinutesOn(day),
        't': e.title,
        'c': categories[e.categoryId]?.color ?? 0xFF5F6B80,
        'l': e.isLocal,
        'k': e.isTask,
        'x': o.isDone,
      });
    }
  }
  return jsonEncode({
    'v': 1,
    'generated': now.toIso8601String(),
    'items': items,
  });
}
