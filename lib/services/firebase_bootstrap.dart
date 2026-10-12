import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'crash_reporter.dart';

class FirebaseBootstrap {
  static Future<bool> tryInit() async {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (_isPlaceholder(options)) return false;
      await Firebase.initializeApp(options: options);
      try {
        await CrashReporter.start();
      } catch (error) {
        debugPrint('Crashlytics não iniciado: $error');
      }
      return true;
    } catch (error, stack) {
      debugPrint('Firebase não iniciado: $error');
      debugPrint('$stack');
      return false;
    }
  }

  static bool _isPlaceholder(FirebaseOptions options) {
    return options.apiKey.startsWith('REPLACE') ||
        options.appId.startsWith('REPLACE') ||
        options.projectId.startsWith('REPLACE');
  }
}
