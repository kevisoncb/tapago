import 'dart:async';

import 'package:flutter/foundation.dart';

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
    final saved = await cache.getCurrentUser();
    if (saved.email.isEmpty && saved.nome.isEmpty) {
      // Primeira vez neste aparelho: o perfil precisa existir antes de abrir.
      await remote.ensureProfile(profile);
    } else {
      // Já entrou aqui antes: abre na hora, mesmo sem internet, e confere o
      // perfil em segundo plano.
      unawaited(
        remote
            .ensureProfile(profile)
            .catchError(
              (Object error) => debugPrint('Perfil: ${error.runtimeType}'),
            ),
      );
    }
    return CachedRepository(remote: remote, cache: cache);
  }
}
