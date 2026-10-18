import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../domain/occurrence.dart';
import 'entry_tile.dart';

/// Kolumna z godzinami 00-23 po lewej stronie osi czasu.
class HourLabels extends StatelessWidget {
  const HourLabels({
    super.key,
    required this.hourHeight,
    required this.width,
    this.fontSize = 11,
  });

  final double hourHeight;
  final double width;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: width,
      height: hourHeight * 24,
      child: Stack(
        children: [
          for (var h = 1; h < 24; h++)
            Positioned(
              top: h * hourHeight - 7,
              right: 6,
              child: Text(
                h.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: fontSize,
                  color: c,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Poziome linie godzin w tle jednego dnia.
class HourGrid extends StatelessWidget {
  const HourGrid({super.key, required this.hourHeight});

  final double hourHeight;

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).colorScheme.outlineVariant;
    return Column(
      children: [
        for (var h = 0; h < 24; h++)
          Container(
            height: hourHeight,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: line, width: 0.8)),
            ),
          ),
      ],
    );
  }
}

/// Czerwona linia "teraz".
class NowLine extends StatelessWidget {
  const NowLine({super.key, required this.top});

  final double top;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.error;
    return Positioned(
      top: top - 5,
      left: -5,
      right: 0,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            Expanded(child: Container(height: 2, color: c)),
          ],
        ),
      ),
    );
  }
}

/// Blok wpisu na osi godzin.
class TimelineEvent extends ConsumerWidget {
  const TimelineEvent({
    super.key,
    required this.item,
    required this.day,
    required this.onTap,
    this.compact = false,
  });

  final PositionedOccurrence item;
  final DateTime day;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = item.occurrence;
    final scheme = Theme.of(context).colorScheme;
    final color = categoryColorOf(ref, o.entry.categoryId);
    final bg = Color.alphaBlend(color.withValues(alpha: 0.2), scheme.surface);
    final done = o.isDone;

    return Semantics(
      button: true,
      label:
          '${o.entry.title}, ${formatMinutes(item.start)} do ${formatMinutes(item.end >= 1440 ? 1439 : item.end)}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.hardEdge,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 3 : 8,
            vertical: compact ? 2 : 5,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(compact ? 4 : 8),
            border: Border(
              left: BorderSide(color: color, width: compact ? 2 : 3),
            ),
          ),
          child: compact
              ? Text(
                  o.entry.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: o.entry.title),
                          if (o.entry.isLocal)
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.lock_outline, size: 12),
                              ),
                            ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(
                      '${formatMinutes(item.start)} - ${formatMinutes(item.end >= 1440 ? 0 : item.end)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Wpisy całodniowe jako małe etykiety nad osią godzin.
class AllDayChips extends ConsumerWidget {
  const AllDayChips({super.key, required this.items, required this.onOpen});

  final List<Occurrence> items;
  final void Function(Occurrence) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final o in items)
            Builder(
              builder: (context) {
                final color = categoryColorOf(ref, o.entry.categoryId);
                return ActionChip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Color.alphaBlend(
                    color.withValues(alpha: 0.18),
                    scheme.surface,
                  ),
                  side: BorderSide(color: color.withValues(alpha: 0.6)),
                  avatar: o.entry.isLocal
                      ? const Icon(Icons.lock_outline, size: 14)
                      : null,
                  label: Text(
                    o.entry.title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      decoration: o.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  onPressed: () => onOpen(o),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Minuty od północy dla danej chwili.
int minutesOfDay(DateTime t) => t.hour * 60 + t.minute;

bool isToday(DateTime day, DateTime now) => sameDay(day, now);
