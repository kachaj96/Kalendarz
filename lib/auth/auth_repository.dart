import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_config.dart';

class SignInCancelled implements Exception {
  const SignInCancelled();
}

class AuthRepository {
  AuthRepository(this._auth, this._google, this._db);

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  final FirebaseFirestore _db;

  bool _googleReady = false;

  Future<void> _initGoogle() async {
    if (_googleReady) return;
    await _google.initialize(serverClientId: FirebaseConfig.googleServerClientId);
    _googleReady = true;
  }

  Future<void> signInWithGoogle() async {
    await _initGoogle();
    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInCancelled();
      }
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google nie zwrócił tokenu logowania.');
    }
    final result = await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    final user = result.user;
    if (user != null) {
      await _db.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': user.displayName,
      }, SetOptions(merge: true));
    }
  }

  Future<void> signOut() async {
    try {
      await _initGoogle();
      await _google.signOut();
    } catch (_) {
      // Wylogowanie z Firebase i tak ma się udać.
    }
    await _auth.signOut();
  }
}
