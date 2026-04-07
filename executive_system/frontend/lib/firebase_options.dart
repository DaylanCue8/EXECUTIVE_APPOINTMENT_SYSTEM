import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCMP5RbBSnBr23Jix2ixKvNPhhCn18QQh8', 
    appId: '1:616328184468:android:e3b5eca7d669c7c85d6a81', // Updated from your screenshot
    messagingSenderId: '616328184468',
    projectId: 'executivesystem',
    storageBucket: 'executivesystem.appspot.com',
  );
}