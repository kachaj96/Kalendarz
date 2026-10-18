import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/category.dart';
import '../domain/entry.dart';

const _schemaVersion = 1;

/// Wszystko, co zostaje tylko na tym telefonie: wpisy lokalne i kategorie lokalne.
class LocalData {
  const LocalData({this.entries = const [], this.categories = const []});

  final List<Entry> entries;
  final List<Category> categories;

  Map<String, dynamic> toJson() => {
    'version': _schemaVersion,
    'entries': [for (final e in entries) e.toJson()],
    'categories': [for (final c in categories) c.toJson()],
  };

  factory LocalData.fromJson(Map<String, dynamic> j) => LocalData(
    entries: [
      for (final e in (j['entries'] as List? ?? const []))
        Entry.fromJson(Map<String, dynamic>.from(e as Map)),
    ],
    categories: [
      for (final c in (j['categories'] as List? ?? const []))
        Category.fromJson(Map<String, dynamic>.from(c as Map)),
    ],
  );
}

abstract class LocalStore {
  Future<LocalData> load();
  Future<void> save(LocalData data);
}

/// Plik JSON w katalogu aplikacji. Zapis idzie przez plik tymczasowy i zmianę nazwy,
/// więc przerwany zapis nie zostawia uciętego pliku.
class FileLocalStore implements LocalStore {
  FileLocalStore({this._directory});

  Directory? _directory;

  Future<File> _file(String name) async {
    final dir = _directory ??= await getApplicationDocumentsDirectory();
    return File('${dir.path}/$name');
  }

  @override
  Future<LocalData> load() async {
    final file = await _file('kalendarz_local.json');
    if (!await file.exists()) return const LocalData();
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return LocalData.fromJson(json);
    } catch (_) {
      // Uszkodzony plik odkładamy na bok zamiast go nadpisać, żeby dało się go jeszcze odzyskać.
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await file.rename('${file.path}.uszkodzony-$stamp');
      return const LocalData();
    }
  }

  @override
  Future<void> save(LocalData data) async {
    final file = await _file('kalendarz_local.json');
    final tmp = await _file('kalendarz_local.json.tmp');
    await tmp.writeAsString(jsonEncode(data.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}

/// Do testów.
class MemoryLocalStore implements LocalStore {
  MemoryLocalStore([this.data = const LocalData()]);

  LocalData data;
  int saves = 0;

  @override
  Future<LocalData> load() async => data;

  @override
  Future<void> save(LocalData d) async {
    data = d;
    saves++;
  }
}
