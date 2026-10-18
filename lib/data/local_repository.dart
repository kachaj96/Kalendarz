import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/category.dart';
import '../domain/dates.dart';
import '../domain/entry.dart';
import 'local_store.dart';

final localStoreProvider = Provider<LocalStore>((ref) => FileLocalStore());

final localDataProvider = AsyncNotifierProvider<LocalDataNotifier, LocalData>(
  LocalDataNotifier.new,
);

/// Wpisy i kategorie lokalne. Każda zmiana od razu ląduje w pliku.
class LocalDataNotifier extends AsyncNotifier<LocalData> {
  @override
  Future<LocalData> build() => ref.read(localStoreProvider).load();

  LocalData get _current => state.value ?? const LocalData();

  Future<void> _commit(LocalData next) async {
    state = AsyncData(next);
    await ref.read(localStoreProvider).save(next);
  }

  Future<void> upsertEntry(Entry entry) {
    final list = [..._current.entries];
    final i = list.indexWhere((e) => e.id == entry.id);
    if (i == -1) {
      list.add(entry);
    } else {
      list[i] = entry;
    }
    return _commit(LocalData(entries: list, categories: _current.categories));
  }

  Future<void> deleteEntry(String id) => _commit(
    LocalData(
      entries: [
        for (final e in _current.entries)
          if (e.id != id) e,
      ],
      categories: _current.categories,
    ),
  );

  Future<void> _updateEntry(String id, Entry Function(Entry) change) {
    return _commit(
      LocalData(
        entries: [for (final e in _current.entries) e.id == id ? change(e) : e],
        categories: _current.categories,
      ),
    );
  }

  Future<void> toggleDone(String entryId, DateTime occurrenceStart) {
    final key = dateKey(occurrenceStart);
    return _updateEntry(entryId, (e) {
      final done = {...e.doneDates};
      done.contains(key) ? done.remove(key) : done.add(key);
      return e.copyWith(doneDates: done);
    });
  }

  /// Odhaczenie punktu listy. Gdy zadanie ma wszystkie punkty odhaczone, samo staje się zrobione.
  Future<void> toggleCheck(
    String entryId,
    DateTime occurrenceStart,
    String itemId,
  ) {
    final key = dateKey(occurrenceStart);
    return _updateEntry(entryId, (e) {
      final checks = {
        for (final x in e.checks.entries) x.key: {...x.value},
      };
      final set = checks.putIfAbsent(key, () => {});
      set.contains(itemId) ? set.remove(itemId) : set.add(itemId);
      if (set.isEmpty) checks.remove(key);

      var done = e.doneDates;
      if (e.isTask && e.checklist.isNotEmpty) {
        final allChecked = e.checklist.every((i) => set.contains(i.id));
        done = {...e.doneDates};
        allChecked ? done.add(key) : done.remove(key);
      }
      return e.copyWith(checks: checks, doneDates: done);
    });
  }

  /// "Pomiń ten dzień" dla wpisu powtarzalnego. Wpis bez powtarzania usuwamy w całości.
  Future<void> skipOccurrence(String entryId, DateTime occurrenceStart) {
    final key = dateKey(occurrenceStart);
    final entry = _current.entries.firstWhere((e) => e.id == entryId);
    if (!entry.isRecurring) return deleteEntry(entryId);
    return _updateEntry(
      entryId,
      (e) => e.copyWith(skipped: {...e.skipped, key}),
    );
  }

  Future<void> upsertCategory(Category category) {
    final list = [..._current.categories];
    final i = list.indexWhere((c) => c.id == category.id);
    if (i == -1) {
      list.add(category);
    } else {
      list[i] = category;
    }
    return _commit(LocalData(entries: _current.entries, categories: list));
  }

  /// Usunięcie kategorii lokalnej: jej wpisy przechodzą do "Inne".
  Future<void> deleteCategory(String id) => _commit(
    LocalData(
      entries: [
        for (final e in _current.entries)
          e.categoryId == id ? e.copyWith(categoryId: fallbackCategoryId) : e,
      ],
      categories: [
        for (final c in _current.categories)
          if (c.id != id) c,
      ],
    ),
  );
}
