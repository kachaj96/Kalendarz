import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalendarz/app.dart';
import 'package:kalendarz/device/device_port.dart';
import 'package:kalendarz/device/reminder_plan.dart';
import 'package:kalendarz/device/widget_snapshot.dart';
import 'package:kalendarz/domain/category.dart';
import 'package:kalendarz/domain/entry.dart';
import 'package:kalendarz/domain/maps_links.dart';
import 'package:kalendarz/providers_calendar.dart';
import 'package:kalendarz/settings/app_settings.dart';
import 'package:kalendarz/ui/settings_screen.dart';

import 'helpers.dart';

void main() {
  setUpAll(initPolish);

  group('linki do Google Maps', () {
    test('trasa do adresu z kodowaniem polskich znaków i spacji', () {
      final uri = directionsUri('  Rynek 1, Wrocław ');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters, {
        'api': '1',
        'destination': 'Rynek 1, Wrocław',
      });
    });

    test('miejsce na mapie', () {
      expect(
        mapUri('Biedronka Legnicka').queryParameters['query'],
        'Biedronka Legnicka',
      );
      expect(mapUri('x').path, '/maps/search/');
    });

    test('wklejony link z Map otwiera się bez zmian', () {
      const link = 'https://maps.app.goo.gl/abc123';
      expect(directionsUri(link).toString(), link);
      expect(mapUri(link).toString(), link);
      expect(locationLabel(link), 'mapa');
      expect(locationLabel('Rynek 1'), 'Rynek 1');
    });

    test('miejsce trafia do przypomnienia i do danych widżetów', () {
      final e = makeEntry(
        title: 'Dentysta',
        date: DateTime(2026, 10, 21),
        start: 510,
        end: 555,
      ).copyWith(location: 'ul. Długa 5', reminders: [60]);
      expect(
        planReminders([e], testNow).single.body,
        'Dziś, 08:30 - 09:15 · ul. Długa 5',
      );
      final cats = {for (final c in defaultCategories) c.id: c};
      final items =
          (jsonDecode(buildWidgetSnapshot([e], cats, testNow))['items'] as List)
              .cast<Map>();
      expect(items.single['p'], 'ul. Długa 5');
    });

    test(
      'miejsce przechodzi przez JSON, stare wpisy bez pola też się wczytują',
      () {
        final e = makeEntry(date: DateTime(2026, 10, 21))
            .copyWith(location: 'Park');
        expect(Entry.fromJson(e.toJson()).location, 'Park');
        final old = e.toJson()..remove('location');
        expect(Entry.fromJson(old).location, '');
      },
    );
  });

  group('miejsce w aplikacji', () {
    testWidgets(
      'formularz zapisuje miejsce, a szczegóły otwierają trasę i mapę',
      (tester) async {
        final stores = await pumpHome(tester);
        await tester.tap(find.byKey(const Key('fab-new')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('entry-title')),
          'Dentysta',
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('entry-location')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(
          find.byKey(const Key('entry-location')),
          'ul. Długa 5, Wrocław',
        );
        await tester.tap(find.byKey(const Key('save-entry')));
        await tester.pumpAndSettle();

        expect(
          stores.shared.entries.values.single.location,
          'ul. Długa 5, Wrocław',
        );
        expect(
          find.text('ul. Długa 5, Wrocław'),
          findsOneWidget,
        ); // pinezka na liście

        await tester.tap(find.text('Dentysta'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('location-route')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('location-map')));
        await tester.pumpAndSettle();

        expect(
          stores.openedUrls.first.queryParameters['destination'],
          'ul. Długa 5, Wrocław',
        );
        expect(
          stores.openedUrls.last.queryParameters['query'],
          'ul. Długa 5, Wrocław',
        );
      },
    );
  });

  group('wygląd', () {
    Future<(MemorySettingsStore, NoopDevicePort)> pumpAppearance(
      WidgetTester tester,
    ) async {
      final store = MemorySettingsStore();
      final device = NoopDevicePort();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWithValue(store),
            devicePortProvider.overrideWithValue(device),
          ],
          child: Consumer(
            builder: (context, ref, _) => AppShell(
              themeMode: ref.watch(appSettingsProvider).themeMode,
              home: const Scaffold(
                body: SingleChildScrollView(child: AppearanceSection()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (store, device);
    }

    testWidgets('przełącznik motywu zmienia motyw aplikacji i zapisuje wybór', (
      tester,
    ) async {
      final (store, _) = await pumpAppearance(tester);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.system,
      );

      await tester.tap(find.text('Ciemny').first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(store.saved.themeMode, ThemeMode.dark);
    });

    testWidgets('tło i tekst widżetów trafiają do telefonu', (tester) async {
      final (store, device) = await pumpAppearance(tester);
      await tester.tap(find.text('Przezroczyste'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jasny').last);
      await tester.pumpAndSettle();

      expect(store.saved.widgetOpacity, 0);
      expect(store.saved.widgetText, WidgetTextMode.light);
      expect(device.widgetStyles.last, (0, WidgetTextMode.light));
    });
  });
}
