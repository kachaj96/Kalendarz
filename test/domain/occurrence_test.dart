import 'package:flutter_test/flutter_test.dart';
import 'package:kalendarz/domain/dates.dart';
import 'package:kalendarz/domain/entry.dart';
import 'package:kalendarz/domain/occurrence.dart';

Entry entry({
  String id = 'e',
  EntryType type = EntryType.event,
  required DateTime date,
  DateTime? endDate,
  int? start,
  int? end,
  bool allDay = false,
  Recurrence? rec,
  Set<String> skipped = const {},
  Set<String> done = const {},
}) => Entry(
  id: id,
  type: type,
  title: 'T$id',
  date: date,
  endDate: endDate ?? date,
  categoryId: 'inne',
  allDay: allDay,
  startMinutes: start,
  endMinutes: end,
  recurrence: rec,
  skipped: skipped,
  doneDates: done,
);

List<String> starts(Entry e, DateTime from, DateTime to) =>
    occurrencesInRange(e, from, to).map((o) => o.key).toList();

void main() {
  group('bez powtarzania', () {
    test('jedno wystąpienie tylko w swoim dniu', () {
      final e = entry(date: DateTime(2026, 10, 20), start: 600, end: 660);
      expect(starts(e, DateTime(2026, 10, 20), DateTime(2026, 10, 20)), [
        '2026-10-20',
      ]);
      expect(
        starts(e, DateTime(2026, 10, 21), DateTime(2026, 10, 30)),
        isEmpty,
      );
      expect(starts(e, DateTime(2026, 10, 1), DateTime(2026, 10, 19)), isEmpty);
    });

    test('wpis kilkudniowy jest widoczny w każdym dniu zakresu', () {
      final e = entry(
        date: DateTime(2026, 10, 24),
        endDate: DateTime(2026, 10, 26),
        allDay: true,
      );
      for (final d in [24, 25, 26]) {
        expect(
          occurrencesOnDay([e], DateTime(2026, 10, d)),
          hasLength(1),
          reason: '$d',
        );
      }
      expect(occurrencesOnDay([e], DateTime(2026, 10, 27)), isEmpty);
      expect(occurrencesOnDay([e], DateTime(2026, 10, 23)), isEmpty);
    });
  });

  group('codziennie', () {
    final base = DateTime(2026, 10, 1);

    test('co dzień i co 3 dni', () {
      final daily = entry(
        date: base,
        rec: const Recurrence(freq: RepeatFreq.daily),
      );
      expect(starts(daily, DateTime(2026, 10, 3), DateTime(2026, 10, 5)), [
        '2026-10-03',
        '2026-10-04',
        '2026-10-05',
      ]);
      final every3 = entry(
        date: base,
        rec: const Recurrence(freq: RepeatFreq.daily, interval: 3),
      );
      expect(starts(every3, base, DateTime(2026, 10, 10)), [
        '2026-10-01',
        '2026-10-04',
        '2026-10-07',
        '2026-10-10',
      ]);
    });

    test('koniec po N razach i do daty', () {
      final count = entry(
        date: base,
        rec: const Recurrence(freq: RepeatFreq.daily, count: 3),
      );
      expect(starts(count, base, DateTime(2026, 12, 31)), [
        '2026-10-01',
        '2026-10-02',
        '2026-10-03',
      ]);
      final until = entry(
        date: base,
        rec: Recurrence(freq: RepeatFreq.daily, until: DateTime(2026, 10, 2)),
      );
      expect(starts(until, base, DateTime(2026, 12, 31)), [
        '2026-10-01',
        '2026-10-02',
      ]);
    });

    test('pominięty dzień znika, ale liczy się do limitu', () {
      final e = entry(
        date: base,
        rec: const Recurrence(freq: RepeatFreq.daily, count: 3),
        skipped: {'2026-10-02'},
      );
      expect(starts(e, base, DateTime(2026, 12, 31)), [
        '2026-10-01',
        '2026-10-03',
      ]);
    });
  });

  group('co tydzień', () {
    test('domyślnie w dzień tygodnia pierwszego wpisu', () {
      final e = entry(
        date: DateTime(2026, 10, 20), // wtorek
        rec: const Recurrence(freq: RepeatFreq.weekly),
      );
      expect(starts(e, DateTime(2026, 10, 20), DateTime(2026, 11, 10)), [
        '2026-10-20',
        '2026-10-27',
        '2026-11-03',
        '2026-11-10',
      ]);
    });

    test('wybrane dni tygodnia, bez dni sprzed pierwszego wpisu', () {
      final e = entry(
        date: DateTime(2026, 10, 22), // czwartek
        rec: const Recurrence(freq: RepeatFreq.weekly, weekdays: {2, 4}),
      );
      expect(starts(e, DateTime(2026, 10, 19), DateTime(2026, 11, 1)), [
        '2026-10-22',
        '2026-10-27',
        '2026-10-29',
      ]);
    });

    test('co 2 tygodnie', () {
      final e = entry(
        date: DateTime(2026, 10, 19), // poniedziałek
        rec: const Recurrence(
          freq: RepeatFreq.weekly,
          interval: 2,
          weekdays: {1},
        ),
      );
      expect(starts(e, DateTime(2026, 10, 19), DateTime(2026, 11, 16)), [
        '2026-10-19',
        '2026-11-02',
        '2026-11-16',
      ]);
    });

    test('limit wystąpień liczy też kilka dni w tygodniu', () {
      final e = entry(
        date: DateTime(2026, 10, 19),
        rec: const Recurrence(
          freq: RepeatFreq.weekly,
          weekdays: {1, 3, 5},
          count: 4,
        ),
      );
      expect(starts(e, DateTime(2026, 10, 1), DateTime(2026, 12, 31)), [
        '2026-10-19',
        '2026-10-21',
        '2026-10-23',
        '2026-10-26',
      ]);
    });
  });

  group('co miesiąc i co rok', () {
    test('31. dnia wypada w ostatni dzień krótszego miesiąca', () {
      final e = entry(
        date: DateTime(2026, 1, 31),
        rec: const Recurrence(freq: RepeatFreq.monthly),
      );
      expect(starts(e, DateTime(2026, 1, 1), DateTime(2026, 5, 31)), [
        '2026-01-31',
        '2026-02-28',
        '2026-03-31',
        '2026-04-30',
        '2026-05-31',
      ]);
    });

    test('co 3 miesiące przez granicę roku', () {
      final e = entry(
        date: DateTime(2026, 11, 15),
        rec: const Recurrence(freq: RepeatFreq.monthly, interval: 3),
      );
      expect(starts(e, DateTime(2026, 11, 1), DateTime(2027, 6, 30)), [
        '2026-11-15',
        '2027-02-15',
        '2027-05-15',
      ]);
    });

    test('29 lutego w latach nieprzestępnych wypada 28 lutego', () {
      final e = entry(
        date: DateTime(2024, 2, 29),
        rec: const Recurrence(freq: RepeatFreq.yearly),
      );
      expect(starts(e, DateTime(2024, 1, 1), DateTime(2028, 12, 31)), [
        '2024-02-29',
        '2025-02-28',
        '2026-02-28',
        '2027-02-28',
        '2028-02-29',
      ]);
    });
  });

  group('wpis kilkudniowy z powtarzaniem', () {
    test(
      'wystąpienie sprzed zakresu, które wchodzi w zakres, jest widoczne',
      () {
        final e = entry(
          date: DateTime(2026, 10, 2),
          endDate: DateTime(2026, 10, 4),
          allDay: true,
          rec: const Recurrence(freq: RepeatFreq.weekly),
        );
        // Wystąpienie 9-11 paź ma być widoczne 10 paź, mimo że zaczęło się 9.
        final occ = occurrencesOnDay([e], DateTime(2026, 10, 10));
        expect(occ.map((o) => o.key), ['2026-10-09']);
      },
    );
  });

  group('układ dnia', () {
    Occurrence occ(String id, int s, int e) => Occurrence(
      entry(id: id, date: DateTime(2026, 10, 20), start: s, end: e),
      DateTime(2026, 10, 20),
      DateTime(2026, 10, 20),
    );

    test('rozłączne wpisy zajmują całą szerokość', () {
      final l = layoutDay([
        occ('a', 60, 120),
        occ('b', 120, 180),
      ], DateTime(2026, 10, 20));
      expect(l.map((p) => (p.lane, p.lanes)), [(0, 1), (0, 1)]);
    });

    test('nakładające się trafiają do osobnych kolumn', () {
      final l = layoutDay([
        occ('a', 60, 180),
        occ('b', 90, 120),
        occ('c', 200, 230),
      ], DateTime(2026, 10, 20));
      expect(l[0].lanes, 2);
      expect(l[1].lanes, 2);
      expect({l[0].lane, l[1].lane}, {0, 1});
      expect((l[2].lane, l[2].lanes), (0, 1));
    });

    test('wpis całodniowy nie wchodzi do osi godzin', () {
      final all = Occurrence(
        entry(id: 'z', date: DateTime(2026, 10, 20), allDay: true),
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 20),
      );
      expect(layoutDay([all], DateTime(2026, 10, 20)), isEmpty);
    });
  });

  group('kolejność w dniu i zaległe', () {
    test('całodniowe pierwsze, potem według godziny', () {
      final day = DateTime(2026, 10, 20);
      final list = occurrencesOnDay([
        entry(id: 'late', date: day, start: 900, end: 960),
        entry(id: 'all', date: day, allDay: true),
        entry(id: 'early', date: day, start: 420, end: 480),
      ], day);
      expect(list.map((o) => o.entry.id), ['all', 'early', 'late']);
    });

    test(
      'zaległe to tylko nieodhaczone zadania bez powtarzania po terminie',
      () {
        final today = DateTime(2026, 10, 20);
        final overdueTask = entry(
          id: '1',
          type: EntryType.task,
          date: DateTime(2026, 10, 19),
          allDay: true,
        );
        final doneTask = entry(
          id: '2',
          type: EntryType.task,
          date: DateTime(2026, 10, 18),
          allDay: true,
          done: {'2026-10-18'},
        );
        final event = entry(
          id: '3',
          date: DateTime(2026, 10, 18),
          allDay: true,
        );
        final todayTask = entry(
          id: '4',
          type: EntryType.task,
          date: today,
          allDay: true,
        );
        final recurring = entry(
          id: '5',
          type: EntryType.task,
          date: DateTime(2026, 10, 1),
          allDay: true,
          rec: const Recurrence(freq: RepeatFreq.daily),
        );
        final r = overdueOccurrences([
          overdueTask,
          doneTask,
          event,
          todayTask,
          recurring,
        ], today);
        expect(r.map((o) => o.entry.id), ['1']);
      },
    );
  });

  group('daty', () {
    test('daysBetween jest odporne na zmianę czasu', () {
      expect(daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
      expect(daysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
    });

    test('mondayOf', () {
      expect(
        mondayOf(DateTime(2026, 10, 18)),
        DateTime(2026, 10, 12),
      ); // niedziela
      expect(
        mondayOf(DateTime(2026, 10, 20)),
        DateTime(2026, 10, 19),
      ); // wtorek
    });
  });

  group('JSON', () {
    test('wpis przechodzi pełny obieg', () {
      final e = Entry(
        id: 'x',
        type: EntryType.task,
        title: 'Zakupy',
        description: 'opis',
        date: DateTime(2026, 10, 20),
        endDate: DateTime(2026, 10, 21),
        categoryId: 'zakupy',
        startMinutes: 1050,
        endMinutes: 1110,
        recurrence: Recurrence(
          freq: RepeatFreq.weekly,
          interval: 2,
          weekdays: const {2, 4},
          until: DateTime(2027, 1, 1),
        ),
        reminders: const [0, 60],
        checklist: const [ChecklistItem(id: 'a', text: 'Mleko')],
        skipped: const {'2026-11-03'},
        doneDates: const {'2026-10-20'},
        checks: const {
          '2026-10-20': {'a'},
        },
      );
      final back = Entry.fromJson(e.toJson());
      expect(back.toJson(), e.toJson());
      expect(back.recurrence!.weekdays, {2, 4});
      expect(back.checks['2026-10-20'], {'a'});
    });
  });
}
