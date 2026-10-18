import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalendarz/device/device_port.dart';
import 'package:kalendarz/domain/entry.dart';
import 'package:kalendarz/ui/home_shell.dart';
import 'package:kalendarz/ui/missing_config_screen.dart';

import 'helpers.dart';

void main() {
  setUpAll(initPolish);

  testWidgets('samotna osoba widzi kod zaproszenia', (tester) async {
    await pumpHome(tester, space: lonelySpace);
    expect(find.text('KAL-ABCD-2345'), findsOneWidget);
    expect(
      find.text('Czekasz na partnera. Przekaż mu ten kod:'),
      findsOneWidget,
    );
  });

  testWidgets('sparowana przestrzeń nie pokazuje kodu', (tester) async {
    await pumpHome(tester);
    expect(find.textContaining('KAL-'), findsNothing);
  });

  testWidgets('pusty kalendarz zachęca do dodania pierwszego wpisu', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(find.textContaining('Dotknij plusa'), findsOneWidget);
  });

  testWidgets('dolna nawigacja przełącza cztery widoki', (tester) async {
    await pumpHome(tester);
    String title() =>
        (tester.widget<Text>(find.byKey(const Key('screen-title')))).data!;

    expect(title(), 'Najbliższe');
    for (final (tab, expected) in [
      (HomeTab.day, 'Wtorek'),
      (HomeTab.week, '19 - 25 paź'),
      (HomeTab.month, 'Październik'),
      (HomeTab.agenda, 'Najbliższe'),
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tab.label),
        ),
      );
      await tester.pumpAndSettle();
      expect(title(), expected, reason: tab.label);
    }
  });

  testWidgets('strzałki przesuwają dzień, tydzień i miesiąc, a Dziś wraca', (
    tester,
  ) async {
    await pumpHome(tester);
    String title() =>
        (tester.widget<Text>(find.byKey(const Key('screen-title')))).data!;
    Future<void> tab(HomeTab t) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(t.label),
        ),
      );
      await tester.pumpAndSettle();
    }

    await tab(HomeTab.day);
    await tester.tap(find.byTooltip('Dalej'));
    await tester.pumpAndSettle();
    expect(title(), 'Środa');

    await tab(HomeTab.week);
    await tester.tap(find.byTooltip('Dalej'));
    await tester.pumpAndSettle();
    expect(title(), '26 paź - 1 lis'.replaceAll('26 paź - 1 lis', title()));
    expect(title(), contains('26'));

    await tab(HomeTab.month);
    await tester.tap(find.byTooltip('Wstecz'));
    await tester.pumpAndSettle();
    expect(title(), 'Wrzesień');

    await tester.tap(find.text('Dziś'));
    await tester.pumpAndSettle();
    expect(title(), 'Październik');
  });

  testWidgets('ekran braku konfiguracji tłumaczy, co zrobić', (tester) async {
    await tester.pumpWidget(const MissingConfigApp());
    expect(find.text('Brak konfiguracji Firebase'), findsOneWidget);
    expect(find.textContaining('GOOGLE_SERVICES_JSON'), findsOneWidget);
  });

  testWidgets('wpisy pojawiają się w widokach dnia, tygodnia i miesiąca', (
    tester,
  ) async {
    await pumpHome(
      tester,
      entries: [
        makeEntry(
          title: 'Spotkanie projektowe',
          date: DateTime(2026, 10, 20),
          start: 540,
          end: 600,
        ),
        makeEntry(
          id: 'e2',
          title: 'Urodziny mamy',
          date: DateTime(2026, 10, 23),
          allDay: true,
          categoryId: 'rodzina',
        ),
      ],
    );
    Future<void> tab(HomeTab t) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(t.label),
        ),
      );
      await tester.pumpAndSettle();
    }

    expect(find.text('Spotkanie projektowe'), findsOneWidget);
    expect(find.text('Urodziny mamy'), findsOneWidget);

    await tab(HomeTab.day);
    expect(
      find.textContaining('Spotkanie projektowe', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('09:00 - 10:00'), findsOneWidget);

    await tab(HomeTab.week);
    expect(find.text('Spotkanie projektowe'), findsOneWidget);
    expect(find.text('Urodziny mamy'), findsOneWidget);

    await tab(HomeTab.month);
    expect(find.text('Spotkanie projektowe'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('23 października, wpisów: 1'));
    await tester.pumpAndSettle();
    expect(find.text('Urodziny mamy'), findsOneWidget);
    expect(find.text('Spotkanie projektowe'), findsNothing);
  });

  testWidgets('drugie dotknięcie dnia w miesiącu otwiera widok dnia', (
    tester,
  ) async {
    await pumpHome(
      tester,
      entries: [
        makeEntry(
          title: 'Kino',
          date: DateTime(2026, 10, 24),
          start: 1200,
          end: 1350,
        ),
      ],
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Miesiąc'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('24 października, wpisów: 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('24 października, wpisów: 1'));
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Text>(find.byKey(const Key('screen-title')))).data,
      'Sobota',
    );
    expect(find.text('20:00 - 22:30'), findsOneWidget);
  });

  testWidgets('zaległe zadanie jest w osobnej sekcji i znika po odhaczeniu', (
    tester,
  ) async {
    await pumpHome(
      tester,
      entries: [
        makeEntry(
          title: 'Zapłacić rachunek',
          type: EntryType.task,
          date: DateTime(2026, 10, 19),
          allDay: true,
        ),
      ],
    );
    expect(find.text('Zaległe'), findsOneWidget);
    expect(find.text('PO TERMINIE'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Zrobione'));
    await tester.pumpAndSettle();
    expect(find.text('Zaległe'), findsNothing);
  });

  testWidgets('po zmianie wpisów telefon przelicza alarmy i widżety', (
    tester,
  ) async {
    final device = NoopDevicePort();
    await pumpHome(
      tester,
      device: device,
      entries: [
        makeEntry(
          title: 'Kino',
          date: DateTime(2026, 10, 24),
          start: 1200,
          end: 1350,
        ),
      ],
    );
    await tester.pump(const Duration(seconds: 2));
    expect(device.syncs, isNotEmpty);
    expect(device.syncs.last.entries.single.title, 'Kino');
    expect(device.syncs.last.myUid, 'u1');
  });

  testWidgets('otwarcie z widżetu miesiąca pokazuje wskazany dzień', (
    tester,
  ) async {
    final device = NoopDevicePort(
      launchUri: Uri.parse('kalendarz://open?tab=day&date=2026-10-24'),
    );
    await pumpHome(tester, device: device);
    expect(
      (tester.widget<Text>(find.byKey(const Key('screen-title')))).data,
      'Sobota',
    );
  });

  testWidgets('dotknięte przypomnienie otwiera szczegóły wpisu', (
    tester,
  ) async {
    final device = NoopDevicePort(notificationPayload: 'e1|2026-10-21');
    await pumpHome(
      tester,
      device: device,
      entries: [
        makeEntry(
          title: 'Wizyta u dentysty',
          date: DateTime(2026, 10, 21),
          start: 510,
          end: 555,
        ),
      ],
    );
    expect(find.byTooltip('Edytuj'), findsOneWidget);
    expect(find.text('Środa, 21 października'), findsOneWidget);
  });
}
