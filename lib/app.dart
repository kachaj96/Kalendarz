import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'theme.dart';
import 'ui/home_shell.dart';
import 'ui/pairing_screen.dart';
import 'ui/sign_in_screen.dart';

const _pl = Locale('pl');

class KalendarzApp extends StatelessWidget {
  const KalendarzApp({super.key});

  @override
  Widget build(BuildContext context) => const AppShell(home: RootGate());
}

/// Wspólne ustawienia MaterialApp: polski język, motyw jasny i ciemny wg systemu.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kalendarz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: _pl,
      supportedLocales: const [_pl],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );
  }
}

/// Wybiera ekran: logowanie, parowanie albo właściwą aplikację.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const _Splash(),
      error: (e, _) =>
          _ErrorView(message: 'Nie udało się sprawdzić logowania.\n$e'),
      data: (user) {
        if (user == null) return const SignInScreen();

        final spaceId = ref.watch(spaceIdProvider);
        if (spaceId.isLoading) return const _Splash();
        if (spaceId.value == null) return const PairingScreen();

        final space = ref.watch(spaceProvider);
        return space.when(
          loading: () => const _Splash(),
          // Brak dostępu do przestrzeni (np. po rozłączeniu) oznacza ponowne parowanie.
          error: (_, _) => const PairingScreen(),
          data: (s) => s == null
              ? const PairingScreen()
              : HomeShell(space: s, meUid: user.uid),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}
