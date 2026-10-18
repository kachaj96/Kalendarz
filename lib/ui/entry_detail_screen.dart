import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/entry_actions.dart';
import '../domain/dates.dart';
import '../domain/entry.dart';
import '../domain/occurrence.dart';
import '../providers_calendar.dart';
import 'format.dart';
import 'navigation.dart';

class EntryDetailScreen extends ConsumerWidget {
  const EntryDetailScreen({
    super.key,
    required this.entryId,
    required this.occurrenceStart,
  });

  final String entryId;
  final DateTime occurrenceStart;

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String body,
    String action,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Entry? entry;
    for (final e in ref.watch(entriesProvider)) {
      if (e.id == entryId) entry = e;
    }
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Tego wpisu już nie ma.')),
      );
    }

    final e = entry;
    final scheme = Theme.of(context).colorScheme;
    final actions = ref.read(entryActionsProvider);
    final now = ref.watch(clockProvider)();
    final cat = ref.watch(categoryByIdProvider)[e.categoryId];
    final color = Color(cat?.color ?? 0xFF5F6B80);
    // Wpis bez powtarzania ma jedno wystąpienie, więc po zmianie daty w formularzu pokazujemy nową.
    final start = e.isRecurring ? occurrenceStart : e.date;
    final occ = Occurrence(e, start, addDays(start, e.spanDays));
    final overdue =
        e.isTask &&
        !e.isRecurring &&
        occ.endDate.isBefore(dateOnly(now)) &&
        !occ.isDone;

    final when = e.spanDays > 0
        ? '${shortDate(occ.startDate)} - ${shortDate(occ.endDate)}'
        : fullDate(occ.startDate);

    Widget row(IconData icon, String title, {String? sub, Widget? trailing}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (sub != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          sub,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Edytuj',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openEntryForm(context, entry: e),
          ),
        ],
      ),
      body: ListView(
        children: [
          Container(
            color: color,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (cat?.name ?? 'Inne').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  e.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Badge(
                      icon: e.isLocal
                          ? Icons.lock_outline
                          : Icons.people_outline,
                      text: e.isLocal ? 'Tylko na tym telefonie' : 'Wspólny',
                    ),
                    _Badge(text: e.isTask ? 'Zadanie' : 'Wydarzenie'),
                  ],
                ),
              ],
            ),
          ),
          if (overdue)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  scheme.error.withValues(alpha: 0.1),
                  scheme.surfaceContainerLowest,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: scheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Po terminie od ${dayMonth(occ.endDate)}',
                      style: TextStyle(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => actions.toggleDone(e, occ.startDate),
                    child: const Text('Odhacz'),
                  ),
                ],
              ),
            ),
          row(
            Icons.schedule,
            when,
            sub: whenText(e, occ.startDate),
            trailing: e.isTask
                ? Checkbox(
                    shape: const CircleBorder(),
                    value: occ.isDone,
                    onChanged: (_) => actions.toggleDone(e, occ.startDate),
                  )
                : null,
          ),
          const Divider(height: 1),
          row(
            Icons.repeat,
            repeatDescription(e),
            sub: e.isRecurring
                ? 'Odhaczenia i lista dotyczą tylko tego dnia.'
                : null,
          ),
          const Divider(height: 1),
          row(
            Icons.notifications_none,
            e.reminders.isEmpty
                ? 'Bez przypomnienia'
                : (e.reminders.toList()..sort()).map(reminderLabel).join(', '),
            sub: e.isLocal
                ? 'Przypomni tylko ten telefon.'
                : 'Przypomnienie dostajecie oboje, każde na swoim telefonie.',
          ),
          if (e.description.trim().isNotEmpty) ...[
            const Divider(height: 1),
            row(Icons.notes, e.description.trim()),
          ],
          if (e.checklist.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: Row(
                children: [
                  Icon(Icons.checklist, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 14),
                  const Text(
                    'Lista',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: occ.checklistDone / e.checklist.length,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${occ.checklistDone}/${e.checklist.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            for (final item in e.checklist)
              CheckboxListTile(
                key: ValueKey('check-${item.id}'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                value: occ.checkedItems.contains(item.id),
                onChanged: (_) =>
                    actions.toggleCheck(e, occ.startDate, item.id),
                title: Text(
                  item.text,
                  style: TextStyle(
                    decoration: occ.checkedItems.contains(item.id)
                        ? TextDecoration.lineThrough
                        : null,
                    color: occ.checkedItems.contains(item.id)
                        ? scheme.onSurfaceVariant
                        : null,
                  ),
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Text(
              _authorLine(e, ref),
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (e.isRecurring) ...[
                  OutlinedButton(
                    onPressed: () async {
                      await actions.skip(e, occ.startDate);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Pomiń ten dzień'),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(
                      color: scheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                  onPressed: () async {
                    final ok = await _confirm(
                      context,
                      e.isRecurring ? 'Usunąć całą serię?' : 'Usunąć wpis?',
                      e.isRecurring
                          ? 'Zniknie każde wystąpienie tego wpisu, także te w przeszłości.'
                          : 'Tego nie da się cofnąć.',
                      'Usuń',
                    );
                    if (!ok) return;
                    await actions.delete(e);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Text(e.isRecurring ? 'Usuń całą serię' : 'Usuń wpis'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _authorLine(Entry e, WidgetRef ref) {
  if (e.isLocal) return 'Zapisane tylko w tym telefonie. Partner go nie widzi.';
  final me = ref.read(currentUidProvider);
  if (e.createdBy == null || e.createdBy == me)
    return 'Wpis wspólny, dodany przez ciebie.';
  final name = ref.read(memberProfilesProvider)[e.createdBy]?.name;
  return 'Wpis wspólny, dodał(a): ${name ?? 'partner'}.';
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
