import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'auth_models.dart';

/// Public client configuration, not Admin SDK credentials or an OAuth secret.
/// Android configuration is read by its SDK from matching Google-services data.
abstract final class FirebaseConfiguration {
  static const projectId = 'jarvis-cea16';
  static const androidPackage = 'com.synchro.synchro';

  static const webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN', defaultValue: 'jarvis-cea16.firebaseapp.com',
  );
  static const senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID', defaultValue: '1008585753714',
  );
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET', defaultValue: 'jarvis-cea16.firebasestorage.app',
  );

  static FirebaseOptions webOptions({String? apiKey, String? appId}) {
    final key = apiKey ?? webApiKey;
    final id = appId ?? webAppId;
    // Never reuse an Android app ID or fabricate a Web app registration.
    if (key.trim().isEmpty || key.startsWith('REPLACE_') ||
        !id.startsWith('1:$senderId:web:') || id.endsWith(':')) {
      throw const AuthFailure('configuration');
    }
    return FirebaseOptions(
      apiKey: key, appId: id, projectId: projectId,
      messagingSenderId: senderId, authDomain: authDomain,
      storageBucket: storageBucket,
    );
  }

  static Future<FirebaseApp> initialize() async {
    final FirebaseApp app;
    if (kIsWeb) {
      app = await Firebase.initializeApp(options: webOptions());
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // A real google-services.json for com.synchro.synchro is required.
      app = await Firebase.initializeApp();
    } else {
      throw const AuthFailure('unsupported-platform');
    }
    if (app.options.projectId != projectId) {
      throw const AuthFailure('configuration');
    }
    return app;
  }
}
