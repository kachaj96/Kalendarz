import 'package:flutter/material.dart';

import '../app.dart';

/// Pokazywana, gdy aplikację zbudowano bez danych Firebase (np. lokalnie albo bez sekretu w CI).
class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const AppShell(home: MissingConfigScreen());
}

class MissingConfigScreen extends StatelessWidget {
  const MissingConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.settings_suggest_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text('Brak konfiguracji Firebase', style: t.headlineSmall),
              const SizedBox(height: 12),
              const Text(
                'Ta wersja aplikacji została zbudowana bez danych projektu Firebase, '
                'więc logowanie i wspólny kalendarz nie mogą działać. '
                'Dodaj sekret GOOGLE_SERVICES_JSON w ustawieniach repozytorium na GitHubie '
                'i uruchom budowanie ponownie.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
