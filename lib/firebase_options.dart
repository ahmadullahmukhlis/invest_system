// Generated placeholder file.
// Run `flutterfire configure` to replace these values with real options.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError('Firebase is not supported on Linux.');
      case TargetPlatform.fuchsia:
        throw UnsupportedError('Firebase is not supported on Fuchsia.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBLDd_nzLpnLs9eKyhsE635BBnZAHKg320',
    appId: '1:816397432153:web:b6dc66b7b7da57808e0848',
    messagingSenderId: '816397432153',
    projectId: 'realt-time-database',
    authDomain: 'realt-time-database.firebaseapp.com',
    databaseURL: 'https://realt-time-database-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'realt-time-database.firebasestorage.app',
    measurementId: 'G-6MZEN91DM0',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA5b4I4ovuq3Fgti2aYO0PUJWV0-2D3MbM',
    appId: '1:816397432153:android:dd82556830e362258e0848',
    messagingSenderId: '816397432153',
    projectId: 'realt-time-database',
    databaseURL: 'https://realt-time-database-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'realt-time-database.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCtyFupuUnDDkz4MgG889B7bKys61ArJlA',
    appId: '1:816397432153:ios:ac20d46a4ed984438e0848',
    messagingSenderId: '816397432153',
    projectId: 'realt-time-database',
    databaseURL: 'https://realt-time-database-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'realt-time-database.firebasestorage.app',
    iosClientId: '816397432153-rjmvsiuv1bfqvdjvea45evd8q9v60eev.apps.googleusercontent.com',
    iosBundleId: 'com.example.investSystem',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCtyFupuUnDDkz4MgG889B7bKys61ArJlA',
    appId: '1:816397432153:ios:ac20d46a4ed984438e0848',
    messagingSenderId: '816397432153',
    projectId: 'realt-time-database',
    databaseURL: 'https://realt-time-database-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'realt-time-database.firebasestorage.app',
    iosClientId: '816397432153-rjmvsiuv1bfqvdjvea45evd8q9v60eev.apps.googleusercontent.com',
    iosBundleId: 'com.example.investSystem',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBLDd_nzLpnLs9eKyhsE635BBnZAHKg320',
    appId: '1:816397432153:web:0975855aa9a3114a8e0848',
    messagingSenderId: '816397432153',
    projectId: 'realt-time-database',
    authDomain: 'realt-time-database.firebaseapp.com',
    databaseURL: 'https://realt-time-database-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'realt-time-database.firebasestorage.app',
    measurementId: 'G-93J5YQ8K36',
  );

}