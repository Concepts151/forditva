// Firebase project `forditva-151` (set up by Alex, October 2026).
//
// Values come from the config files Alex sent, kept in
// `.deploy/firebase/` (gitignored). They are passed in code instead of
// through google-services.json / GoogleService-Info.plist, so no Gradle
// plugin or Xcode change is needed.
//
// The apiKey only identifies the Firebase project; it is not a secret.
// Requests are protected by App Check (Play Integrity, see main.dart).
//
// iOS stays a placeholder: Alex registered the iOS app as
// `hu.wirinungarn.forditva`, but the iOS bundle id is
// `hu.wirinungarn.forditva3`, so App Attest would fail. Fill it in once
// Markus confirms iOS and the bundle ids match.
library;

import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (Platform.isIOS) return ios;
    return android;
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyAXLX5KAHHIxEGOrcGoL6rsscvijSbLiX4',
    appId: '1:851863893438:android:c740e257fb79717cefb5ef',
    messagingSenderId: '851863893438',
    projectId: 'forditva-151',
    storageBucket: 'forditva-151.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    iosBundleId: 'hu.wirinungarn.forditva3',
  );
}
