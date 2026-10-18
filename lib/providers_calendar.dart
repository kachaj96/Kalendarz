import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/local_repository.dart';
import 'data/shared_store.dart';
import 'device/android_device_port.dart';
import 'device/device_port.dart';
import 'domain/category.dart';
import 'domain/entry.dart';
import 'providers.dart';
import 'space/models.dart';

/// Alarmy, widżety i uprawnienia Androida. W testach podmieniane na wersję bez efektów.
final devicePortProvider = Provider<DevicePort>((ref) => AndroidDevicePort());

/// Aktualny czas. Osobny provider, żeby testy mogły go podmienić.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.uid,
);

final currentSpaceIdProvider = Provider<String?>(
  (ref) => ref.watch(spaceIdProvider).value,
);

/// Profile obu osób z przestrzeni, do podpisów "dodał: ...".
final memberProfilesProvider = Provider<Map<String, Profile>>(
  (ref) => ref.watch(spaceProvider).value?.profiles ?? const {},
);

final sharedStoreProvider = Provider<SharedStore>(
  (ref) => FirestoreSharedStore(FirebaseFirestore.instance),
);

final sharedEntriesProvider = StreamProvider<List<Entry>>((ref) {
  final spaceId = ref.watch(currentSpaceIdProvider);
  if (spaceId == null) return Stream.value(const []);
  return ref.watch(sharedStoreProvider).watchEntries(spaceId);
});

final sharedCategoryDocsProvider = StreamProvider<List<SharedCategoryDoc>>((
  ref,
) {
  final spaceId = ref.watch(currentSpaceIdProvider);
  if (spaceId == null) return Stream.value(const []);
  return ref.watch(sharedStoreProvider).watchCategories(spaceId);
});

/// Wszystkie wpisy widoczne na tym telefonie: lokalne i wspólne.
final entriesProvider = Provider<List<Entry>>(
  (ref) => [
    ...(ref.watch(localDataProvider).value?.entries ?? const <Entry>[]),
    ...(ref.watch(sharedEntriesProvider).value ?? const <Entry>[]),
  ],
);

final sharedCategoriesProvider = Provider<List<Category>>(
  (ref) => mergeSharedCategories(
    ref.watch(sharedCategoryDocsProvider).value ?? const [],
  ),
);

final categoriesProvider = Provider<List<Category>>(
  (ref) => [
    ...ref.watch(sharedCategoriesProvider),
    ...(ref.watch(localDataProvider).value?.categories ?? const <Category>[]),
  ],
);

/// Wpisy szukają kategorii po id. Usunięta kategoria wspólna nadal ma wpis w mapie
/// (z wartościami domyślnymi), żeby stary wpis nie zgubił koloru przed przeniesieniem do "Inne".
final categoryByIdProvider = Provider<Map<String, Category>>(
  (ref) => {
    for (final c in defaultCategories) c.id: c,
    for (final c in ref.watch(categoriesProvider)) c.id: c,
  },
);
