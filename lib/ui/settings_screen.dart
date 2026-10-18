import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../device/device_port.dart';
import '../providers_calendar.dart';
import '../settings/app_settings.dart';
import 'invite_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String spaceId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rozłączyć kalendarz?'),
        content: const Text(
          'Przestaniesz widzieć wspólne wpisy. Partner zachowa wszystko, co zostało we wspólnym kalendarzu. '
          'Żeby wrócić, potrzebny będzie nowy kod od partnera.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rozłącz'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(spaceRepositoryProvider).leave(uid, spaceId);
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final space = ref.watch(spaceProvider).value;
    final scheme = Theme.of(context).colorScheme;
    final partner = user == null ? null : space?.partnerOf(user.uid);

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Partner i ustawienia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section('Konto', [
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(user?.displayName ?? 'Zalogowano'),
                subtitle: Text(user?.email ?? ''),
              ),
            ),
          ]),
          section('Partner', [
            if (space != null && user != null && partner != null)
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: Text(partner.name),
                  subtitle: Text(partner.email),
                ),
              )
            else if (space != null && user != null)
              InviteCard(
                code: space.inviteCode,
                onRenew: () => ref
                    .read(spaceRepositoryProvider)
                    .renewInvite(space, user.uid),
              ),
            const SizedBox(height: 12),
            if (space != null && user != null)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                ),
                onPressed: () =>
                    _confirmLeave(context, ref, user.uid, space.id),
                child: const Text('Rozłącz'),
              ),
          ]),
          section('Wygląd', [const AppearanceSection()]),
          section('Przypomnienia i widżety', [const DeviceSection()]),
          section('Konto Google', [
            OutlinedButton(
              onPressed: () async {
                Navigator.of(context).popUntil((r) => r.isFirst);
                await ref.read(authRepositoryProvider).signOut();
              },
              child: const Text('Wyloguj'),
            ),
          ]),
          section('O aplikacji', [
            const Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text('Kalendarz 1.0'),
                subtitle: Text(
                  'Dane wspólne wymagają internetu. Wpisy lokalne będą działać zawsze.',
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Stan uprawnień, od których zależą przypomnienia, z przyciskami do ich włączenia.
class DeviceSection extends ConsumerStatefulWidget {
  const DeviceSection({super.key});

  @override
  ConsumerState<DeviceSection> createState() => _DeviceSectionState();
}

class _DeviceSectionState extends ConsumerState<DeviceSection> {
  late Future<DeviceStatus> _status = ref.read(devicePortProvider).status();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _refresh() =>
      setState(() => _status = ref.read(devicePortProvider).status());

  Future<void> _run(Future<void> Function() action) async {
    await action();
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final port = ref.read(devicePortProvider);
    final scheme = Theme.of(context).colorScheme;

    Widget row({
      required bool ok,
      required String okText,
      required String badText,
      required String hint,
      required String action,
      required Future<void> Function() onFix,
    }) => ListTile(
      leading: Icon(
        ok ? Icons.check_circle : Icons.error_outline,
        color: ok ? const Color(0xFF1F8A4C) : scheme.error,
      ),
      title: Text(ok ? okText : badText),
      subtitle: ok ? null : Text(hint),
      trailing: ok
          ? null
          : TextButton(onPressed: () => _run(onFix), child: Text(action)),
    );

    return FutureBuilder<DeviceStatus>(
      future: _status,
      builder: (context, snap) {
        final s = snap.data;
        if (s == null) {
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snap.hasError
                        ? 'Nie udało się sprawdzić uprawnień: ${snap.error}'
                        : 'Sprawdzam uprawnienia...',
                    key: const Key('device-status-text'),
                  ),
                  if (snap.hasError) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed: _refresh,
                          child: const Text('Spróbuj ponownie'),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed: () => _run(port.testNotification),
                          child: const Text('Test teraz'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Card(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row(
                ok: s.notificationsEnabled,
                okText: 'Powiadomienia włączone',
                badText: 'Powiadomienia wyłączone',
                hint: 'Bez tego przypomnienia się nie pokażą.',
                action: 'Włącz',
                onFix: port.requestNotifications,
              ),
              row(
                ok: s.exactAlarms,
                okText: 'Dokładne alarmy włączone',
                badText: 'Alarmy mogą się spóźniać',
                hint: 'Android może przesunąć przypomnienie o kilka minut.',
                action: 'Zezwól',
                onFix: port.requestExactAlarms,
              ),
              row(
                ok: s.batteryUnrestricted,
                okText: 'Bez ograniczeń baterii',
                badText: 'Oszczędzanie baterii ogranicza aplikację',
                hint: 'System może uśpić przypomnienia i odświeżanie w tle. Zezwól na działanie bez ograniczeń.',
                action: 'Zmień',
                onFix: port.requestBatteryUnrestricted,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Zaplanowane przypomnienia: ${s.scheduledCount}. Wpisy partnera, alarmy i widżety '
                  'odświeżają się w tle mniej więcej co 30 minut, gdy jest internet, oraz od razu po otwarciu aplikacji.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () => _run(port.testNotification),
                      child: const Text('Test teraz'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () async {
                        await _run(
                          () => port.testNotification(
                            delay: const Duration(minutes: 1),
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Za minutę przyjdzie powiadomienie. Możesz zablokować telefon.',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Test za minutę'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Motyw aplikacji oraz tło i tekst widżetów.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );

    Widget chips<T>(
      List<(T, String)> options,
      T selected,
      void Function(T) onSelect,
    ) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final (value, text) in options)
            ChoiceChip(
              label: Text(text),
              selected: value == selected,
              onSelected: (_) => onSelect(value),
            ),
        ],
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label('Motyw aplikacji'),
          chips<ThemeMode>(
            const [
              (ThemeMode.system, 'Jak w telefonie'),
              (ThemeMode.light, 'Jasny'),
              (ThemeMode.dark, 'Ciemny'),
            ],
            s.themeMode,
            (v) => notifier.set(s.copyWith(themeMode: v)),
          ),
          label('Tło widżetów'),
          chips<int>(
            const [
              (100, 'Pełne'),
              (75, '75%'),
              (50, '50%'),
              (0, 'Przezroczyste'),
            ],
            s.widgetOpacity,
            (v) => notifier.set(s.copyWith(widgetOpacity: v)),
          ),
          label('Tekst w widżetach'),
          chips<WidgetTextMode>(
            const [
              (WidgetTextMode.auto, 'Jak motyw telefonu'),
              (WidgetTextMode.light, 'Jasny'),
              (WidgetTextMode.dark, 'Ciemny'),
            ],
            s.widgetText,
            (v) => notifier.set(s.copyWith(widgetText: v)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Text(
              'Przy przezroczystym tle wybierz jasny tekst na ciemną tapetę albo ciemny na jasną. '
              'Jasny tekst dostaje cień, żeby był czytelny na zdjęciu.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
