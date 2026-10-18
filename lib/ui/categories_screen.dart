import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/entry_actions.dart';
import '../domain/category.dart';
import '../providers_calendar.dart';

/// Okno tworzenia i edycji kategorii: nazwa, jeden z 12 kolorów i (przy nowej) zasięg.
/// Zwraca zapisaną kategorię albo null po anulowaniu.
Future<Category?> showCategoryDialog(
  BuildContext context, {
  Category? existing,
  bool local = false,
  bool lockScope = false,
  bool sharedAvailable = true,
}) {
  return showDialog<Category>(
    context: context,
    builder: (_) => _CategoryDialog(
      existing: existing,
      initialLocal: existing?.isLocal ?? (local || !sharedAvailable),
      canChooseScope: existing == null && !lockScope && sharedAvailable,
    ),
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({
    this.existing,
    required this.initialLocal,
    required this.canChooseScope,
  });

  final Category? existing;
  final bool initialLocal;
  final bool canChooseScope;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late int _color = widget.existing?.color ?? categoryPalette.first;
  late bool _local = widget.initialLocal;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Wpisz nazwę kategorii.');
      return;
    }
    final base =
        widget.existing ??
        Category(
          id: const Uuid().v4(),
          name: name,
          color: _color,
          isLocal: _local,
        );
    Navigator.of(context).pop(base.copyWith(name: name, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Nowa kategoria' : 'Edytuj kategorię',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('category-name'),
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nazwa',
                errorText: _error,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in categoryPalette)
                  Semantics(
                    button: true,
                    selected: c == _color,
                    label: 'Kolor',
                    child: GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: c == _color
                              ? Border.all(color: scheme.onSurface, width: 3)
                              : null,
                        ),
                        child: c == _color
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.canChooseScope)
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.people_outline),
                    label: Text('Wspólna'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.lock_outline),
                    label: Text('Lokalna'),
                  ),
                ],
                selected: {_local},
                onSelectionChanged: (s) => setState(() => _local = s.first),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _local ? Icons.lock_outline : Icons.people_outline,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _local
                        ? 'Lokalna: tylko na tym telefonie i tylko dla wpisów lokalnych.'
                        : 'Wspólna: widzi ją partner, oboje możecie jej używać i ją zmieniać.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _save,
          child: const Text('Zapisz'),
        ),
      ],
    );
  }
}

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final entries = ref.watch(entriesProvider);
    final cats = ref.watch(categoriesProvider);
    final actions = ref.read(entryActionsProvider);
    final sharedAvailable = ref.watch(currentSpaceIdProvider) != null;
    final shared = cats.where((c) => !c.isLocal).toList();
    final local = cats.where((c) => c.isLocal).toList();

    int countFor(Category c) =>
        entries.where((e) => e.categoryId == c.id).length;

    Widget header(IconData icon, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    Future<void> confirmDelete(Category c) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Usunąć kategorię „${c.name}”?'),
          content: Text(
            c.isLocal ? 'Jej wpisy przejdą do kategorii „Inne”.' : 'Zniknie też u partnera. Wpisy z tej kategorii przejdą do „Inne”.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anuluj'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Usuń'),
            ),
          ],
        ),
      );
      if (ok == true) await actions.deleteCategory(c);
    }

    Widget tile(Category c) {
      final editable = c.isLocal || sharedAvailable;
      return ListTile(
        leading: CircleAvatar(radius: 8, backgroundColor: Color(c.color)),
        title: Text(
          c.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${countFor(c)} wpisów'),
        trailing: editable
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edytuj ${c.name}',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final updated = await showCategoryDialog(
                        context,
                        existing: c,
                      );
                      if (updated != null) await actions.saveCategory(updated);
                    },
                  ),
                  if (c.id != fallbackCategoryId)
                    IconButton(
                      tooltip: 'Usuń ${c.name}',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => confirmDelete(c),
                    ),
                ],
              )
            : null,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Kategorie')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
        children: [
          header(Icons.people_outline, 'Wspólne - widzi je partner'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(children: [for (final c in shared) tile(c)]),
          ),
          header(Icons.lock_outline, 'Lokalne - tylko ten telefon'),
          if (local.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Nie masz jeszcze własnych kategorii lokalnych.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(children: [for (final c in local) tile(c)]),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Nowa kategoria'),
            onPressed: () async {
              final created = await showCategoryDialog(
                context,
                sharedAvailable: sharedAvailable,
              );
              if (created != null) await actions.saveCategory(created);
            },
          ),
        ],
      ),
    );
  }
}
