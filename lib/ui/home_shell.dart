import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../space/models.dart';
import 'invite_card.dart';
import 'settings_screen.dart';

enum HomeTab {
  agenda('Najbliższe', Icons.view_agenda_outlined, Icons.view_agenda),
  day('Dzień', Icons.today_outlined, Icons.today),
  week('Tydzień', Icons.view_week_outlined, Icons.view_week),
  month('Miesiąc', Icons.calendar_month_outlined, Icons.calendar_month);

  const HomeTab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Główny ekran z czterema widokami. Na razie puste, widoki dochodzą w kolejnym etapie.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.space, required this.meUid});

  final Space space;
  final String meUid;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  HomeTab _tab = HomeTab.agenda;

  void _openSettings() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );

  void _soon(String what) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$what pojawi się w następnym etapie.')));

  @override
  Widget build(BuildContext context) {
    final partner = widget.space.partnerOf(widget.meUid);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tab.label),
        actions: [
          _PairBadge(
            me: widget.space.profiles[widget.meUid],
            partner: partner,
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (v) => v == 'settings' ? _openSettings() : _soon('Kategorie'),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'cats', child: Text('Kategorie')),
              PopupMenuItem(value: 'settings', child: Text('Partner i ustawienia')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.space.isFull) ...[
            InviteCard(
              code: widget.space.inviteCode,
              onRenew: () => ref
                  .read(spaceRepositoryProvider)
                  .renewInvite(widget.space, widget.meUid),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_tab.selectedIcon, color: scheme.primary),
                const SizedBox(height: 8),
                Text('Widok „${_tab.label}”',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  partner == null
                      ? 'Kalendarz jest gotowy. Widoki i dodawanie wpisów dochodzą w następnym etapie.'
                      : 'Połączono z: ${partner.name}. Widoki i dodawanie wpisów dochodzą w następnym etapie.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _soon('Dodawanie wpisów'),
        tooltip: 'Nowy wpis',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => setState(() => _tab = HomeTab.values[i]),
        destinations: [
          for (final t in HomeTab.values)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _PairBadge extends StatelessWidget {
  const _PairBadge({required this.me, required this.partner});

  final Profile? me;
  final Profile? partner;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget dot(Profile? p, Color bg, Color fg) => CircleAvatar(
          radius: 12,
          backgroundColor: bg,
          child: Text(
            p == null || p.name.isEmpty ? '?' : p.name.characters.first.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
          ),
        );
    return Semantics(
      label: partner == null ? 'Brak partnera' : 'Połączono z ${partner!.name}',
      child: Row(
        children: [
          dot(me, scheme.primary, scheme.onPrimary),
          Transform.translate(
            offset: const Offset(-6, 0),
            child: dot(
              partner,
              partner == null ? scheme.outlineVariant : const Color(0xFFC93C7B),
              Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
