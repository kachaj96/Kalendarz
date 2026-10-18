import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/local_repository.dart';
import 'domain/category.dart';
import 'domain/entry.dart';

/// Aktualny czas. Osobny provider, żeby testy mogły go podmienić.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Wszystkie wpisy widoczne na tym telefonie (na razie tylko lokalne).
final entriesProvider = Provider<List<Entry>>(
  (ref) => ref.watch(localDataProvider).value?.entries ?? const [],
);

final categoriesProvider = Provider<List<Category>>(
  (ref) => [
    ...defaultCategories,
    ...(ref.watch(localDataProvider).value?.categories ?? const <Category>[]),
  ],
);

final categoryByIdProvider = Provider<Map<String, Category>>(
  (ref) => {for (final c in ref.watch(categoriesProvider)) c.id: c},
);
