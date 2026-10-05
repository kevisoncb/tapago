import '../models/models.dart';
import 'app_repository.dart';
import 'cached_repository.dart';
import 'firestore_repository.dart';
import 'local_repository.dart';

class RepositoryFactory {
  static Future<AppRepository> open({
    required String userId,
    required AppUser profile,
    required bool firebaseReady,
  }) async {
    final cache = LocalRepository(userId: userId);
    await cache.init();
    if (!firebaseReady) {
      final existing = await cache.getCurrentUser();
      if (existing.email.isEmpty && existing.nome.isEmpty) {
        await cache.saveUser(profile);
      }
      return cache;
    }

    final remote = FirestoreRepository(userId: userId);
    await remote.ensureProfile(profile);
    return CachedRepository(remote: remote, cache: cache);
  }
}
