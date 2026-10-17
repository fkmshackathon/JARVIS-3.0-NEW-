import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchro/auth/auth_models.dart';
import 'package:synchro/auth/auth_session.dart';
import 'package:synchro/auth/firebase_configuration.dart';
import 'package:synchro/auth/local_profile_store.dart';

import 'support/fake_auth.dart';

Future<void> settleAuth() => Future<void>.delayed(Duration.zero);
AuthProfile profile(String name) => AuthProfile(displayName: name, collegeName: 'Test College');

void main() {
  late FakeAuthRepository repository;
  late MemoryAuthProfiles profiles;
  late AuthSession session;

  setUp(() async {
    repository = FakeAuthRepository();
    profiles = MemoryAuthProfiles();
    session = AuthSession(repository: repository, profiles: profiles);
    await settleAuth();
  });
  tearDown(() => session.dispose());

  test('incorrect credentials never open the authenticated workspace', () async {
    repository.failure = const AuthFailure('invalid-credential');
    await session.signIn(email: 'planner@campus.edu', password: 'incorrect', profile: profile('Aarya'));
    expect(session.isSignedIn, isFalse);
    expect(session.stage, AuthStage.signedOut);
    expect(session.error, contains('email or password is incorrect'));
  });

  test('valid email login keeps profile metadata under the SDK UID', () async {
    await session.signIn(email: 'planner@campus.edu', password: 'test-password', profile: profile('Aarya'));
    expect(session.isSignedIn, isTrue);
    expect(profiles.records['test-user']?.displayName, 'Aarya');
    await session.signOut();
    expect(session.user, isNull);
    expect(session.profile, isNull);
    expect(repository.currentUser, isNull);
  });

  test('sign-up requires email verification and uses reloaded SDK state', () async {
    await session.signUp(email: 'planner@campus.edu', password: 'test-password', profile: profile('Aarya'));
    expect(repository.signUpCalls, 1);
    expect(repository.verificationCalls, 1);
    expect(session.stage, AuthStage.verificationRequired);
    expect(session.isSignedIn, isFalse);
    repository.verifyOnReload = true;
    await session.refreshVerification();
    expect(session.isSignedIn, isTrue);
  });

  test('Google login collects missing college without creating a second account', () async {
    await session.signInWithGoogle();
    expect(session.stage, AuthStage.profileRequired);
    expect(session.isSignedIn, isFalse);
    await session.completeProfile(profile('Aarya'));
    expect(session.isSignedIn, isTrue);
    expect(repository.googleCalls, 1);
    expect(repository.signUpCalls, 0);
  });

  test('Google cancellation does not pretend login succeeded', () async {
    repository.failure = const AuthFailure('cancelled');
    await session.signInWithGoogle();
    expect(session.isSignedIn, isFalse);
    expect(session.error, isNull);
  });

  test('local metadata alone cannot authenticate a user', () async {
    profiles.records['test-user'] = profile('Aarya');
    expect(session.stage, AuthStage.signedOut);
    expect(session.isSignedIn, isFalse);
  });

  test('invalid input is rejected before calling an auth provider', () async {
    await session.signUp(email: 'invalid', password: 'x', profile: profile('Aarya'));
    await session.signIn(email: 'planner@campus.edu', password: 'test-password', profile: profile(' '));
    expect(repository.signInCalls + repository.signUpCalls, 0);
    expect(session.isSignedIn, isFalse);
  });

  test('password reset does not sign in or enumerate an account', () async {
    await session.sendPasswordReset('planner@campus.edu');
    expect(repository.resetCalls, 1);
    expect(session.info, contains('If an account exists'));
    expect(session.isSignedIn, isFalse);
  });

  test('a stale profile read after sign-out cannot restore the workspace', () async {
    final pending = Completer<AuthProfile?>();
    profiles.pendingReads['test-user'] = pending;
    repository.emit(const AuthUser(uid: 'test-user', emailVerified: true));
    await settleAuth();
    await session.signOut();
    pending.complete(profile('Aarya'));
    await settleAuth();
    expect(session.isSignedIn, isFalse);
    expect(session.profile, isNull);
  });

  test('repeated submit starts only one provider request', () async {
    repository.pendingLogin = Completer<AuthUser>();
    final first = session.signIn(email: 'planner@campus.edu', password: 'test-password', profile: profile('Aarya'));
    await session.signIn(email: 'planner@campus.edu', password: 'test-password', profile: profile('Aarya'));
    expect(repository.signInCalls, 1);
    repository.pendingLogin!.complete(const AuthUser(uid: 'test-user', emailVerified: true));
    await first;
    expect(session.isSignedIn, isTrue);
  });

  test('a late login result cannot undo a newer sign-out', () async {
    repository.pendingLogin = Completer<AuthUser>();
    final pending = session.signIn(email: 'planner@campus.edu', password: 'test-password', profile: profile('Aarya'));
    await session.signOut();
    repository.pendingLogin!.complete(const AuthUser(uid: 'test-user', emailVerified: true));
    await pending;
    await settleAuth();
    expect(session.isSignedIn, isFalse);
    expect(repository.currentUser, isNull);
  });

  test('local profile storage is UID-scoped and contains no credentials', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalProfileStore();
    await store.write('user-a', profile('Aarya'));
    expect(await store.read('user-b'), isNull);
    expect((await store.read('user-a'))?.displayName, 'Aarya');
    final preferences = await SharedPreferences.getInstance();
    final saved = jsonDecode(preferences.getString(LocalProfileStore.keyFor('user-a'))!) as Map;
    expect(saved.keys.toSet(), {'display_name', 'college_name'});
  });

  test('Android app IDs and missing Web registration are rejected for Web', () {
    expect(() => FirebaseConfiguration.webOptions(apiKey: 'client-test', appId: '1:1008585753714:android:example'), throwsA(isA<AuthFailure>()));
    expect(() => FirebaseConfiguration.webOptions(apiKey: '', appId: ''), throwsA(isA<AuthFailure>()));
    final options = FirebaseConfiguration.webOptions(apiKey: 'client-test', appId: '1:1008585753714:web:test-registration');
    expect(options.projectId, 'jarvis-cea16');
  });
}
