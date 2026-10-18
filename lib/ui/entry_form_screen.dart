import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/entry_actions.dart';
import '../domain/category.dart';
import '../domain/dates.dart';
import '../domain/entry.dart';
import '../providers_calendar.dart';
import 'categories_screen.dart';
import 'format.dart';

enum _EndMode { never, until, count }

class _Item {
  _Item(String text, {String? id})
    : id = id ?? const Uuid().v4(),
      controller = TextEditingController(text: text),
      focus = FocusNode();

  final String id;
  final TextEditingController controller;
  final FocusNode focus;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

/// Formularz nowego wpisu albo edycji istniejącego (edycja zmienia całą serię).
class EntryFormScreen extends ConsumerStatefulWidget {
  const EntryFormScreen({super.key, this.entry, this.initialDate});

  final Entry? entry;
  final DateTime? initialDate;

  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _items = <_Item>[];

  EntryType _type = EntryType.event;
  bool _allDay = false;
  late DateTime _startDate;
  late DateTime _endDate;
  int _startMin = 9 * 60;
  int _endMin = 10 * 60;

  RepeatFreq? _freq;
  int _interval = 1;
  final _weekdays = <int>{};
  _EndMode _endMode = _EndMode.never;
  DateTime? _until;
  int _count = 10;

  final _reminders = <int>{};
  String _categoryId = fallbackCategoryId;
  bool _local = true;

  String? _titleError;
  bool _dirty = false;

  bool get _editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    if (e == null) {
      final now = ref.read(clockProvider)();
      final base = dateOnly(widget.initialDate ?? now);
      // Domyślnie wpis wspólny, o ile jest wspólny kalendarz.
      _local = ref.read(currentSpaceIdProvider) == null;
      _startDate = base;
      _endDate = base;
      if (sameDay(base, now)) {
        final next = (now.hour + 1).clamp(0, 22);
        _startMin = next * 60;
        _endMin = _startMin + 60;
      }
      return;
    }
    _type = e.type;
    _title.text = e.title;
    _description.text = e.description;
    _allDay = e.allDay || e.startMinutes == null;
    _startDate = e.date;
    _endDate = e.endDate;
    _startMin = e.startMinutes ?? _startMin;
    _endMin = e.endMinutes ?? _endMin;
    final r = e.recurrence;
    if (r != null) {
      _freq = r.freq;
      _interval = r.interval;
      _weekdays.addAll(r.weekdays);
      if (r.until != null) {
        _endMode = _EndMode.until;
        _until = r.until;
      } else if (r.count != null) {
        _endMode = _EndMode.count;
        _count = r.count!;
      }
    }
    _reminders.addAll(e.reminders);
    _categoryId = e.categoryId;
    _local = e.isLocal;
    for (final c in e.checklist) {
      _items.add(_Item(c.text, id: c.id));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  void _change(VoidCallback fn) => setState(() {
    _dirty = true;
    fn();
  });

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _change(() {
      final d = dateOnly(picked);
      if (start) {
        final span = daysBetween(_startDate, _endDate);
        _startDate = d;
        _endDate = addDays(d, span < 0 ? 0 : span);
      } else {
        _endDate = d.isBefore(_startDate) ? _startDate : d;
      }
      _fixEnd();
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _startMin : _endMin;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    _change(() {
      final m = picked.hour * 60 + picked.minute;
      if (start) {
        final length = _endMin - _startMin;
        _startMin = m;
        if (sameDay(_startDate, _endDate)) {
          _endMin = (m + (length > 0 ? length : 60)).clamp(m + 1, 1439);
        }
      } else {
        _endMin = m;
      }
      _fixEnd();
    });
  }

  /// W jednym dniu koniec nie może być przed początkiem.
  void _fixEnd() {
    if (!_allDay && sameDay(_startDate, _endDate) && _endMin <= _startMin) {
      _endMin = (_startMin + 60).clamp(_startMin + 1, 1439);
    }
  }

  Future<void> _pickUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _until ?? addDays(_startDate, 30),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) _change(() => _until = dateOnly(picked));
  }

