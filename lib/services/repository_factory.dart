import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'app_repository.dart';
import 'firestore_repository.dart';
import 'local_repository.dart';

class RepositoryFactory {
  static Future<AppRepository> create() async {
    const useFirebase = bool.fromEnvironment('USE_FIREBASE', defaultValue: false);

    if (!useFirebase) {
      final local = LocalRepository();
      await local.init();
      return local;
    }

    try {
      await Firebase.initializeApp();
      final remote = FirestoreRepository();
      await remote.init();
      return remote;
    } catch (error, stack) {
      debugPrint('Firestore indisponível, usando dados locais: $error');
      debugPrint('$stack');
      final local = LocalRepository();
      await local.init();
      return local;
    }
  }
}
