import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_models.dart';

enum AuthStage { restoring, signedOut, profileRequired, verificationRequired, authenticated }

/// The gate depends on Firebase identity + a complete profile + verified email.
/// Tests inject the repository boundary; production never constructs a demo.
class AuthSession extends ChangeNotifier {
  AuthSession({required this._repository, required this._profiles}) {
    _subscription = _repository.userChanges.listen(_onUserChanged, onError: (_) {
      if (_disposed) return;
      _epoch++;
      _user = null;
      _profile = null;
      _stage = AuthStage.signedOut;
      _error = const AuthFailure('network-request-failed').message;
      _notify();
    });
  }

  final AuthRepository _repository;
  final AuthProfileStore _profiles;
  late final StreamSubscription<AuthUser?> _subscription;
  AuthStage _stage = AuthStage.restoring;
  AuthUser? _user;
  AuthProfile? _profile;
  String? _error;
  String? _info;
  bool _busy = false;
  bool _disposed = false;
  int _epoch = 0;
  int _operationId = 0;
  String? _suppressedUid;
  DateTime? _lastVerificationAt;

  AuthStage get stage => _stage;
  AuthUser? get user => _user;
  AuthProfile? get profile => _profile;
  String? get error => _error;
  String? get info => _info;
  bool get busy => _busy || _stage == AuthStage.restoring;
  bool get isSignedIn => _stage == AuthStage.authenticated &&
      _user?.emailVerified == true && _profile?.isValid == true &&
      _repository.currentUser?.uid == _user?.uid;

  void _notify() { if (!_disposed) notifyListeners(); }

  void _onUserChanged(AuthUser? user) {
    if (_disposed) return;
    if (user != null && user.uid == _suppressedUid) return;
    if (user == null) {
      _epoch++;
      _user = null;
      _profile = null;
      _lastVerificationAt = null;
      _stage = AuthStage.signedOut;
      _notify();
      return;
    }
    // Provider/profile operations also emit userChanges. Resolve them once,
    // rather than allowing an intermediate event to publish a partial login.
    if (_busy) { _user = user; return; }
    if (_user?.uid == user.uid && _profile?.isValid == true) {
      _user = user;
      _deriveStage();
      _notify();
      return;
    }
    unawaited(_restoreUser(user));
  }

  bool _current(int epoch, String uid) => !_disposed && epoch == _epoch &&
      _repository.currentUser?.uid == uid;

  void _deriveStage() {
    _stage = _user == null ? AuthStage.signedOut
        : _profile?.isValid != true ? AuthStage.profileRequired
        : _user!.emailVerified ? AuthStage.authenticated
        : AuthStage.verificationRequired;
  }

  Future<void> _restoreUser(AuthUser user) async {
    final epoch = ++_epoch;
    if (_user?.uid != user.uid) _lastVerificationAt = null;
    _user = user;
    _profile = null;
    _stage = AuthStage.restoring;
    _notify();
    try {
      final profile = await _profiles.read(user.uid);
      if (!_current(epoch, user.uid)) return;
      _profile = profile;
      _error = null;
    } catch (_) {
      if (!_current(epoch, user.uid)) return;
      _error = const AuthFailure('profile-storage').message;
    }
    if (!_current(epoch, user.uid)) return;
    _deriveStage();
    _notify();
  }

  Future<void> _saveProfile(AuthUser user, AuthProfile profile) async {
    if (!profile.isValid) throw const AuthFailure('profile-invalid');
    if (_repository.currentUser?.uid != user.uid) throw const AuthFailure('session-changed');
    await _repository.updateDisplayName(user.uid, profile.displayName);
    if (_repository.currentUser?.uid != user.uid) throw const AuthFailure('session-changed');
    await _profiles.write(user.uid, profile);
  }

  Future<void> _authenticate(
    Future<AuthUser> Function() action, {AuthProfile? profile, bool verify = false}
  ) async {
    if (busy || _disposed) return;
    final epoch = ++_epoch;
    _suppressedUid = null;
    final operation = ++_operationId;
    _busy = true;
    _error = null;
    _info = null;
    _notify();
    try {
      final user = await action();
      if (!_current(epoch, user.uid)) {
        // A late SDK login must not undo a newer logout/session change.
        if (!_disposed && _repository.currentUser?.uid == user.uid) {
          _suppressedUid = user.uid;
          await _repository.signOut();
        }
        return;
      }
      _user = user;
      if (profile != null) await _saveProfile(user, profile);
      final stored = profile ?? await _profiles.read(user.uid);
      if (!_current(epoch, user.uid)) return;
      _profile = stored;
      _user = _repository.currentUser;
      if (verify && !_user!.emailVerified) {
        try {
          await _repository.sendVerificationEmail(user.uid);
          _lastVerificationAt = DateTime.now();
          _info = 'A verification email was sent. Verify your email before entering the workspace.';
        } catch (error) {
          _error = _message(error);
        }
      }
    } catch (error) {
      if (_disposed || epoch != _epoch) return;
      _user = _repository.currentUser;
      _profile = null;
      _error = error is AuthFailure && error.wasCancelled ? null : _message(error);
    } finally {
      if (!_disposed && operation == _operationId) {
        _busy = false;
        if (epoch == _epoch) _deriveStage();
        _notify();
        final current = _repository.currentUser;
        if (epoch != _epoch && current != null && current.uid != _suppressedUid) {
          _onUserChanged(current);
        }
      }
    }
  }

