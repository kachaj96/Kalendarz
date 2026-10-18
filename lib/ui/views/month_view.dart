import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_repository.dart';
import '../../domain/dates.dart';
import '../../domain/occurrence.dart';
import '../../providers_calendar.dart';
import '../format.dart';
import '../navigation.dart';
import '../widgets/entry_tile.dart';

/// Miesiąc: siatka z kropkami w kolorach kategorii i lista wpisów wybranego dnia.
class MonthView extends ConsumerWidget {
  const MonthView({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onOpenDay,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesProvider);
    final now = ref.watch(clockProvider)();
    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(localDataProvider.notifier);

    final first = DateTime(selected.year, selected.month, 1);
    final leading = first.weekday - 1;
    final weeks = ((leading + daysInMonth(first.year, first.month)) / 7).ceil();
    final start = addDays(first, -leading);
    final overdueDays = {
      for (final o in overdueOccurrences(entries, now)) dateKey(o.startDate),
    };

    Widget cell(DateTime day) {
      final inMonth = day.month == first.month;
      final isSelected = sameDay(day, selected);
      final isNow = sameDay(day, now);
      final occs = occurrencesOnDay(entries, day);
      final dots = occs.take(3).toList();
      final hasOverdue = overdueDays.contains(dateKey(day));

      return Expanded(
        child: Semantics(
          button: true,
          excludeSemantics: true,
          label: '${dayMonth(day)}, wpisów: ${occs.length}',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => isSelected ? onOpenDay(day) : onSelect(day),
            child: Container(
              height: 54,
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: isSelected ? scheme.surfaceContainerHighest : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Opacity(
                opacity: inMonth ? 1 : 0.38,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 4),
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isNow ? scheme.primary : null,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isNow
                                  ? scheme.onPrimary
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final o in dots)
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: categoryColorOf(
                                    ref,
                                    o.entry.categoryId,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (occs.length > 3)
                              Text(
                                '+${occs.length - 3}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (hasOverdue)
                      Positioned(
                        top: 4,
                        right: 6,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: scheme.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final selectedOccs = occurrencesOnDay(entries, selected);
    final isNowSelected = sameDay(selected, now);

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
          child: Row(
            children: [
              for (final l in weekdayShort)
                Expanded(
                  child: Center(
                    child: Text(
                      l.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              for (var w = 0; w < weeks; w++)
                Row(
                  children: [
                    for (var d = 0; d < 7; d++) cell(addDays(start, w * 7 + d)),
                  ],
                ),
            ],
          ),
        ),
        Divider(height: 24, color: scheme.outlineVariant),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                isNowSelected ? 'Dziś' : capitalize(weekdayName(selected)),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  dayMonth(selected),
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
        if (selectedOccs.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'Brak wpisów w tym dniu. Dotknij plusa, żeby dodać.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (final Occurrence o in selectedOccs)
                  EntryTile(
                    occurrence: o,
                    onTap: () => openOccurrence(context, o),
                    onToggleDone: () =>
                        notifier.toggleDone(o.entry.id, o.startDate),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
