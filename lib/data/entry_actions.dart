import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/category.dart';
import '../domain/dates.dart';
import '../domain/entry.dart';
import '../providers_calendar.dart';
import 'local_repository.dart';

final entryActionsProvider = Provider<EntryActions>((ref) => EntryActions(ref));

/// Wszystkie zmiany wpisów i kategorii przechodzą tędy: akcja sama wybiera, czy dotyczy
/// pamięci telefonu, czy wspólnej bazy, i przenosi wpis, gdy zmieniła się jego widoczność.
class EntryActions {
  EntryActions(this._ref);

  final Ref _ref;

  LocalDataNotifier get _local => _ref.read(localDataProvider.notifier);

  String get _spaceId {
    final id = _ref.read(currentSpaceIdProvider);
    if (id == null) throw StateError('Brak wspólnego kalendarza.');
    return id;
  }

  Future<void> save(Entry entry, {Entry? previous}) async {
    final store = _ref.read(sharedStoreProvider);
    if (entry.isLocal) {
      await _local.upsertEntry(entry);
      if (previous != null && !previous.isLocal) {
        await store.deleteEntry(_spaceId, previous.id);
      }
      return;
    }
    final movedFromLocal = previous != null && previous.isLocal;
    final withAuthor = entry.createdBy == null
        ? entry.copyWith(createdBy: _ref.read(currentUidProvider))
        : entry;
    await store.putEntry(
      _spaceId,
      withAuthor,
      previous: movedFromLocal ? null : previous,
    );
    if (movedFromLocal) await _local.deleteEntry(previous.id);
  }

  Future<void> delete(Entry entry) => entry.isLocal
      ? _local.deleteEntry(entry.id)
      : _ref.read(sharedStoreProvider).deleteEntry(_spaceId, entry.id);

  Future<void> toggleDone(Entry entry, DateTime occurrenceStart) {
    if (entry.isLocal) return _local.toggleDone(entry.id, occurrenceStart);
    final key = dateKey(occurrenceStart);
    return _ref
        .read(sharedStoreProvider)
        .setDone(_spaceId, entry.id, key, !entry.doneDates.contains(key));
  }

  /// Gdy zadanie ma wszystkie punkty odhaczone, samo staje się zrobione (i odwrotnie).
  Future<void> toggleCheck(
    Entry entry,
    DateTime occurrenceStart,
    String itemId,
  ) async {
    if (entry.isLocal) {
      return _local.toggleCheck(entry.id, occurrenceStart, itemId);
    }
    final key = dateKey(occurrenceStart);
    final store = _ref.read(sharedStoreProvider);
    final checked = {...?entry.checks[key]};
    final nowChecked = !checked.contains(itemId);
    nowChecked ? checked.add(itemId) : checked.remove(itemId);
    await store.setChecked(_spaceId, entry.id, key, itemId, nowChecked);
    if (entry.isTask && entry.checklist.isNotEmpty) {
      final allChecked = entry.checklist.every((i) => checked.contains(i.id));
      if (allChecked != entry.doneDates.contains(key)) {
        await store.setDone(_spaceId, entry.id, key, allChecked);
      }
    }
  }

  Future<void> skip(Entry entry, DateTime occurrenceStart) {
    if (entry.isLocal) return _local.skipOccurrence(entry.id, occurrenceStart);
    if (!entry.isRecurring) return delete(entry);
    return _ref
        .read(sharedStoreProvider)
        .addSkipped(_spaceId, entry.id, dateKey(occurrenceStart));
  }

  Future<void> saveCategory(Category category) => category.isLocal
      ? _local.upsertCategory(category)
      : _ref.read(sharedStoreProvider).putCategory(_spaceId, category);

  Future<void> deleteCategory(Category category) => category.isLocal
      ? _local.deleteCategory(category.id)
      : _ref.read(sharedStoreProvider).deleteCategory(_spaceId, category.id);
}
