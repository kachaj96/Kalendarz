import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalendarz/data/local_repository.dart';
import 'package:kalendarz/data/local_store.dart';
import 'package:kalendarz/domain/category.dart';
import 'package:kalendarz/domain/entry.dart';

Entry sample({
  String id = 'a',
  bool task = true,
  List<String> items = const [],
}) => Entry(
  id: id,
  type: task ? EntryType.task : EntryType.event,
  title: 'Zakupy',
  date: DateTime(2026, 10, 20),
  endDate: DateTime(2026, 10, 20),
  categoryId: 'zakupy',
  allDay: true,
  checklist: [for (final i in items) ChecklistItem(id: i, text: i)],
);

ProviderContainer containerWith(MemoryLocalStore store) {
  final c = ProviderContainer(
    overrides: [localStoreProvider.overrideWithValue(store)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test(
    'dodany wpis trafia do magazynu i da się go odczytać po restarcie',
    () async {
      final store = MemoryLocalStore();
      final c = containerWith(store);
      await c.read(localDataProvider.future);
      await c.read(localDataProvider.notifier).upsertEntry(sample());
      expect(store.data.entries.single.title, 'Zakupy');

      final c2 = containerWith(store);
      final loaded = await c2.read(localDataProvider.future);
      expect(loaded.entries.single.id, 'a');
    },
  );

  test(
    'odhaczenie wszystkich punktów kończy zadanie, odznaczenie je wznawia',
    () async {
      final store = MemoryLocalStore(
        LocalData(
          entries: [
            sample(items: ['m', 'c']),
          ],
        ),
      );
      final c = containerWith(store);
      await c.read(localDataProvider.future);
      final n = c.read(localDataProvider.notifier);
      final day = DateTime(2026, 10, 20);

      await n.toggleCheck('a', day, 'm');
      expect(store.data.entries.single.doneDates, isEmpty);
      await n.toggleCheck('a', day, 'c');
      expect(store.data.entries.single.doneDates, {'2026-10-20'});
      await n.toggleCheck('a', day, 'm');
      expect(store.data.entries.single.doneDates, isEmpty);
      expect(store.data.entries.single.checks['2026-10-20'], {'c'});
    },
  );

  test(
    'pominięcie dnia wpisu powtarzalnego zostawia wpis, bez powtarzania usuwa',
    () async {
      final rec = sample(id: 'r')
          .copyWith(recurrence: () => const Recurrence(freq: RepeatFreq.daily));
      final store = MemoryLocalStore(
        LocalData(
          entries: [
            rec,
            sample(id: 'one'),
          ],
        ),
      );
      final c = containerWith(store);
      await c.read(localDataProvider.future);
      final n = c.read(localDataProvider.notifier);

      await n.skipOccurrence('r', DateTime(2026, 10, 21));
      expect(store.data.entries.firstWhere((e) => e.id == 'r').skipped, {
        '2026-10-21',
      });
      await n.skipOccurrence('one', DateTime(2026, 10, 20));
      expect(store.data.entries.map((e) => e.id), ['r']);
    },
  );

  test('usunięcie kategorii lokalnej przenosi jej wpisy do Inne', () async {
    const cat = Category(
      id: 'moja',
      name: 'Moja',
      color: 0xFF2F6FDE,
      isLocal: true,
    );
    final e = sample().copyWith(categoryId: 'moja');
    final store = MemoryLocalStore(LocalData(entries: [e], categories: [cat]));
    final c = containerWith(store);
    await c.read(localDataProvider.future);

    await c.read(localDataProvider.notifier).deleteCategory('moja');
    expect(store.data.categories, isEmpty);
    expect(store.data.entries.single.categoryId, fallbackCategoryId);
  });

  group('FileLocalStore', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('kalendarz_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('zapis i odczyt', () async {
      final store = FileLocalStore(directory: dir);
      await store.save(LocalData(entries: [sample()]));
      final back = await FileLocalStore(directory: dir).load();
      expect(back.entries.single.title, 'Zakupy');
      expect(
        File('${dir.path}/kalendarz_local.json.tmp').existsSync(),
        isFalse,
      );
    });

    test('brak pliku to puste dane', () async {
      final back = await FileLocalStore(directory: dir).load();
      expect(back.entries, isEmpty);
    });

    test('uszkodzony plik jest odkładany na bok, a nie nadpisywany', () async {
      File('${dir.path}/kalendarz_local.json')
          .writeAsStringSync('{ to nie jest json');
      final back = await FileLocalStore(directory: dir).load();
      expect(back.entries, isEmpty);
      final names = dir.listSync().map((f) => f.uri.pathSegments.last).toList();
      expect(
        names.any((n) => n.startsWith('kalendarz_local.json.uszkodzony-')),
        isTrue,
      );
    });
  });
}
