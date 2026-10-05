import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'app_repository.dart';
import 'auth_messages.dart';
import 'firebase_bootstrap.dart';
import 'local_account_store.dart';
import 'repository_factory.dart';

class SessionGate extends ChangeNotifier {
  SessionGate({LocalAccountStore? accounts})
      : _accounts = accounts ?? LocalAccountStore();

  final LocalAccountStore _accounts;
  StreamSubscription<User?>? _authSub;
  var _firebaseReady = false;
  String? _pendingName;
  String? _pendingPhone;
  DateTime? _pendingAceite;

  bool booting = true;
  String? bootError;
  String? userId;
  AppRepository? repository;

  bool get firebaseReady => _firebaseReady;

  Future<void> bootstrap() async {
    booting = true;
    bootError = null;
    notifyListeners();
    _firebaseReady = await FirebaseBootstrap.tryInit();
    if (_firebaseReady) {
      _authSub = FirebaseAuth.instance.authStateChanges().listen(
        _onFirebaseUser,
        onError: (Object error) {
          bootError = 'Não foi possível verificar a sessão.';
          booting = false;
          debugPrint('$error');
          notifyListeners();
        },
      );
      return;
    }

    final session = await _accounts.current();
    if (session != null) {
      await _openLocal(session);
    }
    booting = false;
    notifyListeners();
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    final invalid = validateAccount(
      nome: '',
      email: email,
      password: password,
      creating: false,
    );
    if (invalid != null) return invalid;

    if (_firebaseReady) {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        return null;
      } on FirebaseAuthException catch (error) {
        return authErrorMessage(error.code);
      }
    }

    final error = await _accounts.signIn(email: email, password: password);
    if (error != null) return error;
    final session = await _accounts.current();
    if (session == null) return 'Não foi possível entrar.';
    await _openLocal(session);
    notifyListeners();
    return null;
  }

  Future<String?> register({
    required String nome,
    required String email,
    required String password,
    String? passwordConfirm,
    String? telefone,
    bool acceptedTerms = false,
  }) async {
    final invalid = validateAccount(
      nome: nome,
      email: email,
      password: password,
      creating: true,
      passwordConfirm: passwordConfirm,
      telefone: telefone,
      acceptedTerms: acceptedTerms,
    );
    if (invalid != null) return invalid;
    final aceite = DateTime.now();
    final phone = (telefone ?? '').replaceAll(RegExp(r'\D'), '');

    if (_firebaseReady) {
      try {
        _pendingName = nome.trim();
        _pendingPhone = phone.isEmpty ? null : phone;
        _pendingAceite = aceite;
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await cred.user?.updateDisplayName(nome.trim());
        await cred.user?.reload();
        return null;
      } on FirebaseAuthException catch (error) {
        _pendingName = null;
        _pendingPhone = null;
        _pendingAceite = null;
        return authErrorMessage(error.code);
      }
    }

    final error = await _accounts.register(
      nome: nome,
      email: email,
      password: password,
    );
    if (error != null) return error;
    final session = await _accounts.current();
    if (session == null) return 'Não foi possível criar a conta.';
    await _openLocal(
      session,
      telefone: phone.isEmpty ? null : phone,
      aceite: aceite,
    );
    notifyListeners();
    return null;
  }

  Future<void> signOut() async {
    if (_firebaseReady) {
      await FirebaseAuth.instance.signOut();
      return;
    }
    await _accounts.signOut();
    repository = null;
    userId = null;
    notifyListeners();
  }

  Future<void> _onFirebaseUser(User? user) async {
    if (user == null) {
      repository = null;
      userId = null;
      booting = false;
      notifyListeners();
      return;
    }

    final email = user.email ?? '';
    final nome = (user.displayName ?? _pendingName ?? email.split('@').first).trim();
    final telefone = _pendingPhone;
    final aceite = _pendingAceite;
    _pendingName = null;
    _pendingPhone = null;
    _pendingAceite = null;
    final profile = AppUser(
      id: user.uid,
      nome: nome.isEmpty ? 'Usuário' : nome,
      email: email,
      isPremium: false,
      chavePix: '',
      telefone: telefone,
      aceiteTermosEm: aceite,
      aceitePrivacidadeEm: aceite,
    );
    try {
      repository = await RepositoryFactory.open(
        userId: user.uid,
        profile: profile,
        firebaseReady: true,
      );
      userId = user.uid;
      bootError = null;
    } catch (error, stack) {
      repository = null;
      userId = null;
      bootError = 'Não foi possível abrir seus dados.';
      debugPrint('$error');
      debugPrint('$stack');
    }
    booting = false;
    notifyListeners();
  }

  Future<void> _openLocal(
    LocalSession session, {
    String? telefone,
    DateTime? aceite,
  }) async {
    final profile = AppUser(
      id: session.id,
      nome: session.nome,
      email: session.email,
      isPremium: false,
      chavePix: '',
      telefone: telefone,
      aceiteTermosEm: aceite,
      aceitePrivacidadeEm: aceite,
    );
    repository = await RepositoryFactory.open(
      userId: session.id,
      profile: profile,
      firebaseReady: false,
    );
    userId = session.id;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
