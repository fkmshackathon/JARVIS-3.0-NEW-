import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_models.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository._(this._auth);

  final FirebaseAuth _auth;
  static Future<void>? _googleInitialization;
  bool _googleReady = false;

  static Future<FirebaseAuthRepository> create() async {
    final repository = FirebaseAuthRepository._(FirebaseAuth.instance);
    if (kIsWeb) {
      await repository._auth.setPersistence(Persistence.LOCAL);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        _googleInitialization ??= GoogleSignIn.instance.initialize();
        await _googleInitialization;
        repository._googleReady = true;
      } catch (_) {
        // A Google setup failure must not turn email authentication into demo
        // authentication or disable otherwise configured email accounts.
        repository._googleReady = false;
      }
    }
    return repository;
  }

  static AuthUser _identity(User? user) {
    if (user == null || user.uid.isEmpty) throw const AuthFailure('session-changed');
    return AuthUser(uid: user.uid, email: user.email,
      displayName: user.displayName, emailVerified: user.emailVerified);
  }

  @override
  AuthUser? get currentUser => _auth.currentUser == null ? null : _identity(_auth.currentUser);

  @override
  Stream<AuthUser?> get userChanges => _auth.userChanges().map(
    (user) => user == null ? null : _identity(user),
  );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' || error.code == 'cancelled-popup-request') {
        throw const AuthFailure('cancelled');
      }
      throw AuthFailure(error.code);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthFailure('cancelled');
      }
      throw const AuthFailure('google-configuration');
    }
  }

  @override
  Future<AuthUser> signIn(String email, String password) => _guard(() async {
    final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return _identity(result.user);
  });

  @override
  Future<AuthUser> signUp(String email, String password) => _guard(() async {
    final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return _identity(result.user);
  });

  @override
  Future<AuthUser> signInWithGoogle() => _guard(() async {
    if (kIsWeb) {
      // Called directly from the button gesture, not after an unrelated await.
      final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
      return _identity((await _auth.signInWithPopup(provider)).user);
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw const AuthFailure('unsupported-platform');
    }
    if (!_googleReady) throw const AuthFailure('google-configuration');
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const AuthFailure('google-configuration');
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _identity((await _auth.signInWithCredential(credential)).user);
  });

  User _userFor(String uid) {
    final user = _auth.currentUser;
    if (user == null || user.uid != uid) throw const AuthFailure('session-changed');
    return user;
  }

  @override
  Future<void> updateDisplayName(String uid, String name) =>
    _guard(() => _userFor(uid).updateDisplayName(name));

  @override
  Future<void> sendVerificationEmail(String uid) =>
    _guard(() => _userFor(uid).sendEmailVerification());

  @override
  Future<AuthUser?> reloadUser(String uid) => _guard(() async {
    await _userFor(uid).reload();
    final user = _auth.currentUser;
    if (user != null && user.uid != uid) throw const AuthFailure('session-changed');
    return user == null ? null : _identity(user);
  });

  @override
  Future<void> sendPasswordReset(String email) => _guard(() async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      if (error.code != 'user-not-found') rethrow;
      // Same visible result with or without an account (no email enumeration).
    }
  });

  @override
  Future<void> signOut() => _guard(() async {
    await _auth.signOut();
    if (!kIsWeb && _googleReady) {
      try { await GoogleSignIn.instance.signOut(); } catch (_) {
        // Firebase identity has already been cleared; never restore it here.
      }
    }
  });

  @override
  void dispose() {}
}
