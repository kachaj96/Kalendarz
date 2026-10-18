import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_repository.dart';
import '../domain/dates.dart';
import '../providers.dart';
import '../providers_calendar.dart';
import '../space/models.dart';
import 'categories_screen.dart';
import 'format.dart';
import 'invite_card.dart';
import 'navigation.dart';
import 'settings_screen.dart';
import 'views/agenda_view.dart';
import 'views/day_view.dart';
import 'views/month_view.dart';
import 'views/week_view.dart';

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

/// Główny ekran: cztery widoki kalendarza, przycisk dodawania i menu.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.space, required this.meUid});

  final Space space;
  final String meUid;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  HomeTab _tab = HomeTab.agenda;
  late DateTime _selected = dateOnly(ref.read(clockProvider)());

  void _step(int direction) {
    setState(() {
      _selected = switch (_tab) {
        HomeTab.day => addDays(_selected, direction),
        HomeTab.week => addDays(_selected, 7 * direction),
        HomeTab.month => DateTime(
          _selected.year,
          _selected.month + direction,
          1,
        ),
        HomeTab.agenda => _selected,
      };
    });
  }

  void _openDay(DateTime day) => setState(() {
    _selected = dateOnly(day);
    _tab = HomeTab.day;
  });

  (String, String?) _titles() {
    final now = ref.read(clockProvider)();
    switch (_tab) {
      case HomeTab.agenda:
        return ('Najbliższe', '${weekdayName(now)}, ${dayMonth(now)}');
      case HomeTab.day:
        return (
          capitalize(weekdayName(_selected)),
          '${dayMonth(_selected)} ${_selected.year}',
        );
      case HomeTab.week:
        final mon = mondayOf(_selected);
        final sun = addDays(mon, 6);
        final range = mon.month == sun.month
            ? '${mon.day} - ${sun.day} ${shortDate(sun).split(' ').last}'
            : '${mon.day} ${shortDate(mon).split(' ').last} - ${sun.day} ${shortDate(sun).split(' ').last}';
        return (range, 'tydzień ${isoWeekNumber(mon)}, ${sun.year}');
      case HomeTab.month:
        return (monthName(_selected), '${_selected.year}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final partner = widget.space.partnerOf(widget.meUid);
    final scheme = Theme.of(context).colorScheme;
    final data = ref.watch(localDataProvider);
    final (title, subtitle) = _titles();
    final today = dateOnly(ref.watch(clockProvider)());
    final hasNav = _tab != HomeTab.agenda;

    final Widget body;
    if (data.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (data.hasError) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nie udało się wczytać danych z telefonu.\n${data.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      body = switch (_tab) {
        HomeTab.agenda => AgendaView(
          header: [
            if (!widget.space.isFull)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: InviteCard(
                  code: widget.space.inviteCode,
                  onRenew: () => ref
                      .read(spaceRepositoryProvider)
                      .renewInvite(widget.space, widget.meUid),
                ),
              ),
          ],
        ),
        HomeTab.day => DayView(
          key: ValueKey('day-${dateKey(_selected)}-${mondayOf(_selected).day}'),
          selected: _selected,
          onSelect: (d) => setState(() => _selected = d),
        ),
        HomeTab.week => WeekView(selected: _selected, onOpenDay: _openDay),
        HomeTab.month => MonthView(
          selected: _selected,
          onSelect: (d) => setState(() => _selected = d),
          onOpenDay: _openDay,
        ),
      };
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: hasNav ? 0 : null,
        title: Row(
          children: [
            if (hasNav)
              IconButton(
                tooltip: 'Wstecz',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _step(-1),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(title, key: const Key('screen-title')),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (hasNav)
              IconButton(
                tooltip: 'Dalej',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _step(1),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() => _selected = today),
            child: const Text('Dziś'),
          ),
          _PairBadge(me: widget.space.profiles[widget.meUid], partner: partner),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (v) {
              if (v == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CategoriesScreen(),
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'cats', child: Text('Kategorie')),
              PopupMenuItem(
                value: 'settings',
                child: Text('Partner i ustawienia'),
              ),
            ],
          ),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        key: const Key('fab-new'),
        onPressed: () => openEntryForm(
          context,
          initialDate: _tab == HomeTab.agenda ? today : _selected,
        ),
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
        p == null || p.name.isEmpty
            ? '?'
            : p.name.characters.first.toUpperCase(),
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
