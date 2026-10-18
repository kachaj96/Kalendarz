import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalendarz/app.dart';
import 'package:kalendarz/device/device_port.dart';
import 'package:kalendarz/providers_calendar.dart';
import 'package:kalendarz/ui/settings_screen.dart';

import 'helpers.dart';

class _FailingPort extends NoopDevicePort {
  @override
  Future<DeviceStatus> status() async => throw StateError('brak ikonki');
}

Widget _app(DevicePort port) => ProviderScope(
  overrides: [devicePortProvider.overrideWithValue(port)],
  child: const AppShell(
    home: Scaffold(body: SingleChildScrollView(child: DeviceSection())),
  ),
);

void main() {
  setUpAll(initPolish);

  testWidgets(
    'błąd sprawdzania uprawnień jest widoczny, a nie wisi na "Sprawdzam"',
    (tester) async {
      await tester.pumpWidget(_app(_FailingPort()));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Nie udało się sprawdzić uprawnień'),
        findsOneWidget,
      );
      expect(find.text('Spróbuj ponownie'), findsOneWidget);
      expect(find.text('Test teraz'), findsOneWidget);
    },
  );

  testWidgets('poprawny stan pokazuje uprawnienia i przyciski testowe', (
    tester,
  ) async {
    await tester.pumpWidget(_app(NoopDevicePort()));
    await tester.pumpAndSettle();
    expect(find.text('Powiadomienia włączone'), findsOneWidget);
    expect(find.text('Test za minutę'), findsOneWidget);
  });
}
