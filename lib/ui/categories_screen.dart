import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/local_repository.dart';
import '../domain/category.dart';
import '../providers_calendar.dart';

/// Okno tworzenia i edycji kategorii: nazwa i jeden z 12 kolorów.
/// Zwraca zapisaną kategorię albo null po anulowaniu.
Future<Category?> showCategoryDialog(
  BuildContext context, {
  Category? existing,
}) {
  return showDialog<Category>(
    context: context,
    builder: (_) => _CategoryDialog(existing: existing),
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.existing});

  final Category? existing;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late int _color = widget.existing?.color ?? categoryPalette.first;
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
          isLocal: true,
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
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kategoria lokalna: tylko na tym telefonie i tylko dla wpisów lokalnych.',
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
    final notifier = ref.read(localDataProvider.notifier);
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

    Widget tile(Category c, {bool editable = false}) => ListTile(
      leading: CircleAvatar(radius: 8, backgroundColor: Color(c.color)),
      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                    if (updated != null) await notifier.upsertCategory(updated);
                  },
                ),
                IconButton(
                  tooltip: 'Usuń ${c.name}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Usunąć kategorię „${c.name}”?'),
                        content: const Text(
                          'Jej wpisy przejdą do kategorii „Inne”.',
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
                    if (ok == true) await notifier.deleteCategory(c.id);
                  },
                ),
              ],
            )
          : null,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Kategorie')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
        children: [
          header(Icons.people_outline, 'Wspólne'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(children: [for (final c in shared) tile(c)]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Kategorie wspólne będzie można dodawać i zmieniać po włączeniu współdzielenia wpisów.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
          header(Icons.lock_outline, 'Lokalne - tylko ten telefon'),
          if (local.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Nie masz jeszcze własnych kategorii.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [for (final c in local) tile(c, editable: true)],
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Nowa kategoria'),
            onPressed: () async {
              final created = await showCategoryDialog(context);
              if (created != null) await notifier.upsertCategory(created);
            },
          ),
        ],
      ),
    );
  }
}
