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
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'PH_API_KEY',
  appId: 'PH_WEB_APP_ID',
  messagingSenderId: 'PH_MESSAGING_SENDER_ID',
  projectId: 'PH_PROJECT_ID',
  authDomain: 'PH_AUTH_DOMAIN',
  storageBucket: 'PH_STORAGE_BUCKET',
  measurementId: 'PH_MEASUREMENT_ID',
);

static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'PH_API_KEY',
  appId: 'PH_ANDROID_APP_ID',
  messagingSenderId: 'PH_MESSAGING_SENDER_ID',
  projectId: 'PH_PROJECT_ID',
  storageBucket: 'PH_STORAGE_BUCKET',
);

} 