  static String _message(Object error) => error is AuthFailure
      ? error.message : const AuthFailure('unknown').message;

  void _inputError(String message) {
    _error = message;
    _info = null;
    _notify();
  }

  Future<void> signIn({required String email, required String password,
      required AuthProfile profile}) async {
    final invalid = AuthValidators.email(email) ?? AuthValidators.password(password);
    if (invalid != null) { _inputError(invalid); return; }
    if (!profile.isValid) { _inputError(const AuthFailure('profile-invalid').message); return; }
    await _authenticate(() => _repository.signIn(email.trim(), password), profile: profile);
  }

  Future<void> signUp({required String email, required String password,
      required AuthProfile profile}) async {
    final invalid = AuthValidators.email(email) ??
        AuthValidators.password(password, creatingAccount: true);
    if (invalid != null) { _inputError(invalid); return; }
    if (!profile.isValid) { _inputError(const AuthFailure('profile-invalid').message); return; }
    await _authenticate(() => _repository.signUp(email.trim(), password),
      profile: profile, verify: true);
  }

  Future<void> signInWithGoogle({AuthProfile? profile}) async {
    if (profile != null && !profile.isValid) {
      _inputError(const AuthFailure('profile-invalid').message);
      return;
    }
    await _authenticate(_repository.signInWithGoogle, profile: profile);
  }

  Future<void> completeProfile(AuthProfile profile) async {
    final user = _user;
    if (user == null) return;
    if (!profile.isValid) { _inputError(const AuthFailure('profile-invalid').message); return; }
    await _authenticate(() async {
      final current = _repository.currentUser;
      if (current?.uid != user.uid) throw const AuthFailure('session-changed');
      return current!;
    }, profile: profile, verify: !user.emailVerified);
  }

  Future<void> refreshVerification() async {
    final user = _user;
    if (user == null) return;
    await _authenticate(() async {
      final refreshed = await _repository.reloadUser(user.uid);
      if (refreshed == null) throw const AuthFailure('session-changed');
      return refreshed;
    });
  }

  Future<void> _auxiliary(Future<void> Function() action, String success) async {
    if (busy || _disposed) return;
    final epoch = _epoch;
    final operation = ++_operationId;
    _busy = true;
    _error = null;
    _info = null;
    _notify();
    try {
      await action();
      if (!_disposed && epoch == _epoch) _info = success;
    } catch (error) {
      if (!_disposed && epoch == _epoch) _error = _message(error);
    } finally {
      if (!_disposed && operation == _operationId) { _busy = false; _notify(); }
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final invalid = AuthValidators.email(email);
    if (invalid != null) { _inputError(invalid); return; }
    await _auxiliary(() => _repository.sendPasswordReset(email.trim()),
      'If an account exists for this email, password reset instructions have been sent.');
  }

  Future<void> resendVerification() async {
    final user = _user;
    if (user == null || user.emailVerified) return;
    if (_lastVerificationAt != null &&
        DateTime.now().difference(_lastVerificationAt!).inSeconds < 60) {
      _inputError('Please wait a minute before requesting another verification email.');
      return;
    }
    await _auxiliary(() async {
      await _repository.sendVerificationEmail(user.uid);
      _lastVerificationAt = DateTime.now();
    }, 'A new verification email was sent.');
  }

  Future<void> signOut() async {
    if (_disposed) return;
    ++_epoch;
    final operation = ++_operationId;
    _suppressedUid = _user?.uid ?? _repository.currentUser?.uid;
    _user = null;
    _profile = null;
    _lastVerificationAt = null;
    _error = null;
    _info = null;
    _stage = AuthStage.signedOut;
    _busy = true;
    _notify();
    try {
      await _repository.signOut();
    } catch (error) {
      if (!_disposed) _error = _message(error);
    } finally {
      if (!_disposed && operation == _operationId) { _busy = false; _notify(); }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_epoch;
    unawaited(_subscription.cancel());
    _repository.dispose();
    super.dispose();
  }
}
