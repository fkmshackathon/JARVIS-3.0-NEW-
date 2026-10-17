import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_models.dart';

/// College stays local, consistent with the existing local timetable workspace.
/// SDK-managed identity/session credentials are never copied to these records.
class LocalProfileStore implements AuthProfileStore {
  static String keyFor(String uid) => 'synchro.profile.v1.${Uri.encodeComponent(uid)}';

  @override
  Future<AuthProfile?> read(String uid) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(keyFor(uid));
      if (raw == null) return null;
      try {
        return AuthProfile.fromJson(jsonDecode(raw));
      } on FormatException {
        return null;
      }
    } catch (_) {
      throw const AuthFailure('profile-storage');
    }
  }

  @override
  Future<void> write(String uid, AuthProfile profile) async {
    if (!profile.isValid) throw const AuthFailure('profile-invalid');
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(keyFor(uid), jsonEncode(profile.toJson()));
      if (!saved) throw const AuthFailure('profile-storage');
    } catch (_) {
      throw const AuthFailure('profile-storage');
    }
  }
}
