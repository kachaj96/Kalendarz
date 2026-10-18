import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalendarz/device/reminder_plan.dart';
import 'package:kalendarz/device/widget_snapshot.dart';
import 'package:kalendarz/domain/category.dart';
import 'package:kalendarz/domain/entry.dart';

import 'helpers.dart';

Entry withReminders(Entry e, List<int> r) => e.copyWith(reminders: r);

void main() {
  final now = DateTime(2026, 10, 20, 14, 32);

  group('plan przypomnień', () {
    test('wpis z godziną: kilka wyprzedzeń, bez tych z przeszłości', () {
      final e = withReminders(
        makeEntry(
          title: 'Dentysta',
          date: DateTime(2026, 10, 21),
          start: 510,
          end: 555,
        ),
        [0, 60, 1440],
      );
      final plan = planReminders([e], now);
      expect(
        plan.map((p) => p.at),
        [
          DateTime(
            2026,
            10,
            21,
            7,
            30,
          ), // 1440 min przed 8:30 to dziś 8:30, już minęło
          DateTime(2026, 10, 21, 8, 30),
        ]..sort(),
      );
      expect(plan.first.title, 'Dentysta');
      // Tekst jest liczony względem chwili, w której zadzwoni alarm (21 paź rano).
      expect(plan.first.body, 'Dziś, 08:30 - 09:15');
    });

    test('1 dzień wcześniej, gdy to jeszcze przyszłość', () {
      final e = withReminders(
        makeEntry(
          title: 'Urodziny',
          date: DateTime(2026, 10, 23),
          allDay: true,
        ),
        [1440],
      );
      final plan = planReminders([e], now);
      // Całodniowy wpis przypomina o 9:00, więc dzień wcześniej to 22 paź 9:00.
      expect(plan.single.at, DateTime(2026, 10, 22, 9));
      expect(plan.single.body, 'Jutro, cały dzień');
    });

    test(
      'wpis cykliczny dostaje alarm dla każdego wystąpienia w horyzoncie',
      () {
        final e = withReminders(
          makeEntry(
            title: 'Bieganie',
            date: DateTime(2026, 10, 1),
            start: 420,
            end: 480,
            recurrence: const Recurrence(
              freq: RepeatFreq.weekly,
              weekdays: {2, 4},
            ),
          ),
          [10],
        );
        final plan = planReminders([e], now);
        expect(
          plan.first.at,
          DateTime(2026, 10, 22, 6, 50),
        ); // dzisiejsze 6:50 już minęło
        expect(plan.length, 6); // 3 tygodnie po 2 wystąpienia
        expect(plan.map((p) => p.id).toSet().length, plan.length);
      },
    );

    test('zrobione zadanie nie przypomina', () {
      final e = withReminders(
        makeEntry(
          title: 'Rachunek',
          type: EntryType.task,
          date: DateTime(2026, 10, 21),
          allDay: true,
        ),
        [0],
      ).copyWith(doneDates: {'2026-10-21'});
      expect(planReminders([e], now), isEmpty);
    });

    test('identyfikator jest stabilny', () {
      expect(stableId('a|2026-10-20|10'), stableId('a|2026-10-20|10'));
      expect(stableId('a|2026-10-20|10'), isNot(stableId('a|2026-10-20|30')));
      expect(stableId('x'), lessThan(1 << 31));
    });
  });

  group('dane widżetów', () {
    test('zawiera dzisiejsze wpisy z kolorem kategorii i stanem', () {
      final entries = [
        makeEntry(
          id: '1',
          title: 'Spotkanie',
          date: DateTime(2026, 10, 20),
          start: 540,
          end: 600,
          categoryId: 'praca',
        ),
        makeEntry(
          id: '2',
          title: 'Urodziny',
          date: DateTime(2026, 10, 23),
          allDay: true,
          categoryId: 'rodzina',
        ),
      ];
      final cats = {for (final c in defaultCategories) c.id: c};
      final json = jsonDecode(
        buildWidgetSnapshot(entries, cats, now),
      ) as Map<String, dynamic>;
      final items = (json['items'] as List).cast<Map<String, dynamic>>();
      final meeting = items.firstWhere((i) => i['t'] == 'Spotkanie');
      expect(meeting['d'], '2026-10-20');
      expect(meeting['s'], 540);
      expect(meeting['c'], 0xFF2F6FDE);
      expect(meeting['l'], isTrue);
      final bday = items.firstWhere((i) => i['t'] == 'Urodziny');
      expect(bday['s'], -1);
    });
  });
}
