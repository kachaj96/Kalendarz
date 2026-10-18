import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth/auth_repository.dart';
import 'space/models.dart';
import 'space/space_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    FirebaseAuth.instance,
    GoogleSignIn.instance,
    FirebaseFirestore.instance,
  ),
);

final spaceRepositoryProvider = Provider<SpaceRepository>(
  (ref) => SpaceRepository(FirebaseFirestore.instance),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Id wspólnej przestrzeni zalogowanej osoby, null gdy jeszcze nie jest sparowana.
final spaceIdProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(spaceRepositoryProvider).watchSpaceId(user.uid);
});

final spaceProvider = StreamProvider<Space?>((ref) {
  final id = ref.watch(spaceIdProvider).value;
  if (id == null) return Stream.value(null);
  return ref.watch(spaceRepositoryProvider).watchSpace(id);
});
