import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_repository.dart';
import '../../domain/dates.dart';
import '../../domain/occurrence.dart';
import '../../providers_calendar.dart';
import '../format.dart';
import '../navigation.dart';
import '../widgets/entry_tile.dart';

const agendaDays = 14;

/// Lista nadchodzących wpisów pogrupowana po dniach, z sekcją zaległych na górze.
class AgendaView extends ConsumerWidget {
  const AgendaView({super.key, this.header = const []});

  final List<Widget> header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    final overdue = overdueOccurrences(entries, today);
    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(localDataProvider.notifier);

    Widget tile(Occurrence o, {String? label, bool isOverdue = false}) =>
        EntryTile(
          occurrence: o,
          timeLabel: label,
          overdue: isOverdue,
          onTap: () => openOccurrence(context, o),
          onToggleDone: () => notifier.toggleDone(o.entry.id, o.startDate),
        );

    final children = <Widget>[...header];

    if (overdue.isNotEmpty) {
      children.add(
        Container(
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              scheme.error.withValues(alpha: 0.08),
              scheme.surfaceContainerLowest,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: scheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Zaległe',
                      style: TextStyle(
                        color: scheme.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${overdue.length}',
                      style: TextStyle(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              for (final o in overdue)
                tile(
                  o,
                  label:
                      '${weekdayShort[o.startDate.weekday - 1]} ${o.startDate.day}',
                  isOverdue: true,
                ),
            ],
          ),
        ),
      );
    }

    var anyUpcoming = false;
    for (var i = 0; i < agendaDays; i++) {
      final day = addDays(today, i);
      final occs = occurrencesOnDay(entries, day);
      if (occs.isEmpty && i > 0) continue;
      if (occs.isNotEmpty) anyUpcoming = true;

      final label = i == 0
          ? 'Dziś'
          : i == 1
          ? 'Jutro'
          : capitalize(weekdayName(day));
      final sub = i < 2
          ? '${weekdayName(day)}, ${dayMonth(day)}'
          : dayMonth(day);
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: i == 0 ? scheme.primary : scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (occs.isEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Brak wpisów.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        );
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [for (final o in occs) tile(o)]),
          ),
        );
      }
    }

    if (!anyUpcoming && overdue.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
          child: Text(
            'Nic nie jest zaplanowane na najbliższe dwa tygodnie. Dotknij plusa, żeby dodać pierwszy wpis.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: children,
    );
  }
}
