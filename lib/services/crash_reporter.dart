import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Envia travamentos do app para o Firebase Crashlytics (só Android/iOS em release).
class CrashReporter {
  static var _on = false;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> start() async {
    if (!_supported) return;
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    if (kDebugMode) return;
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
    _on = true;
  }

  static Future<void> setUser(String? uid) async {
    if (!_on) return;
    await FirebaseCrashlytics.instance.setUserIdentifier(uid ?? '');
  }
}
