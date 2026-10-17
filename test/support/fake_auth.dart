import 'dart:async';

import 'package:synchro/auth/auth_models.dart';
import 'package:synchro/auth/auth_session.dart';

class FakeAuthRepository implements AuthRepository {
  final _events = StreamController<AuthUser?>.broadcast(sync: true);
  AuthUser? _user;
  AuthFailure? failure;
  Completer<AuthUser>? pendingLogin;
  bool verifyOnReload = false;
  int signInCalls = 0;
  int signUpCalls = 0;
  int googleCalls = 0;
  int verificationCalls = 0;
  int resetCalls = 0;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get userChanges async* {
    yield _user;
    yield* _events.stream;
  }

  void emit(AuthUser? user) { _user = user; _events.add(user); }

  Future<AuthUser> _login(String email, {bool verified = true}) async {
    if (failure != null) throw failure!;
    final user = pendingLogin == null ? AuthUser(
      uid: email.startsWith('other') ? 'other-user' : 'test-user',
      email: email, displayName: 'Test Planner', emailVerified: verified,
    ) : await pendingLogin!.future;
    emit(user);
    return user;
  }

  @override
  Future<AuthUser> signIn(String email, String password) {
    signInCalls++;
    return _login(email);
  }

  @override
  Future<AuthUser> signUp(String email, String password) {
    signUpCalls++;
    return _login(email, verified: false);
  }

  @override
  Future<AuthUser> signInWithGoogle() {
    googleCalls++;
    return _login('planner@campus.edu');
  }

  @override
  Future<void> updateDisplayName(String uid, String name) async {
    if (_user?.uid != uid) throw const AuthFailure('session-changed');
  }

  @override
  Future<void> sendVerificationEmail(String uid) async { verificationCalls++; }

  @override
  Future<AuthUser?> reloadUser(String uid) async {
    final old = _user;
    if (old == null || old.uid != uid) throw const AuthFailure('session-changed');
    final user = AuthUser(uid: uid, email: old.email,
      displayName: old.displayName, emailVerified: verifyOnReload || old.emailVerified);
    emit(user);
    return user;
  }

  @override
  Future<void> sendPasswordReset(String email) async { resetCalls++; }

  @override
  Future<void> signOut() async { emit(null); }

  @override
  void dispose() { unawaited(_events.close()); }
}

class MemoryAuthProfiles implements AuthProfileStore {
  final records = <String, AuthProfile>{};
  final pendingReads = <String, Completer<AuthProfile?>>{};

  @override
  Future<AuthProfile?> read(String uid) async =>
      pendingReads[uid] == null ? records[uid] : await pendingReads[uid]!.future;

  @override
  Future<void> write(String uid, AuthProfile profile) async {
    records[uid] = profile;
  }
}

AuthSession testAuthSession() => AuthSession(
  repository: FakeAuthRepository(), profiles: MemoryAuthProfiles(),
);
