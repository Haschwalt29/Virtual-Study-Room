// File generated based on firebase.json configuration
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
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
        return windows;
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
    apiKey: 'AIzaSyB3jdm-FcoQlTfnkKqTXyaM-goxfKIB4Ro',
    appId: '1:882408969195:web:f7cd42d27e16de0b827fae',
    messagingSenderId: '882408969195',
    projectId: 'virtual-study-room-4d8c0',
    authDomain: 'virtual-study-room-4d8c0.firebaseapp.com',
    storageBucket: 'virtual-study-room-4d8c0.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB3jdm-FcoQlTfnkKqTXyaM-goxfKIB4Ro',
    appId: '1:882408969195:android:f6031cc75f363e10827fae',
    messagingSenderId: '882408969195',
    projectId: 'virtual-study-room-4d8c0',
    storageBucket: 'virtual-study-room-4d8c0.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB3jdm-FcoQlTfnkKqTXyaM-goxfKIB4Ro',
    appId: '1:882408969195:ios:e948ca40f0ddfcd9827fae',
    messagingSenderId: '882408969195',
    projectId: 'virtual-study-room-4d8c0',
    storageBucket: 'virtual-study-room-4d8c0.firebasestorage.app',
    iosClientId: '882408969195-ios-client-id.apps.googleusercontent.com',
    iosBundleId: 'com.example.study_room',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB3jdm-FcoQlTfnkKqTXyaM-goxfKIB4Ro',
    appId: '1:882408969195:ios:e948ca40f0ddfcd9827fae',
    messagingSenderId: '882408969195',
    projectId: 'virtual-study-room-4d8c0',
    storageBucket: 'virtual-study-room-4d8c0.firebasestorage.app',
    iosClientId: '882408969195-ios-client-id.apps.googleusercontent.com',
    iosBundleId: 'com.example.study_room',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyB3jdm-FcoQlTfnkKqTXyaM-goxfKIB4Ro',
    appId: '1:882408969195:web:f8645eb92f966ba4827fae',
    messagingSenderId: '882408969195',
    projectId: 'virtual-study-room-4d8c0',
    storageBucket: 'virtual-study-room-4d8c0.firebasestorage.app',
    authDomain: 'virtual-study-room-4d8c0.firebaseapp.com',
  );
}