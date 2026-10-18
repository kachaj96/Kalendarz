import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalendarz/app.dart';
import 'package:kalendarz/space/models.dart';
import 'package:kalendarz/ui/home_shell.dart';
import 'package:kalendarz/ui/missing_config_screen.dart';

const _me = Profile(uid: 'u1', name: 'Anna Test', email: 'anna@example.com');
const _partner = Profile(uid: 'u2', name: 'Bartek Test', email: 'bartek@example.com');

Widget _app(Space space) => ProviderScope(
      child: AppShell(home: HomeShell(space: space, meUid: 'u1')),
    );

void main() {
  testWidgets('pusta przestrzeń pokazuje kod zaproszenia', (tester) async {
    await tester.pumpWidget(_app(const Space(
      id: 's1',
      memberIds: ['u1'],
      profiles: {'u1': _me},
      inviteCode: 'ABCD2345',
    )));

    expect(find.text('KAL-ABCD-2345'), findsOneWidget);
    expect(find.text('Czekasz na partnera. Przekaż mu ten kod:'), findsOneWidget);
  });

  testWidgets('sparowana przestrzeń nie pokazuje kodu i wymienia partnera', (tester) async {
    await tester.pumpWidget(_app(const Space(
      id: 's1',
      memberIds: ['u1', 'u2'],
      profiles: {'u1': _me, 'u2': _partner},
    )));

    expect(find.textContaining('KAL-'), findsNothing);
    expect(find.textContaining('Bartek Test'), findsOneWidget);
  });

  testWidgets('dolna nawigacja przełącza cztery widoki', (tester) async {
    await tester.pumpWidget(_app(const Space(
      id: 's1',
      memberIds: ['u1', 'u2'],
      profiles: {'u1': _me, 'u2': _partner},
    )));

    expect(find.text('Widok „Najbliższe”'), findsOneWidget);
    for (final tab in HomeTab.values) {
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(tab.label),
      ));
      await tester.pump();
      expect(find.text('Widok „${tab.label}”'), findsOneWidget);
    }
  });

  testWidgets('ekran braku konfiguracji tłumaczy, co zrobić', (tester) async {
    await tester.pumpWidget(const MissingConfigApp());
    expect(find.text('Brak konfiguracji Firebase'), findsOneWidget);
    expect(find.textContaining('GOOGLE_SERVICES_JSON'), findsOneWidget);
  });
}
