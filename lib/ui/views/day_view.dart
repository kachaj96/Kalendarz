import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../domain/occurrence.dart';
import '../../providers_calendar.dart';
import '../format.dart';
import '../navigation.dart';
import '../widgets/timeline.dart';

const dayHourHeight = 56.0;

/// Jeden dzień: pasek tygodnia, wpisy całodniowe i oś godzin.
class DayView extends ConsumerStatefulWidget {
  const DayView({super.key, required this.selected, required this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  ConsumerState<DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<DayView> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider)();
    final startHour = sameDay(widget.selected, now)
        ? max(0.0, minutesOfDay(now) / 60 - 2.5)
        : 7.0;
    _scroll = ScrollController(initialScrollOffset: startHour * dayHourHeight);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(entriesProvider);
    final now = ref.watch(clockProvider)();
    final scheme = Theme.of(context).colorScheme;
    final day = dateOnly(widget.selected);
    final occs = occurrencesOnDay(entries, day);
    final allDay = occs.where((o) => o.hasNoTime).toList();
    final items = layoutDay(occs, day);
    final monday = mondayOf(day);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _DayChip(
                    day: addDays(monday, i),
                    selected: sameDay(addDays(monday, i), day),
                    today: sameDay(addDays(monday, i), now),
                    onTap: () => widget.onSelect(addDays(monday, i)),
                  ),
                ),
            ],
          ),
        ),
        AllDayChips(items: allDay, onOpen: (o) => openOccurrence(context, o)),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 96, top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HourLabels(hourHeight: dayHourHeight, width: 44),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        return SizedBox(
                          height: dayHourHeight * 24,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Positioned.fill(
                                child: HourGrid(hourHeight: dayHourHeight),
                              ),
                              for (final it in items)
                                Positioned(
                                  top: it.start / 60 * dayHourHeight + 1,
                                  height: max(
                                    (it.end - it.start) / 60 * dayHourHeight -
                                        2,
                                    22,
                                  ),
                                  left: c.maxWidth / it.lanes * it.lane + 2,
                                  width: c.maxWidth / it.lanes - 4,
                                  child: TimelineEvent(
                                    item: it,
                                    day: day,
                                    onTap: () =>
                                        openOccurrence(context, it.occurrence),
                                  ),
                                ),
                              if (sameDay(day, now))
                                NowLine(
                                  top: minutesOfDay(now) / 60 * dayHourHeight,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? scheme.surfaceContainerHighest : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              weekdayShort[day.weekday - 1].toUpperCase(),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: today ? scheme.primary : null,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: today ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
