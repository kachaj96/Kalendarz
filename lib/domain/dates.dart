/// Pomocnicze funkcje na samych datach (bez godzin). Operują na lokalnym czasie
/// i unikają dodawania Duration, żeby zmiana czasu nie przesuwała dni.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Liczba dni między dwiema datami (b - a), odporna na zmianę czasu.
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Poniedziałek tygodnia, w którym leży data.
DateTime mondayOf(DateTime d) => addDays(dateOnly(d), -(d.weekday - 1));

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String formatMinutes(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Numer tygodnia wg ISO 8601 (tydzień zaczyna się w poniedziałek, pierwszy zawiera 4 stycznia).
int isoWeekNumber(DateTime d) {
  final date = dateOnly(d);
  final thursday = addDays(date, 4 - date.weekday);
  final firstThursday = DateTime(thursday.year, 1, 4);
  final week1Thursday = addDays(firstThursday, 4 - firstThursday.weekday);
  return 1 + daysBetween(week1Thursday, thursday) ~/ 7;
}