  Future<void> _newCategory() async {
    final created = await showCategoryDialog(
      context,
      local: _local,
      lockScope: true,
    );
    if (created == null) return;
    await ref.read(entryActionsProvider).saveCategory(created);
    _change(() => _categoryId = created.id);
  }

  /// Wspólny wpis zamieniony na lokalny zniknie partnerowi, więc pytamy.
  Future<void> _makeLocal() async {
    if (_local) return;
    final wasShared = widget.entry != null && !widget.entry!.isLocal;
    if (wasShared) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Zrobić wpis tylko dla siebie?'),
          content: const Text(
            'Po zapisaniu partner przestanie go widzieć, a wpis zostanie tylko na tym telefonie.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anuluj'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tak, tylko ja'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    _change(() => _local = true);
  }

  void _addItem() {
    final item = _Item('');
    _change(() => _items.add(item));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) item.focus.requestFocus();
    });
  }

  Entry? _build() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Wpisz tytuł.');
      return null;
    }
    if (_endDate.isBefore(_startDate)) {
      _snack('Koniec jest przed początkiem.');
      return null;
    }
    if (_freq != null && _endMode == _EndMode.until) {
      if (_until == null) {
        _snack('Wybierz datę końca powtarzania.');
        return null;
      }
      if (_until!.isBefore(_startDate)) {
        _snack('Powtarzanie kończy się przed pierwszym wpisem.');
        return null;
      }
    }

    final old = widget.entry;
    final recurrence = _freq == null
        ? null
        : Recurrence(
            freq: _freq!,
            interval: _interval,
            weekdays: _freq == RepeatFreq.weekly
                ? (_weekdays.isEmpty ? {_startDate.weekday} : {..._weekdays})
                : const {},
            until: _endMode == _EndMode.until ? _until : null,
            count: _endMode == _EndMode.count ? _count : null,
          );

    final items = [
      for (final i in _items)
        if (i.controller.text.trim().isNotEmpty)
          ChecklistItem(id: i.id, text: i.controller.text.trim()),
    ];

    var doneDates = old?.doneDates ?? const <String>{};
    var checks = old?.checks ?? const <String, Set<String>>{};
    var skipped = old?.skipped ?? const <String>{};
    if (old != null &&
        !old.isRecurring &&
        recurrence == null &&
        old.date != _startDate) {
      // Wpis bez powtarzania zmienił dzień: odhaczenia przechodzą na nowy klucz daty.
      final oldKey = dateKey(old.date);
      final newKey = dateKey(_startDate);
      doneDates = doneDates.contains(oldKey) ? {newKey} : <String>{};
      checks = checks.containsKey(oldKey)
          ? {newKey: checks[oldKey]!}
          : <String, Set<String>>{};
    }
    if (old != null && old.isRecurring != (recurrence != null)) {
      skipped = const {};
    }

    return Entry(
      id: old?.id ?? const Uuid().v4(),
      type: _type,
      title: title,
      description: _description.text.trim(),
      date: _startDate,
      endDate: _endDate,
      allDay: _allDay,
      startMinutes: _allDay ? null : _startMin,
      endMinutes: _allDay ? null : _endMin,
      recurrence: recurrence,
      reminders: (_reminders.toList()..sort()),
      categoryId: _categoryId,
      checklist: items,
      isLocal: _local,
      skipped: skipped,
      doneDates: doneDates,
      checks: checks,
    );
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    final entry = _build();
    if (entry == null) return;
    await ref.read(entryActionsProvider).save(entry, previous: widget.entry);
    if (!mounted) return;
    setState(() => _dirty = false);
    Navigator.of(context).pop();
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odrzucić zmiany?'),
        content: const Text('Wpis nie został zapisany.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Wróć do edycji'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Odrzuć'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _dirty = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cats = ref
        .watch(categoriesProvider)
        .where((c) => _local || !c.isLocal)
        .toList();
    final multiDay = !sameDay(_startDate, _endDate);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Zamknij',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(_editing ? 'Edytuj wpis' : 'Nowy wpis'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const Key('save-entry'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: _save,
                child: const Text('Zapisz'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SegmentedButton<EntryType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: EntryType.event,
                    icon: Icon(Icons.event_outlined),
                    label: Text('Wydarzenie'),
                  ),
                  ButtonSegment(
                    value: EntryType.task,
                    icon: Icon(Icons.checklist),
                    label: Text('Zadanie'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => _change(() => _type = s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                key: const Key('entry-title'),
                controller: _title,
                autofocus: !_editing,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'Tytuł',
                  errorText: _titleError,
                  border: InputBorder.none,
                ),
                onChanged: (_) => _change(() => _titleError = null),
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18),
              secondary: const Icon(Icons.schedule),
              title: Text(
                _type == EntryType.task ? 'Bez godziny' : 'Cały dzień',
              ),
              value: _allDay,
              onChanged: (v) => _change(() {
                _allDay = v;
                _fixEnd();
              }),
            ),
            _DateRow(
              label: 'Początek',
              date: _startDate,
              minutes: _allDay ? null : _startMin,
              onDate: () => _pickDate(start: true),
              onTime: () => _pickTime(start: true),
            ),
            _DateRow(
              label: 'Koniec',
              date: _endDate,
              minutes: _allDay ? null : _endMin,
              onDate: () => _pickDate(start: false),
              onTime: () => _pickTime(start: false),
            ),
            if (multiDay && !_allDay)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Text(
                  'Wpis trwa przez kilka dni.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const Divider(height: 1),
            _Section(
              icon: Icons.repeat,
              title: 'Powtarzaj',
              child: _repeatEditor(scheme),
            ),
            _Section(
              icon: Icons.notifications_none,
              title: 'Przypomnienia',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final p in reminderPresets)
                        FilterChip(
                          label: Text(p.$2),
                          selected: _reminders.contains(p.$1),
                          onSelected: (v) => _change(
                            () => v
                                ? _reminders.add(p.$1)
                                : _reminders.remove(p.$1),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _local ? 'Przypomni tylko ten telefon.' : 'Partner dostanie to samo przypomnienie na swoim telefonie.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              icon: Icons.sell_outlined,
              title: 'Kategoria',
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in cats)
                    ChoiceChip(
                      key: Key('cat-${c.id}'),
                      avatar: CircleAvatar(
                        radius: 6,
                        backgroundColor: Color(c.color),
                      ),
                      label: Text(c.name),
                      selected: _categoryId == c.id,
                      onSelected: (_) => _change(() => _categoryId = c.id),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Nowa'),
                    onPressed: _newCategory,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Icon(Icons.notes, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      key: const Key('entry-description'),
                      controller: _description,
                      minLines: 1,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Opis',
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => _change(() {}),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _Section(
              icon: Icons.checklist,
              title: 'Lista punktów',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorderItem: (from, to) => _change(() {
                      final item = _items.removeAt(from);
                      _items.insert(to, item);
                    }),
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Row(
                          key: ValueKey(_items[i].id),
                          children: [
                            ReorderableDragStartListener(
                              index: i,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.drag_indicator,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                key: Key('item-$i'),
                                controller: _items[i].controller,
                                focusNode: _items[i].focus,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  hintText: 'Punkt ${i + 1}',
                                ),
                                onChanged: (_) => _change(() {}),
                                onSubmitted: (_) => _addItem(),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Usuń punkt',
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  _change(() => _items.removeAt(i).dispose()),
                            ),
                          ],
                        ),
                    ],
                  ),
                  TextButton.icon(
                    key: const Key('add-item'),
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Dodaj punkt'),
                  ),
                ],
              ),
            ),
            _Section(
              icon: Icons.people_outline,
              title: 'Kto to widzi',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _VisibilityCard(
                      icon: Icons.people_outline,
                      title: 'Wspólny',
                      subtitle: 'Partner widzi, może edytować i dostaje przypomnienie.',
                      selected: !_local,
                      enabled: ref.watch(currentSpaceIdProvider) != null,
                      onTap: () => _change(() {
                        _local = false;
                        final cat = ref.read(categoryByIdProvider)[_categoryId];
                        if (cat == null || cat.isLocal) {
                          _categoryId = fallbackCategoryId;
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _VisibilityCard(
                      icon: Icons.lock_outline,
                      title: 'Tylko ja',
                      subtitle: 'Zostaje w pamięci tego telefonu. Bez kopii zapasowej.',
                      selected: _local,
                      onTap: _makeLocal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _repeatEditor(ColorScheme scheme) {
    const options = <(RepeatFreq?, String)>[
      (null, 'Nie'),
      (RepeatFreq.daily, 'Codziennie'),
      (RepeatFreq.weekly, 'Co tydzień'),
      (RepeatFreq.monthly, 'Co miesiąc'),
      (RepeatFreq.yearly, 'Co rok'),
    ];
    final unit = switch (_freq) {
      RepeatFreq.daily => 'dni',
      RepeatFreq.weekly => 'tyg.',
      RepeatFreq.monthly => 'mies.',
      RepeatFreq.yearly => 'lat',
      null => '',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final o in options)
              ChoiceChip(
                key: Key('repeat-${o.$1?.name ?? 'none'}'),
                label: Text(o.$2),
                selected: _freq == o.$1,
                onSelected: (_) => _change(() {
                  _freq = o.$1;
                  if (o.$1 == null) {
                    _interval = 1;
                    _endMode = _EndMode.never;
                  }
                }),
              ),
          ],
        ),
        if (_freq != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Co'),
              IconButton(
                tooltip: 'Mniej',
                onPressed: _interval > 1
                    ? () => _change(() => _interval--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$_interval',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                tooltip: 'Więcej',
                onPressed: _interval < 99
                    ? () => _change(() => _interval++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
              Text(unit),
            ],
          ),
          if (_freq == RepeatFreq.weekly)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    Semantics(
                      label: weekdayName(DateTime(2026, 10, 18 + d)),
                      selected: _weekdays.contains(d),
                      button: true,
                      child: ChoiceChip(
                        key: Key('weekday-$d'),
                        showCheckmark: false,
                        padding: EdgeInsets.zero,
                        label: SizedBox(
                          width: 22,
                          child: Center(child: Text(weekdayLetter[d - 1])),
                        ),
                        selected: _weekdays.contains(d),
                        shape: const CircleBorder(),
                        onSelected: (v) => _change(
                          () => v ? _weekdays.add(d) : _weekdays.remove(d),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Bez końca'),
                selected: _endMode == _EndMode.never,
                onSelected: (_) => _change(() => _endMode = _EndMode.never),
              ),
              ChoiceChip(
                label: const Text('Do daty'),
                selected: _endMode == _EndMode.until,
                onSelected: (_) {
                  _change(() => _endMode = _EndMode.until);
                  if (_until == null) _pickUntil();
                },
              ),
              ChoiceChip(
                label: const Text('Po liczbie razy'),
                selected: _endMode == _EndMode.count,
                onSelected: (_) => _change(() => _endMode = _EndMode.count),
              ),
            ],
          ),
          if (_endMode == _EndMode.until)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: _pickUntil,
                child: Text(
                  _until == null
                      ? 'Wybierz datę'
                      : '${dayMonth(_until!)} ${_until!.year}',
                ),
              ),
            ),
          if (_endMode == _EndMode.count)
            Row(
              children: [
                IconButton(
                  tooltip: 'Mniej razy',
                  onPressed: _count > 1 ? () => _change(() => _count--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_count',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: 'Więcej razy',
                  onPressed: _count < 999
                      ? () => _change(() => _count++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const Text('razy'),
              ],
            ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.date,
    required this.minutes,
    required this.onDate,
    required this.onTime,
  });

  final String label;
  final DateTime date;
  final int? minutes;
  final VoidCallback onDate;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget chip(String text, VoidCallback onTap, String semantics) => Semantics(
      button: true,
      label: '$label: $semantics',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      child: Row(
        children: [
          Icon(Icons.event_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          chip(shortDate(date), onDate, 'data'),
          if (minutes != null) ...[
            const SizedBox(width: 8),
            chip(formatMinutes(minutes!), onTime, 'godzina'),
          ],
        ],
      ),
    );
  }
}

class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '$title. $subtitle',
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? scheme.primary.withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
