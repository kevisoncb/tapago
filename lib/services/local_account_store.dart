import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'password_hash.dart';

class LocalAccount {
  const LocalAccount({
    required this.id,
    required this.nome,
    required this.email,
    required this.salt,
    required this.passwordHash,
  });

  final String id;
  final String nome;
  final String email;
  final String salt;
  final String passwordHash;

  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        'email': email,
        'salt': salt,
        'password_hash': passwordHash,
      };

  factory LocalAccount.fromMap(Map<String, dynamic> map) {
    return LocalAccount(
      id: map['id'] as String? ?? '',
      nome: map['nome'] as String? ?? '',
      email: map['email'] as String? ?? '',
      salt: map['salt'] as String? ?? '',
      passwordHash: map['password_hash'] as String? ?? '',
    );
  }
}

class LocalSession {
  const LocalSession({
    required this.id,
    required this.nome,
    required this.email,
  });

  final String id;
  final String nome;
  final String email;
}

class LocalAccountStore {
  static const _accountsKey = 'pago_local_accounts';
  static const _sessionKey = 'pago_session_user_id';
  static const _uuid = Uuid();

  Future<LocalSession?> current() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_sessionKey);
    if (id == null || id.isEmpty) return null;
    final account = _read(prefs).where((item) => item.id == id).firstOrNull;
    if (account == null) return null;
    return LocalSession(id: account.id, nome: account.nome, email: account.email);
  }

  Future<String?> register({
    required String nome,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = _read(prefs);
    final emailKey = email.trim().toLowerCase();
    if (accounts.any((item) => item.email == emailKey)) {
      return 'Já existe uma conta com esse e-mail.';
    }
    final salt = _uuid.v4();
    final account = LocalAccount(
      id: _uuid.v4(),
      nome: nome.trim(),
      email: emailKey,
      salt: salt,
      passwordHash: hashPassword(password, salt),
    );
    accounts.add(account);
    await _write(prefs, accounts);
    await prefs.setString(_sessionKey, account.id);
    return null;
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final emailKey = email.trim().toLowerCase();
    final account =
        _read(prefs).where((item) => item.email == emailKey).firstOrNull;
    if (account == null ||
        hashPassword(password, account.salt) != account.passwordHash) {
      return 'E-mail ou senha incorretos.';
    }
    await prefs.setString(_sessionKey, account.id);
    return null;
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  List<LocalAccount> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .map((item) => LocalAccount.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> _write(SharedPreferences prefs, List<LocalAccount> accounts) {
    return prefs.setString(
      _accountsKey,
      jsonEncode(accounts.map((item) => item.toMap()).toList()),
    );
  }
}
