import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchro/auth/auth_models.dart';
import 'package:synchro/auth/auth_session.dart';
import 'package:synchro/main.dart';
import 'package:synchro/state/timetable_library_controller.dart';

import 'support/fake_auth.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> fillAccount(WidgetTester tester) async {
  for (final entry in {
    'access-name-field': 'Aarya Dsouza',
    'access-college-field': 'Test College',
    'access-email-field': 'planner@campus.edu',
    'access-password-field': 'test-password',
  }.entries) {
    await tester.enterText(find.byKey(Key(entry.key)), entry.value);
  }
}

void main() {
  late FakeAuthRepository repository;
  late AuthSession session;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = FakeAuthRepository();
    session = AuthSession(repository: repository, profiles: MemoryAuthProfiles());
  });
  tearDown(() => session.dispose());

  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SynchroApp(session: session));
    await tester.pumpAndSettle();
  }

  testWidgets('provider credential failures leave the real access form visible', (tester) async {
    repository.failure = const AuthFailure('invalid-credential');
    await boot(tester);
    await fillAccount(tester);
    await tapVisible(tester, find.byKey(const Key('access-submit-button')));
    expect(find.textContaining('email or password is incorrect'), findsOneWidget);
    expect(find.text('Your scheduling workspace'), findsNothing);
    expect(session.isSignedIn, isFalse);
  });

  testWidgets('Google sign-in needs no password and collects missing college', (tester) async {
    await boot(tester);
    await tapVisible(tester, find.byKey(const Key('auth-google-button')));
    expect(find.text('Complete your profile'), findsOneWidget);
    expect(find.text('Your scheduling workspace'), findsNothing);
    await tester.enterText(find.byKey(const Key('access-name-field')), 'Aarya Dsouza');
    await tester.enterText(find.byKey(const Key('access-college-field')), 'Test College');
    await tapVisible(tester, find.byKey(const Key('auth-profile-submit')));
    expect(find.text('Your scheduling workspace'), findsOneWidget);
    expect(repository.googleCalls, 1);
    expect(repository.signUpCalls, 0);
  });

  testWidgets('sign-up validates confirmation and gates unverified email', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    await fillAccount(tester);
    await tester.enterText(find.byKey(const Key('auth-confirm-password')), 'does-not-match');
    await tapVisible(tester, find.byKey(const Key('access-submit-button')));
    expect(find.text('Passwords must match.'), findsOneWidget);
    expect(repository.signUpCalls, 0);
    await tester.enterText(find.byKey(const Key('auth-confirm-password')), 'test-password');
    await tapVisible(tester, find.byKey(const Key('access-submit-button')));
    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Your scheduling workspace'), findsNothing);
    expect(repository.verificationCalls, 1);
    repository.verifyOnReload = true;
    await tapVisible(tester, find.byKey(const Key('auth-refresh-verification')));
    expect(find.text('Your scheduling workspace'), findsOneWidget);
    expect(repository.signUpCalls, 1);
  });

  testWidgets('forgot-password works without name, college or password', (tester) async {
    await boot(tester);
    await tester.enterText(find.byKey(const Key('access-email-field')), 'planner@campus.edu');
    await tapVisible(tester, find.byKey(const Key('auth-reset-password')));
    expect(find.textContaining('If an account exists'), findsOneWidget);
    expect(repository.resetCalls, 1);
    expect(session.isSignedIn, isFalse);
  });

  testWidgets('external sign-out removes protected navigation routes', (tester) async {
    await boot(tester);
    await fillAccount(tester);
    await tapVisible(tester, find.byKey(const Key('access-submit-button')));
    await tester.scrollUntilVisible(find.byKey(const Key('open-timetable-library-button')),
      200, scrollable: find.byType(Scrollable).first);
    await tapVisible(tester, find.byKey(const Key('open-timetable-library-button')));
    expect(find.text('My timetables'), findsOneWidget);
    repository.emit(null);
    await tester.pumpAndSettle();
    expect(find.text('My timetables'), findsNothing);
    expect(find.text('Welcome to SYNCHRO.'), findsOneWidget);
    expect(session.profile, isNull);
    expect(tester.takeException(), isNull);
  });

  test('account libraries are isolated and legacy local records remain untouched', () async {
    final legacy = TimetableLibraryController();
    await legacy.restore();
    legacy.createBlank(name: 'Unowned legacy draft');
    await legacy.flush();
    final preferences = await SharedPreferences.getInstance();
    final original = preferences.getString(TimetableLibraryController.storageKey);
    final first = TimetableLibraryController(ownerUid: 'user-a');
    final second = TimetableLibraryController(ownerUid: 'user-b');
    addTearDown(legacy.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await first.restore();
    await second.restore();
    expect(first.records.any((r) => r.name == 'Unowned legacy draft'), isFalse);
    first.createBlank(name: 'User A private draft');
    await first.flush();
    expect(second.records.any((r) => r.name == 'User A private draft'), isFalse);
    final restored = TimetableLibraryController(ownerUid: 'user-a');
    addTearDown(restored.dispose);
    await restored.restore();
    expect(restored.records.any((r) => r.name == 'User A private draft'), isTrue);
    await first.resetDemo();
    expect(preferences.getString(TimetableLibraryController.storageKey), original);
    expect(preferences.containsKey(TimetableLibraryController.storageKeyForUser('user-b')), isTrue);
  });
}
