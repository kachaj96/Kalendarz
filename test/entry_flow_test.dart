import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalendarz/data/shared_store.dart';
import 'package:kalendarz/domain/category.dart';
import 'package:kalendarz/domain/entry.dart';
import 'package:kalendarz/ui/widgets/entry_tile.dart';

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

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('save-entry')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initPolish);

  group('dodawanie wpisu', () {
    testWidgets(
      'domyślnie zapisuje wpis wspólny na dziś i pokazuje go na liście',
      (tester) async {
        final stores = await pumpHome(tester);
        await openForm(tester);
        await tester.enterText(
          find.byKey(const Key('entry-title')),
          'Wizyta u dentysty',
        );
        await save(tester);

        expect(stores.local.data.entries, isEmpty);
        final e = stores.shared.entries.values.single;
        expect(e.title, 'Wizyta u dentysty');
        expect(e.isLocal, isFalse);
        expect(e.createdBy, 'u1');
        expect(e.type, EntryType.event);
        expect(e.date, DateTime(2026, 10, 20));
        // Domyślnie najbliższa pełna godzina po 14:32.
        expect(e.startMinutes, 15 * 60);
        expect(e.endMinutes, 16 * 60);
        expect(find.text('Wizyta u dentysty'), findsOneWidget);
      },
    );

    testWidgets('pusty tytuł blokuje zapis', (tester) async {
      final stores = await pumpHome(tester);
      await openForm(tester);
      await save(tester);

      expect(find.text('Wpisz tytuł.'), findsOneWidget);
      expect(stores.local.data.entries, isEmpty);
      expect(stores.shared.entries, isEmpty);
    });

    testWidgets('cotygodniowe zadanie z przypomnieniem, kategorią i listą', (
      tester,
    ) async {
      final stores = await pumpHome(tester);
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
      await save(tester);

      final e = stores.shared.entries.values.single;
      expect(e.type, EntryType.task);
      expect(e.recurrence!.freq, RepeatFreq.weekly);
      expect(e.recurrence!.weekdays, {2, 4});
      expect(e.reminders, [30]);
      expect(e.categoryId, 'zakupy');
      expect(e.checklist.map((i) => i.text), ['Mleko', 'Chleb']);
    });

    testWidgets(
      '"Tylko ja" zapisuje wpis w telefonie, a nie we wspólnej bazie',
      (tester) async {
        final stores = await pumpHome(tester);
        await openForm(tester);
        await tester.enterText(find.byKey(const Key('entry-title')), 'Prezent');
        await scrollTo(tester, find.text('Tylko ja'));
        await tester.tap(find.text('Tylko ja'));
        await tester.pumpAndSettle();
        await save(tester);

        expect(stores.local.data.entries.single.isLocal, isTrue);
        expect(stores.shared.entries, isEmpty);
      },
    );

    testWidgets(
      'zamknięcie formularza z wpisanym tytułem pyta o odrzucenie zmian',
      (tester) async {
        final stores = await pumpHome(tester);
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
        expect(stores.local.data.entries, isEmpty);
        expect(stores.shared.entries, isEmpty);
      },
    );

    testWidgets('nowa kategoria z formularza wspólnego wpisu jest wspólna', (
      tester,
    ) async {
      final stores = await pumpHome(tester);
      await openForm(tester);
      await scrollTo(tester, find.text('Nowa'));
      await tester.tap(find.text('Nowa'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('category-name')),
        'Samochód',
      );
      await tester.tap(find.text('Zapisz').last);
      await tester.pumpAndSettle();

      expect(stores.shared.categories.values.single.name, 'Samochód');
      expect(stores.local.data.categories, isEmpty);
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

    testWidgets(
      'odhaczanie listy lokalnej zapisuje się, a komplet kończy zadanie',
      (tester) async {
        final stores = await pumpHome(tester, entries: [shopping]);
        await tester.tap(find.text('Zakupy spożywcze'));
        await tester.pumpAndSettle();

        expect(find.text('0/2'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('check-i0')));
        await tester.pumpAndSettle();
        expect(find.text('1/2'), findsOneWidget);
        expect(stores.local.data.entries.single.doneDates, isEmpty);

        await tester.tap(find.byKey(const ValueKey('check-i1')));
        await tester.pumpAndSettle();
        expect(find.text('2/2'), findsOneWidget);
        expect(stores.local.data.entries.single.doneDates, {'2026-10-20'});
      },
    );

    testWidgets('edycja zmienia tytuł w szczegółach', (tester) async {
      final stores = await pumpHome(tester, entries: [shopping]);
      await tester.tap(find.text('Zakupy spożywcze'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edytuj'));
      await tester.pumpAndSettle();

      expect(find.text('Edytuj wpis'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('entry-title')),
        'Zakupy na weekend',
      );
      await save(tester);

      expect(stores.local.data.entries.single.title, 'Zakupy na weekend');
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
      final stores = await pumpHome(tester, entries: [done]);
      await tester.tap(find.text('Zakupy spożywcze'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edytuj'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(RegExp('Początek: data')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('21'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await save(tester);

      final e = stores.local.data.entries.single;
      expect(e.date, DateTime(2026, 10, 21));
      expect(e.doneDates, {'2026-10-21'});
      expect(e.checks['2026-10-21'], {'i0', 'i1'});
    });

    testWidgets('usunięcie wymaga potwierdzenia', (tester) async {
      final stores = await pumpHome(tester, entries: [shopping]);
      await tester.tap(find.text('Zakupy spożywcze'));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Usuń wpis'));
      await tester.tap(find.text('Usuń wpis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();
      expect(stores.local.data.entries, hasLength(1));

      await tester.tap(find.text('Usuń wpis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuń'));
      await tester.pumpAndSettle();
      expect(stores.local.data.entries, isEmpty);
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
      final stores = await pumpHome(tester, entries: [weekly]);
      expect(find.text('Bieganie'), findsNWidgets(2)); // dziś i 27 października

      await tester.tap(find.text('Bieganie').first);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Pomiń ten dzień'));
      await tester.tap(find.text('Pomiń ten dzień'));
      await tester.pumpAndSettle();

      expect(stores.local.data.entries.single.skipped, {'2026-10-20'});
      expect(find.text('Bieganie'), findsOneWidget);
    });
  });

  group('współdzielenie', () {
    final partnerList = makeEntry(
      id: 'p1',
      title: 'Lista od partnera',
      type: EntryType.task,
      date: DateTime(2026, 10, 20),
      start: 1050,
      end: 1110,
      categoryId: 'zakupy',
      items: ['Mleko', 'Chleb'],
      local: false,
    ).copyWith(createdBy: 'u2');

    testWidgets('wpis partnera ma jego inicjał i podpis w szczegółach', (
      tester,
    ) async {
      await pumpHome(tester, sharedEntries: [partnerList]);
      expect(find.text('Lista od partnera'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(EntryTile), matching: find.text('B')),
        findsOneWidget,
      ); // Bartek

      await tester.tap(find.text('Lista od partnera'));
      await tester.pumpAndSettle();
      expect(find.text('Wspólny'), findsOneWidget);
      await scrollTo(tester, find.textContaining('dodał(a): Bartek Test'));
      expect(find.textContaining('dodał(a): Bartek Test'), findsOneWidget);
    });

    testWidgets(
      'odhaczenie wspólnej listy trafia do bazy, komplet kończy zadanie',
      (tester) async {
        final stores = await pumpHome(tester, sharedEntries: [partnerList]);
        await tester.tap(find.text('Lista od partnera'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('check-i0')));
        await tester.pumpAndSettle();
        expect(stores.shared.entries['p1']!.checks['2026-10-20'], {'i0'});
        expect(stores.shared.entries['p1']!.doneDates, isEmpty);

        await tester.tap(find.byKey(const ValueKey('check-i1')));
        await tester.pumpAndSettle();
        expect(stores.shared.entries['p1']!.doneDates, {'2026-10-20'});
        expect(find.text('2/2'), findsOneWidget);
      },
    );

    testWidgets('wpis lokalny zmieniony na wspólny przenosi się do bazy', (
      tester,
    ) async {
      final mine = makeEntry(
        id: 'm1',
        title: 'Kino',
        date: DateTime(2026, 10, 24),
        start: 1200,
        end: 1350,
      );
      final stores = await pumpHome(tester, entries: [mine]);
      await tester.tap(find.text('Kino'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edytuj'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Wspólny'));
      await tester.tap(find.text('Wspólny'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(stores.local.data.entries, isEmpty);
      final e = stores.shared.entries['m1']!;
      expect(e.isLocal, isFalse);
      expect(e.createdBy, 'u1');
    });

    testWidgets('wspólny zmieniony na lokalny pyta o zgodę i znika z bazy', (
      tester,
    ) async {
      final ours = makeEntry(
        id: 's1',
        title: 'Obiad',
        date: DateTime(2026, 10, 21),
        start: 780,
        end: 840,
        local: false,
      ).copyWith(createdBy: 'u1');
      final stores = await pumpHome(tester, sharedEntries: [ours]);
      await tester.tap(find.text('Obiad'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edytuj'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Tylko ja'));
      await tester.tap(find.text('Tylko ja'));
      await tester.pumpAndSettle();
      expect(find.text('Zrobić wpis tylko dla siebie?'), findsOneWidget);
      await tester.tap(find.text('Tak, tylko ja'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(stores.shared.entries, isEmpty);
      expect(stores.local.data.entries.single.id, 's1');
      expect(stores.local.data.entries.single.isLocal, isTrue);
    });
  });

  group('kategorie', () {
    Future<void> openCategories(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kategorie'));
      await tester.pumpAndSettle();
    }

    testWidgets('usunięcie kategorii lokalnej przenosi jej wpisy do Inne', (
      tester,
    ) async {
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
      final stores = await pumpHome(tester, entries: [e], categories: [cat]);
      await openCategories(tester);

      expect(find.text('Moja'), findsOneWidget);
      expect(find.text('Sport'), findsOneWidget);

      await scrollTo(tester, find.byTooltip('Usuń Moja'));
      await tester.tap(find.byTooltip('Usuń Moja'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuń'));
      await tester.pumpAndSettle();

      expect(stores.local.data.categories, isEmpty);
      expect(stores.local.data.entries.single.categoryId, fallbackCategoryId);
    });

    testWidgets(
      'kategoria domyślna usunięta wspólnie znika z listy, wpisy idą do Inne',
      (tester) async {
        final e = makeEntry(
          id: 'x',
          title: 'Mecz',
          date: DateTime(2026, 10, 21),
          start: 600,
          end: 660,
          categoryId: 'sport',
          local: false,
        );
        final stores = await pumpHome(tester, sharedEntries: [e]);
        await openCategories(tester);

        await tester.tap(find.byTooltip('Usuń Sport'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Usuń'));
        await tester.pumpAndSettle();

        expect(stores.shared.categories['sport']!.deleted, isTrue);
        expect(stores.shared.entries['x']!.categoryId, fallbackCategoryId);
        expect(find.text('Sport'), findsNothing);
      },
    );

    testWidgets('kategorii Inne nie da się usunąć', (tester) async {
      await pumpHome(tester);
      await openCategories(tester);
      expect(find.byTooltip('Edytuj Inne'), findsOneWidget);
      expect(find.byTooltip('Usuń Inne'), findsNothing);
    });
  });

  group('wspólna baza', () {
    test('kategorie domyślne z nałożonymi zmianami i własnymi', () {
      final merged = mergeSharedCategories(const [
        SharedCategoryDoc(id: 'dom', name: 'Mieszkanie', color: 0xFF000000),
        SharedCategoryDoc(id: 'sport', deleted: true),
        SharedCategoryDoc(id: 'inne', deleted: true),
        SharedCategoryDoc(id: 'abc', name: 'Auto', color: 0xFF111111),
      ]);
      final names = merged.map((c) => c.name).toList();
      expect(names.first, 'Mieszkanie');
      expect(names, isNot(contains('Sport')));
      expect(names, contains('Inne')); // "Inne" nie może zniknąć
      expect(names.last, 'Auto');
    });

    test(
      'edycja nie kasuje odhaczeń, które partner zrobił w międzyczasie',
      () async {
        final store = MemorySharedStore();
        final base = makeEntry(
          id: 'z',
          title: 'Zakupy',
          date: DateTime(2026, 10, 20),
          items: ['A', 'B'],
          local: false,
        );
        await store.putEntry('s1', base);
        // Partner odhacza punkt, a my edytujemy tytuł na starej kopii wpisu.
        await store.setChecked('s1', 'z', '2026-10-20', 'i0', true);
        await store.putEntry(
          's1',
          base.copyWith(title: 'Zakupy na weekend'),
          previous: base,
        );

        final e = store.entries['z']!;
        expect(e.title, 'Zakupy na weekend');
        expect(e.checks['2026-10-20'], {'i0'});
      },
    );
  });
}
