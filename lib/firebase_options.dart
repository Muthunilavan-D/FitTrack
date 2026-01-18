import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyCKUyNtzvV2JoAvixFzr5HhQYBUj7GtMps',
    appId: '1:912229377404:web:YOUR_WEB_APP_ID',
    messagingSenderId: '912229377404',
    projectId: 'fitness-app-516d7',
    authDomain: 'fitness-app-516d7.firebaseapp.com',
    storageBucket: 'fitness-app-516d7.firebasestorage.app',
    measurementId: 'G-MEASUREMENT_ID',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCKUyNtzvV2JoAvixFzr5HhQYBUj7GtMps',
    appId: '1:912229377404:android:92a1eefa3e06398f11b0f9',
    messagingSenderId: '912229377404',
    projectId: 'fitness-app-516d7',
    storageBucket: 'fitness-app-516d7.firebasestorage.app',
  );
} 