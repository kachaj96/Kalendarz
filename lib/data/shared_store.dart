import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/category.dart';
import '../domain/entry.dart';

/// Dokument kategorii wspólnej. Kategorie domyślne istnieją w kodzie, a dokument
/// o tym samym id je nadpisuje (zmiana nazwy lub koloru) albo ukrywa (`deleted`).
class SharedCategoryDoc {
  const SharedCategoryDoc({
    required this.id,
    this.name,
    this.color,
    this.deleted = false,
  });

  final String id;
  final String? name;
  final int? color;
  final bool deleted;
}

/// Kategorie wspólne: domyślne z kodu z nałożonymi zmianami z bazy, potem własne wg nazwy.
List<Category> mergeSharedCategories(List<SharedCategoryDoc> docs) {
  final byId = {for (final d in docs) d.id: d};
  final out = <Category>[];
  for (final c in defaultCategories) {
    final d = byId[c.id];
    if (d == null) {
      out.add(c);
    } else if (!d.deleted || c.id == fallbackCategoryId) {
      out.add(c.copyWith(name: d.name, color: d.color));
    }
  }
  final defaultIds = {for (final c in defaultCategories) c.id};
  final extra = [
    for (final d in docs)
      if (!defaultIds.contains(d.id) &&
          !d.deleted &&
          d.name != null &&
          d.color != null)
        Category(id: d.id, name: d.name!, color: d.color!),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return [...out, ...extra];
}

/// Wspólne wpisy i kategorie jednej przestrzeni.
abstract class SharedStore {
  Stream<List<Entry>> watchEntries(String spaceId);
  Stream<List<SharedCategoryDoc>> watchCategories(String spaceId);

  /// Jednorazowy odczyt (praca w tle): najpierw serwer, a bez internetu pamięć podręczna.
  Future<List<Entry>> fetchEntries(String spaceId);
  Future<List<SharedCategoryDoc>> fetchCategories(String spaceId);

  /// Zapis całego wpisu. Przy edycji (`previous` != null) odhaczenia, zrobione dni i pominięcia
  /// są nadpisywane tylko wtedy, gdy formularz je zmienił, żeby nie skasować tego, co w tym
  /// czasie odhaczył partner.
  Future<void> putEntry(String spaceId, Entry entry, {Entry? previous});
  Future<void> deleteEntry(String spaceId, String entryId);
  Future<void> setDone(String spaceId, String entryId, String key, bool done);
  Future<void> setChecked(
    String spaceId,
    String entryId,
    String key,
    String itemId,
    bool checked,
  );
  Future<void> addSkipped(String spaceId, String entryId, String key);
  Future<void> putCategory(String spaceId, Category category);

  /// Usuwa kategorię i przenosi jej wpisy do "Inne".
  Future<void> deleteCategory(String spaceId, String categoryId);
}

bool _sameSet<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

bool _sameChecks(Map<String, Set<String>> a, Map<String, Set<String>> b) =>
    a.length == b.length &&
    a.entries.every((e) => b[e.key] != null && _sameSet(e.value, b[e.key]!));

Map<String, dynamic> _entryFields(Entry e, {Entry? previous}) {
  final json = e.toJson()
    ..remove('id')
    ..['isLocal'] = false;
  // toJson pomija puste pola, a przy częściowym zapisie stara wartość by została (np. powtarzanie).
  for (final key in ['startMinutes', 'endMinutes', 'recurrence', 'createdBy']) {
    json.putIfAbsent(key, () => null);
  }
  if (previous != null) {
    if (_sameSet(e.doneDates, previous.doneDates)) json.remove('doneDates');
    if (_sameSet(e.skipped, previous.skipped)) json.remove('skipped');
    if (_sameChecks(e.checks, previous.checks)) json.remove('checks');
  }
  return json;
}

Entry _entryFromDoc(String id, Map<String, dynamic> data) =>
    Entry.fromJson({...data, 'id': id, 'isLocal': false});

class FirestoreSharedStore implements SharedStore {
  FirestoreSharedStore(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _entries(String spaceId) =>
      _db.collection('spaces').doc(spaceId).collection('entries');
  CollectionReference<Map<String, dynamic>> _categories(String spaceId) =>
      _db.collection('spaces').doc(spaceId).collection('categories');

  @override
  Stream<List<Entry>> watchEntries(String spaceId) => _entries(spaceId)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            if (_tryParse(d.id, d.data()) case final Entry e) e,
        ],
      );

  /// Uszkodzony dokument (np. z przyszłej wersji aplikacji) nie może wywrócić całego kalendarza.
  Entry? _tryParse(String id, Map<String, dynamic> data) {
    try {
      return _entryFromDoc(id, data);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<SharedCategoryDoc>> watchCategories(String spaceId) =>
      _categories(spaceId).snapshots().map(_categoryDocs);

  @override
  Future<List<Entry>> fetchEntries(String spaceId) async {
    final s = await _entries(spaceId).get();
    return [
      for (final d in s.docs)
        if (_tryParse(d.id, d.data()) case final Entry e) e,
    ];
  }

  @override
  Future<List<SharedCategoryDoc>> fetchCategories(String spaceId) async =>
      _categoryDocs(await _categories(spaceId).get());

  List<SharedCategoryDoc> _categoryDocs(
    QuerySnapshot<Map<String, dynamic>> s,
  ) => [
    for (final d in s.docs)
      SharedCategoryDoc(
        id: d.id,
        name: d.data()['name'] as String?,
        color: d.data()['color'] as int?,
        deleted: d.data()['deleted'] as bool? ?? false,
      ),
  ];

  @override
  Future<void> putEntry(String spaceId, Entry entry, {Entry? previous}) {
    final ref = _entries(spaceId).doc(entry.id);
    final fields = _entryFields(entry, previous: previous);
    if (previous == null) return ref.set(fields);
    // Pola mapy nadpisujemy w całości, a nie scalamy, żeby usunięte klucze naprawdę znikały.
    return ref.set(fields, SetOptions(mergeFields: fields.keys.toList()));
  }

  @override
  Future<void> deleteEntry(String spaceId, String entryId) =>
      _entries(spaceId).doc(entryId).delete();

  @override
  Future<void> setDone(String spaceId, String entryId, String key, bool done) =>
      _entries(spaceId).doc(entryId).update({
        'doneDates': done
            ? FieldValue.arrayUnion([key])
            : FieldValue.arrayRemove([key]),
      });

  @override
  Future<void> setChecked(
    String spaceId,
    String entryId,
    String key,
    String itemId,
    bool checked,
  ) => _entries(spaceId).doc(entryId).update({
    FieldPath(['checks', key]): checked
        ? FieldValue.arrayUnion([itemId])
        : FieldValue.arrayRemove([itemId]),
  });

  @override
  Future<void> addSkipped(String spaceId, String entryId, String key) =>
      _entries(spaceId).doc(entryId).update({
        'skipped': FieldValue.arrayUnion([key]),
      });

  @override
  Future<void> putCategory(String spaceId, Category category) =>
      _categories(spaceId).doc(category.id).set({
        'name': category.name,
        'color': category.color,
        'deleted': false,
      });

  @override
  Future<void> deleteCategory(String spaceId, String categoryId) async {
    final batch = _db.batch();
    final affected = await _entries(spaceId)
        .where('categoryId', isEqualTo: categoryId)
        .get();
    for (final d in affected.docs) {
      batch.update(d.reference, {'categoryId': fallbackCategoryId});
    }
    batch.set(_categories(spaceId).doc(categoryId), {'deleted': true});
    await batch.commit();
  }
}

/// Wersja w pamięci: do testów i do podglądu bez Firebase.
class MemorySharedStore implements SharedStore {
  MemorySharedStore({
    List<Entry> entries = const [],
    List<SharedCategoryDoc> categories = const [],
  }) : entries = {for (final e in entries) e.id: e.copyWith(isLocal: false)},
       categories = {for (final c in categories) c.id: c};

  final Map<String, Entry> entries;
  final Map<String, SharedCategoryDoc> categories;
  final _entriesCtl = StreamController<List<Entry>>.broadcast();
  final _categoriesCtl = StreamController<List<SharedCategoryDoc>>.broadcast();

  void _emit() {
    _entriesCtl.add(entries.values.toList());
    _categoriesCtl.add(categories.values.toList());
  }

  Stream<T> _withCurrent<T>(T current, Stream<T> updates) async* {
    yield current;
    yield* updates;
  }

  @override
  Stream<List<Entry>> watchEntries(String spaceId) =>
      _withCurrent(entries.values.toList(), _entriesCtl.stream);

  @override
  Stream<List<SharedCategoryDoc>> watchCategories(String spaceId) =>
      _withCurrent(categories.values.toList(), _categoriesCtl.stream);

  @override
  Future<List<Entry>> fetchEntries(String spaceId) async =>
      entries.values.toList();

  @override
  Future<List<SharedCategoryDoc>> fetchCategories(String spaceId) async =>
      categories.values.toList();

  @override
  Future<void> putEntry(String spaceId, Entry entry, {Entry? previous}) async {
    final old = entries[entry.id];
    var e = entry.copyWith(isLocal: false);
    if (previous != null && old != null) {
      final f = _entryFields(entry, previous: previous);
      e = e.copyWith(
        doneDates: f.containsKey('doneDates') ? null : old.doneDates,
        skipped: f.containsKey('skipped') ? null : old.skipped,
        checks: f.containsKey('checks') ? null : old.checks,
      );
    }
    entries[entry.id] = e;
    _emit();
  }

  @override
  Future<void> deleteEntry(String spaceId, String entryId) async {
    entries.remove(entryId);
    _emit();
  }

  @override
  Future<void> setDone(
    String spaceId,
    String entryId,
    String key,
    bool done,
  ) async {
    final e = entries[entryId]!;
    final set = {...e.doneDates};
    done ? set.add(key) : set.remove(key);
    entries[entryId] = e.copyWith(doneDates: set);
    _emit();
  }

  @override
  Future<void> setChecked(
    String spaceId,
    String entryId,
    String key,
    String itemId,
    bool checked,
  ) async {
    final e = entries[entryId]!;
    final checks = {
      for (final x in e.checks.entries) x.key: {...x.value},
    };
    final set = checks.putIfAbsent(key, () => {});
    checked ? set.add(itemId) : set.remove(itemId);
    entries[entryId] = e.copyWith(checks: checks);
    _emit();
  }

  @override
  Future<void> addSkipped(String spaceId, String entryId, String key) async {
    final e = entries[entryId]!;
    entries[entryId] = e.copyWith(skipped: {...e.skipped, key});
    _emit();
  }

  @override
  Future<void> putCategory(String spaceId, Category category) async {
    categories[category.id] = SharedCategoryDoc(
      id: category.id,
      name: category.name,
      color: category.color,
    );
    _emit();
  }

  @override
  Future<void> deleteCategory(String spaceId, String categoryId) async {
    for (final e
        in entries.values.where((e) => e.categoryId == categoryId).toList()) {
      entries[e.id] = e.copyWith(categoryId: fallbackCategoryId);
    }
    categories[categoryId] = SharedCategoryDoc(id: categoryId, deleted: true);
    _emit();
  }
}
