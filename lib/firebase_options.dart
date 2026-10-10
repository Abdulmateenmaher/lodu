// File generated to mirror the Firebase project `ludo-e88c6`.
// Used by Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
// so that Firebase (and Google Sign In) works on Web as well as Android.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for '
          '$defaultTargetPlatform. Run flutterfire configure to add them.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDdLa1SMbptFmwWfO9G7OZSphTbDeNVoPQ',
    appId: '1:117025729312:android:0109f2c93a8932ce000545',
    messagingSenderId: '117025729312',
    projectId: 'ludo-e88c6',
    databaseURL: 'https://ludo-e88c6-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'ludo-e88c6.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBY1lj9y7_8kLP71085sK95gjnc9oPy6kE',
    appId: '1:117025729312:web:69a5886b6f692df2000545',
    messagingSenderId: '117025729312',
    projectId: 'ludo-e88c6',
    authDomain: 'ludo-e88c6.firebaseapp.com',
    databaseURL: 'https://ludo-e88c6-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'ludo-e88c6.firebasestorage.app',
    measurementId: 'G-9JV21EF8N2',
  );

  // Placeholder until an iOS app is registered; iOS Google Sign In is not in
  // scope for this task. Run `flutterfire configure` to populate real values.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBY1lj9y7_8kLP71085sK95gjnc9oPy6kE',
    appId: '1:117025729312:ios:0000000000000000000000',
    messagingSenderId: '117025729312',
    projectId: 'ludo-e88c6',
    storageBucket: 'ludo-e88c6.firebasestorage.app',
    iosBundleId: 'com.example.lodu',
  );
}
