import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalendarz/domain/category.dart';
import 'package:kalendarz/domain/entry.dart';

import 'helpers.dart';

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> openForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('fab-new')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initPolish);

  group('dodawanie wpisu', () {
    testWidgets('zapisuje wpis lokalny na dziś i pokazuje go na liście', (
      tester,
    ) async {
      final store = await pumpHome(tester);
      await openForm(tester);

      await tester.enterText(
        find.byKey(const Key('entry-title')),
        'Wizyta u dentysty',
      );
      await tester.tap(find.byKey(const Key('save-entry')));
      await tester.pumpAndSettle();

      final e = store.data.entries.single;
      expect(e.title, 'Wizyta u dentysty');
      expect(e.isLocal, isTrue);
      expect(e.type, EntryType.event);
      expect(e.date, DateTime(2026, 10, 20));
      // Domyślnie najbliższa pełna godzina po 14:32.
      expect(e.startMinutes, 15 * 60);
      expect(e.endMinutes, 16 * 60);
      expect(find.text('Wizyta u dentysty'), findsOneWidget);
    });

    testWidgets('pusty tytuł blokuje zapis', (tester) async {
      final store = await pumpHome(tester);
      await openForm(tester);

      await tester.tap(find.byKey(const Key('save-entry')));
      await tester.pumpAndSettle();

      expect(find.text('Wpisz tytuł.'), findsOneWidget);
      expect(store.data.entries, isEmpty);
    });

    testWidgets('cotygodniowe zadanie z przypomnieniem, kategorią i listą', (
      tester,
    ) async {
      final store = await pumpHome(tester);
      await openForm(tester);

      await tester.tap(find.text('Zadanie'));
      await tester.enterText(
        find.byKey(const Key('entry-title')),
        'Zakupy spożywcze',
      );
      await tester.pumpAndSettle();

      await scrollTo(tester, find.byKey(const Key('repeat-weekly')));
      await tester.tap(find.byKey(const Key('repeat-weekly')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('weekday-2')));
      await tester.tap(find.byKey(const Key('weekday-4')));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('30 min'));
      await tester.tap(find.text('30 min'));
      await tester.tap(find.byKey(const Key('cat-zakupy')));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.byKey(const Key('add-item')));
      await tester.tap(find.byKey(const Key('add-item')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('item-0')), 'Mleko');
      await tester.tap(find.byKey(const Key('add-item')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('item-1')), 'Chleb');
      // Pusty punkt na końcu ma zostać pominięty.
      await tester.tap(find.byKey(const Key('add-item')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save-entry')));
      await tester.pumpAndSettle();

      final e = store.data.entries.single;
      expect(e.type, EntryType.task);
      expect(e.recurrence!.freq, RepeatFreq.weekly);
      expect(e.recurrence!.weekdays, {2, 4});
      expect(e.reminders, [30]);
      expect(e.categoryId, 'zakupy');
      expect(e.checklist.map((i) => i.text), ['Mleko', 'Chleb']);
    });

    testWidgets(
      'wpis wspólny jest na razie niedostępny, zapisuje się jako lokalny',
      (tester) async {
        final store = await pumpHome(tester);
        await openForm(tester);
        await tester.enterText(find.byKey(const Key('entry-title')), 'Test');
        await scrollTo(tester, find.text('Wspólny'));
        await tester.tap(find.text('Wspólny'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('save-entry')));
        await tester.pumpAndSettle();
        expect(store.data.entries.single.isLocal, isTrue);
      },
    );

    testWidgets(
      'zamknięcie formularza z wpisanym tytułem pyta o odrzucenie zmian',
      (tester) async {
        final store = await pumpHome(tester);
        await openForm(tester);
        await tester.enterText(
          find.byKey(const Key('entry-title')),
          'Nie zapisuj mnie',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Zamknij'));
        await tester.pumpAndSettle();
        expect(find.text('Odrzucić zmiany?'), findsOneWidget);

        await tester.tap(find.text('Odrzuć'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('entry-title')), findsNothing);
        expect(store.data.entries, isEmpty);
      },
    );

    testWidgets('własna kategoria z formularza trafia do wyboru', (
      tester,
    ) async {
      final store = await pumpHome(tester);
      await openForm(tester);
      await scrollTo(tester, find.text('Nowa'));
      await tester.tap(find.text('Nowa'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Samochód');
      await tester.tap(find.text('Zapisz').last);
      await tester.pumpAndSettle();

      expect(store.data.categories.single.name, 'Samochód');
      expect(store.data.categories.single.isLocal, isTrue);
      expect(find.text('Samochód'), findsOneWidget);
    });
  });

  group('szczegóły wpisu', () {
    final shopping = makeEntry(
      title: 'Zakupy spożywcze',
      type: EntryType.task,
      date: DateTime(2026, 10, 20),
      start: 1050,
      end: 1110,
      categoryId: 'zakupy',
      items: ['Mleko', 'Chleb'],
    );

    testWidgets('odhaczanie listy zapisuje się, a komplet kończy zadanie', (
      tester,
    ) async {
      final store = await pumpHome(tester, entries: [shopping]);
      await tester.tap(find.text('Zakupy spożywcze'));
      await tester.pumpAndSettle();

      expect(find.text('0/2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('check-i0')));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);
      expect(store.data.entries.single.doneDates, isEmpty);

      await tester.tap(find.byKey(const ValueKey('check-i1')));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
      expect(store.data.entries.single.doneDates, {'2026-10-20'});
    });

    testWidgets('edycja zmienia tytuł w szczegółach', (tester) async {
      final store = await pumpHome(tester, entries: [shopping]);
      await tester.tap(find.text('Zakupy spożywcze'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edytuj'));
      await tester.pumpAndSettle();

      expect(find.text('Edytuj wpis'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('entry-title')),
        'Zakupy na weekend',
      );
      await tester.tap(find.byKey(const Key('save-entry')));
      await tester.pumpAndSettle();

      expect(store.data.entries.single.title, 'Zakupy na weekend');
      expect(find.text('Zakupy na weekend'), findsOneWidget);
    });

    testWidgets('przeniesienie wpisu na inny dzień zachowuje odhaczenia', (
      tester,
    ) async {
      final done = shopping.copyWith(
        doneDates: {'2026-10-20'},
        checks: {
          '2026-10-20': {'i0', 'i1'},
        },
      );
      final store = await pumpHome(tester, entries: [done]);
      await tester.tap(find.text('Zakupy spożywcze'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edytuj'));
      await tester.pumpAndSettle();

      // Przesuń początek na kolejny dzień przez okno wyboru daty.
      await tester.tap(find.bySemanticsLabel(RegExp('Początek: data')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('21'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-entry')));
      await tester.pumpAndSettle();

      final e = store.data.entries.single;
      expect(e.date, DateTime(2026, 10, 21));
      expect(e.doneDates, {'2026-10-21'});
      expect(e.checks['2026-10-21'], {'i0', 'i1'});
    });

    testWidgets('usunięcie wymaga potwierdzenia', (tester) async {
      final store = await pumpHome(tester, entries: [shopping]);
      await tester.tap(find.text('Zakupy spożywcze'));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Usuń wpis'));
      await tester.tap(find.text('Usuń wpis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();
      expect(store.data.entries, hasLength(1));

      await tester.tap(find.text('Usuń wpis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuń'));
      await tester.pumpAndSettle();
      expect(store.data.entries, isEmpty);
      expect(find.text('Zakupy spożywcze'), findsNothing);
    });

    testWidgets('pominięcie dnia w serii usuwa tylko to wystąpienie', (
      tester,
    ) async {
      final weekly = makeEntry(
        title: 'Bieganie',
        date: DateTime(2026, 10, 13),
        start: 420,
        end: 480,
        recurrence: const Recurrence(freq: RepeatFreq.weekly, weekdays: {2}),
      );
      final store = await pumpHome(tester, entries: [weekly]);
      expect(find.text('Bieganie'), findsNWidgets(2)); // dziś i 27 października

      await tester.tap(find.text('Bieganie').first);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Pomiń ten dzień'));
      await tester.tap(find.text('Pomiń ten dzień'));
      await tester.pumpAndSettle();

      expect(store.data.entries.single.skipped, {'2026-10-20'});
      expect(find.text('Bieganie'), findsOneWidget);
    });
  });

  group('kategorie', () {
    testWidgets(
      'nowa kategoria lokalna pojawia się na liście, usunięcie przenosi wpisy do Inne',
      (tester) async {
        const cat = Category(
          id: 'moja',
          name: 'Moja',
          color: 0xFF2F6FDE,
          isLocal: true,
        );
        final e = makeEntry(
          title: 'Przegląd auta',
          date: DateTime(2026, 10, 21),
          start: 600,
          end: 660,
          categoryId: 'moja',
        );
        final store = await pumpHome(tester, entries: [e], categories: [cat]);

        await tester.tap(find.byTooltip('Menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kategorie'));
        await tester.pumpAndSettle();

        expect(find.text('Moja'), findsOneWidget);
        expect(find.text('Sport'), findsOneWidget);

        await scrollTo(tester, find.byTooltip('Usuń Moja'));
        await tester.tap(find.byTooltip('Usuń Moja'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Usuń'));
        await tester.pumpAndSettle();

        expect(store.data.categories, isEmpty);
        expect(store.data.entries.single.categoryId, fallbackCategoryId);
      },
    );
  });
}
