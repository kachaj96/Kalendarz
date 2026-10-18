import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../domain/occurrence.dart';
import '../../providers_calendar.dart';
import '../format.dart';
import '../navigation.dart';
import '../widgets/entry_tile.dart';
import '../widgets/timeline.dart';

const weekHourHeight = 44.0;
const _gutter = 32.0;

/// Tydzień: siedem kolumn z osią godzin i paskiem wpisów całodniowych.
class WeekView extends ConsumerStatefulWidget {
  const WeekView({super.key, required this.selected, required this.onOpenDay});

  final DateTime selected;
  final ValueChanged<DateTime> onOpenDay;

  @override
  ConsumerState<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends ConsumerState<WeekView> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    // Początek osi: pierwszy wpis z godziną w tym tygodniu, ale nie niżej niż 7:00.
    final monday = mondayOf(widget.selected);
    var first = 7 * 60;
    for (var i = 0; i < 7; i++) {
      final day = addDays(monday, i);
      for (final it in layoutDay(
        occurrencesOnDay(ref.read(entriesProvider), day),
        day,
      )) {
        if (it.start < first) first = it.start;
      }
    }
    _scroll = ScrollController(
      initialScrollOffset: max(0.0, first / 60 - 0.5) * weekHourHeight,
    );
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
    final monday = mondayOf(widget.selected);
    final days = [for (var i = 0; i < 7; i++) addDays(monday, i)];
    final perDay = [for (final d in days) occurrencesOnDay(entries, d)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final colWidth = (constraints.maxWidth - _gutter - 4) / 7;
        return Column(
          children: [
            Row(
              children: [
                const SizedBox(width: _gutter),
                for (final d in days)
                  SizedBox(
                    width: colWidth,
                    child: InkWell(
                      onTap: () => widget.onOpenDay(d),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            Text(
                              weekdayShort[d.weekday - 1].toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: sameDay(d, now) ? scheme.primary : null,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${d.day}',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: sameDay(d, now)
                                      ? scheme.onPrimary
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: _gutter),
                for (var i = 0; i < 7; i++)
                  SizedBox(
                    width: colWidth,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(1, 0, 1, 6),
                      child: Column(
                        children: [
                          for (final o
                              in perDay[i].where((o) => o.hasNoTime).take(3))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: GestureDetector(
                                onTap: () => openOccurrence(context, o),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: categoryColorOf(
                                      ref,
                                      o.entry.categoryId,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    o.entry.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 96, top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HourLabels(
                      hourHeight: weekHourHeight,
                      width: _gutter,
                      fontSize: 9.5,
                    ),
                    for (var i = 0; i < 7; i++)
                      SizedBox(
                        width: colWidth,
                        height: weekHourHeight * 24,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: sameDay(days[i], now)
                                ? scheme.primary.withValues(alpha: 0.06)
                                : null,
                            border: Border(
                              left: BorderSide(
                                color: scheme.outlineVariant,
                                width: 0.8,
                              ),
                            ),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Positioned.fill(
                                child: HourGrid(hourHeight: weekHourHeight),
                              ),
                              for (final it in layoutDay(perDay[i], days[i]))
                                Positioned(
                                  top: it.start / 60 * weekHourHeight + 1,
                                  height: max(
                                    (it.end - it.start) / 60 * weekHourHeight -
                                        1,
                                    16,
                                  ),
                                  left: colWidth / it.lanes * it.lane + 1,
                                  width: colWidth / it.lanes - 2,
                                  child: TimelineEvent(
                                    item: it,
                                    day: days[i],
                                    compact: true,
                                    onTap: () =>
                                        openOccurrence(context, it.occurrence),
                                  ),
                                ),
                              if (sameDay(days[i], now))
                                NowLine(
                                  top: minutesOfDay(now) / 60 * weekHourHeight,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
