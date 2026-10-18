import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../data/local_store.dart';
import '../data/shared_store.dart';
import '../domain/category.dart';
import '../firebase_config.dart';
import '../space/models.dart';
import 'android_device_port.dart';
import 'device_port.dart';

const _syncTask = 'kalendarz-sync';

/// Punkt wejścia pracy w tle (osobny izolat bez interfejsu). Odczytuje wpisy z telefonu
/// i ze wspólnej bazy, przelicza alarmy i widżety, powiadamia o nowych wpisach partnera.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      await runBackgroundSync();
    } catch (e) {
      debugPrint('Synchronizacja w tle: $e');
    }
    // Zawsze sukces: ponawianie błędu co chwilę tylko zjadałoby baterię.
    return true;
  });
}

Future<void> runBackgroundSync() async {
  final local = await FileLocalStore().load();
  var shared = const <dynamic>[];
  var sharedCategories = const <SharedCategoryDoc>[];
  var profiles = const <String, Profile>{};
  String? uid;

  if (FirebaseConfig.isConfigured) {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: FirebaseConfig.options);
    }
    final user =
        FirebaseAuth.instance.currentUser ??
        await FirebaseAuth.instance.authStateChanges().first.timeout(
          const Duration(seconds: 10),
        );
    uid = user?.uid;
    if (uid != null) {
      final db = FirebaseFirestore.instance;
      final spaceId =
          (await db.collection('users').doc(uid).get()).data()?['spaceId']
              as String?;
      if (spaceId != null) {
        final store = FirestoreSharedStore(db);
        shared = await store.fetchEntries(spaceId);
        sharedCategories = await store.fetchCategories(spaceId);
        final space = await db.collection('spaces').doc(spaceId).get();
        if (space.exists) profiles = Space.fromSnapshot(space).profiles;
      }
    }
  }

  final categories = {
    for (final c in defaultCategories) c.id: c,
    for (final c in mergeSharedCategories(sharedCategories)) c.id: c,
    for (final c in local.categories) c.id: c,
  };
  await AndroidDevicePort().sync(
    DeviceState(
      entries: [...local.entries, ...shared.cast()],
      categories: categories,
      now: DateTime.now(),
      myUid: uid,
      profiles: profiles,
    ),
    background: true,
  );
}

/// Rejestruje okresowe odświeżanie (Android robi to najczęściej co 15 minut, zwykle rzadziej).
Future<void> registerBackgroundSync() async {
  await Workmanager().initialize(backgroundDispatcher);
  await Workmanager().registerPeriodicTask(
    _syncTask,
    _syncTask,
    frequency: const Duration(minutes: 30),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}
