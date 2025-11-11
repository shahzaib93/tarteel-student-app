// File generated manually for tarteel-quran Firebase project
// This file contains Firebase configuration for all platforms

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDrXbi2vqMua2jwvoEOsdEccUEGZAonIS4',
    appId: '1:51402909238:web:c4160931526c345c7a9a97',
    messagingSenderId: '51402909238',
    projectId: 'tarteel-quran',
    authDomain: 'tarteel-quran.firebaseapp.com',
    storageBucket: 'tarteel-quran.firebasestorage.app',
    measurementId: 'G-RDWBDV3HJ3',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDrXbi2vqMua2jwvoEOsdEccUEGZAonIS4',
    appId: '1:51402909238:android:c4160931526c345c7a9a97',
    messagingSenderId: '51402909238',
    projectId: 'tarteel-quran',
    authDomain: 'tarteel-quran.firebaseapp.com',
    storageBucket: 'tarteel-quran.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDrXbi2vqMua2jwvoEOsdEccUEGZAonIS4',
    appId: '1:51402909238:ios:c4160931526c345c7a9a97',
    messagingSenderId: '51402909238',
    projectId: 'tarteel-quran',
    authDomain: 'tarteel-quran.firebaseapp.com',
    storageBucket: 'tarteel-quran.firebasestorage.app',
    iosBundleId: 'com.tarteel.student',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDrXbi2vqMua2jwvoEOsdEccUEGZAonIS4',
    appId: '1:51402909238:ios:c4160931526c345c7a9a97',
    messagingSenderId: '51402909238',
    projectId: 'tarteel-quran',
    authDomain: 'tarteel-quran.firebaseapp.com',
    storageBucket: 'tarteel-quran.firebasestorage.app',
    iosBundleId: 'com.tarteel.student',
  );
}
