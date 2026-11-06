import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for project incline-b00c5.
/// Generated from official Firebase credentials for package com.incline.incline_app.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB6HI2g52uVK6a3HBN0GCYrGSN5L-x3kAI',
    appId: '1:1423494686:android:8b98a42ae9062d633ea80f',
    messagingSenderId: '1423494686',
    projectId: 'incline-b00c5',
    storageBucket: 'incline-b00c5.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD80b1pbEg8f33u-7lyz-RkLyDXnIFJpXg',
    appId: '1:1423494686:ios:f8553d99b711027c3ea80f',
    messagingSenderId: '1423494686',
    projectId: 'incline-b00c5',
    storageBucket: 'incline-b00c5.firebasestorage.app',
    iosBundleId: 'com.incline.inclineApp',
  );
}
