import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../domain/entry.dart';
import '../../domain/maps_links.dart';
import '../../domain/occurrence.dart';
import '../../providers_calendar.dart';
import '../format.dart';

Color categoryColorOf(WidgetRef ref, String categoryId) {
  final cat = ref.read(categoryByIdProvider)[categoryId];
  return Color(cat?.color ?? 0xFF5F6B80);
}

/// Wiersz wpisu na listach: godziny po lewej, karta z kolorem kategorii po prawej.
class EntryTile extends ConsumerWidget {
  const EntryTile({
    super.key,
    required this.occurrence,
    required this.onTap,
    required this.onToggleDone,
    this.timeLabel,
    this.overdue = false,
  });

  final Occurrence occurrence;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;

  /// Zamiast godzin, np. data przy zaległych.
  final String? timeLabel;
  final bool overdue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = occurrence.entry;
    final scheme = Theme.of(context).colorScheme;
    final color = categoryColorOf(ref, e.categoryId);
    final done = occurrence.isDone;
    final cardColor = Color.alphaBlend(
      color.withValues(alpha: 0.13),
      scheme.surface,
    );

    final meta = <Widget>[
      if (e.isLocal) _MetaIcon(Icons.lock_outline, 'Tylko na tym telefonie'),
      if (partnerInitial(ref, e) case final String initial)
        _PartnerBadge(initial),
      if (e.isRecurring) _MetaIcon(Icons.repeat, 'Powtarza się'),
      if (e.location.trim().isNotEmpty)
        _MetaText(Icons.place_outlined, locationLabel(e.location)),
      if (e.checklist.isNotEmpty)
        _MetaText(
          Icons.checklist,
          '${occurrence.checklistDone}/${e.checklist.length}',
        ),
      if (e.reminders.isNotEmpty)
        _MetaIcon(Icons.notifications_none, 'Przypomnienie'),
      if (e.spanDays > 0)
        _MetaText(Icons.arrow_forward, 'do ${shortDate(occurrence.endDate)}'),
      if (overdue)
        Text(
          'PO TERMINIE',
          style: TextStyle(
            color: scheme.error,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            letterSpacing: 0.4,
          ),
        ),
    ];

    final Widget time;
    if (timeLabel != null) {
      time = Text(timeLabel!, style: _timeStyle(context, strong: true));
    } else if (occurrence.hasNoTime) {
      time = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cały', style: _timeStyle(context, strong: true)),
          Text('dzień', style: _timeStyle(context)),
        ],
      );
    } else {
      time = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatMinutes(e.startMinutes!),
            style: _timeStyle(context, strong: true),
          ),
          if (e.endMinutes != null)
            Text(formatMinutes(e.endMinutes!), style: _timeStyle(context)),
        ],
      );
    }

    return Semantics(
      button: true,
      label: '${e.title}, ${whenText(e, occurrence.startDate)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 52,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: time,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border(left: BorderSide(color: color, width: 4)),
                      boxShadow: overdue
                          ? [BoxShadow(color: scheme.error, spreadRadius: 1.5)]
                          : null,
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (e.isTask) ...[
                              _TaskCheck(
                                done: done,
                                color: color,
                                onTap: onToggleDone,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                e.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  decoration: done
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: done
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 10,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: meta,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _timeStyle(BuildContext context, {bool strong = false}) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: strong ? 13 : 12,
      height: 1.35,
      fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
      color: strong ? scheme.onSurface : scheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

/// Inicjał partnera dla wspólnego wpisu, który dodał partner. Null dla własnych i lokalnych.
String? partnerInitial(WidgetRef ref, Entry e) {
  if (e.isLocal || e.createdBy == null) return null;
  if (e.createdBy == ref.read(currentUidProvider)) return null;
  final name = ref.read(memberProfilesProvider)[e.createdBy]?.name ?? '';
  return name.isEmpty ? 'P' : name.characters.first.toUpperCase();
}

class _PartnerBadge extends StatelessWidget {
  const _PartnerBadge(this.initial);

  final String initial;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Dodane przez partnera',
    child: Container(
      width: 17,
      height: 17,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFC93C7B),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _TaskCheck extends StatelessWidget {
  const _TaskCheck({
    required this.done,
    required this.color,
    required this.onTap,
  });

  final bool done;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      checked: done,
      label: 'Zrobione',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? color : null,
              border: Border.all(
                color: done ? color : scheme.outline,
                width: 2,
              ),
            ),
            child: done
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

class _MetaIcon extends StatelessWidget {
  const _MetaIcon(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Icon(
    icon,
    size: 14,
    semanticLabel: label,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

class _MetaText extends StatelessWidget {
  const _MetaText(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }
}
