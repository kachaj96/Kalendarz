import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'invite_code.dart';
import 'models.dart';

enum JoinFailure { invalidCode, spaceFull, alreadyInSpace }

class JoinException implements Exception {
  const JoinException(this.failure);
  final JoinFailure failure;
}

class SpaceRepository {
  SpaceRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _space(String id) =>
      _db.collection('spaces').doc(id);
  DocumentReference<Map<String, dynamic>> _invite(String code) =>
      _db.collection('invites').doc(code);

  Profile _profileOf(User user) => Profile(
    uid: user.uid,
    name: user.displayName ?? user.email ?? '',
    email: user.email ?? '',
  );

  Stream<String?> watchSpaceId(String uid) =>
      _user(uid).snapshots().map((s) => s.data()?['spaceId'] as String?);

  Stream<Space?> watchSpace(String spaceId) =>
      _space(spaceId)
          .snapshots()
          .map((s) => s.exists ? Space.fromSnapshot(s) : null);

  /// Zakłada wspólny kalendarz i zwraca kod zaproszenia dla drugiej osoby.
  /// Przestrzeń musi istnieć przed zaproszeniem, bo reguły sprawdzają członkostwo autora kodu.
  Future<String> createSpace(User me) async {
    final ref = _db.collection('spaces').doc();
    await ref.set({
      'memberIds': [me.uid],
      'profiles': {me.uid: _profileOf(me).toMap()},
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _user(me.uid).set({'spaceId': ref.id}, SetOptions(merge: true));
    final code = await _reserveInvite(ref.id, me.uid);
    await ref.update({'inviteCode': code});
    return code;
  }

  Future<void> joinWithCode(User me, String rawCode) async {
    final code = normalizeInviteCode(rawCode);
    if (code == null) throw const JoinException(JoinFailure.invalidCode);

    final invite = await _invite(code).get();
    final spaceId = invite.data()?['spaceId'] as String?;
    if (spaceId == null) throw const JoinException(JoinFailure.invalidCode);

    try {
      await _space(spaceId).update({
        'memberIds': FieldValue.arrayUnion([me.uid]),
        'profiles.${me.uid}': _profileOf(me).toMap(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const JoinException(JoinFailure.spaceFull);
      }
      rethrow;
    }
    await _user(me.uid).set({'spaceId': spaceId}, SetOptions(merge: true));

    // Kod jest jednorazowy. Gdyby sprzątanie się nie udało, kod i tak nie wpuści trzeciej osoby.
    try {
      await _invite(code).delete();
      await _space(spaceId).update({'inviteCode': FieldValue.delete()});
    } on FirebaseException catch (_) {}
  }

  /// Nowy kod, gdy poprzedni się zgubił. Stary przestaje działać.
  Future<String> renewInvite(Space space, String myUid) async {
    final old = space.inviteCode;
    final code = await _reserveInvite(space.id, myUid);
    await _space(space.id).update({'inviteCode': code});
    if (old != null) {
      try {
        await _invite(old).delete();
      } on FirebaseException catch (_) {}
    }
    return code;
  }

  Future<void> leave(String myUid, String spaceId) async {
    await _space(spaceId).update({
      'memberIds': FieldValue.arrayRemove([myUid]),
      'profiles.$myUid': FieldValue.delete(),
    });
    await _user(myUid)
        .set({'spaceId': FieldValue.delete()}, SetOptions(merge: true));
  }

  Future<String> _reserveInvite(String spaceId, String myUid) async {
    FirebaseException? last;
    for (var i = 0; i < 5; i++) {
      final code = generateInviteCode();
      try {
        // Reguły pozwalają tylko na create, więc zajęty kod kończy się błędem i losujemy kolejny.
        await _invite(code).set({'spaceId': spaceId, 'createdBy': myUid});
        return code;
      } on FirebaseException catch (e) {
        last = e;
      }
    }
    throw last ?? StateError('Nie udało się wygenerować kodu.');
  }
}
