import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/firestore_schema.dart';
import '../models/models.dart';
import 'app_repository.dart';

class FirestoreRepository implements AppRepository {
  factory FirestoreRepository({
    FirebaseFirestore? firestore,
    required String userId,
  }) {
    return FirestoreRepository._(
      firestore ?? FirebaseFirestore.instance,
      userId,
    );
  }

  FirestoreRepository._(this._db, this._userId);

  final FirebaseFirestore _db;
  final String _userId;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(FirestoreSchema.users);

  CollectionReference<Map<String, dynamic>> get _debts =>
      _db.collection(FirestoreSchema.debts);

  CollectionReference<Map<String, dynamic>> get _payments =>
      _db.collection(FirestoreSchema.payments);

  @override
  bool get usesFirestore => true;

  @override
  Future<void> init() async {}

  Future<void> ensureProfile(AppUser profile) async {
    final snap = await _users.doc(_userId).get();
    if (snap.exists) return;
    await saveUser(profile);
  }

  @override
  Future<AppUser> getCurrentUser() async {
    final snap = await _users.doc(_userId).get();
    final data = snap.data() ?? {};
    return AppUser.fromMap(data, id: _userId);
  }

  @override
  Future<void> saveUser(AppUser user) async {
    await _users.doc(user.id).set({
      'email': user.email,
      'is_premium': user.isPremium,
      'chave_pix': user.chavePix,
      'nome': user.nome,
      'notificacoes_diarias': user.notificacoesDiarias,
      'acesso_biometrico': user.acessoBiometrico,
      'banco': user.banco,
      'agencia': user.agencia,
      'conta': user.conta,
      'premium_vence_em': user.premiumVenceEm,
      'premium_transaction_id': user.premiumTransactionId,
    }, SetOptions(merge: true));
  }

  @override
  Future<List<Debt>> getDebts() async {
    final snap = await _debts.where('user_id', isEqualTo: _userId).get();
    return snap.docs
        .map((doc) => Debt.fromMap(_withTimestamp(doc.data()), id: doc.id))
        .toList();
  }

  @override
  Future<void> upsertDebt(Debt debt) async {
    await _debts.doc(debt.id).set(debt.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteDebt(String id) async {
    final payments = await _payments
        .where('user_id', isEqualTo: _userId)
        .where('debt_id', isEqualTo: id)
        .get();
    final batch = _db.batch();
    for (final doc in payments.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_debts.doc(id));
    await batch.commit();
  }

  @override
  Future<List<Payment>> getPayments({String? debtId}) async {
    Query<Map<String, dynamic>> query =
        _payments.where('user_id', isEqualTo: _userId);
    if (debtId != null) {
      query = query.where('debt_id', isEqualTo: debtId);
    }
    final snap = await query.get();
    return snap.docs
        .map((doc) => Payment.fromMap(_withTimestamp(doc.data()), id: doc.id))
        .toList();
  }

  @override
  Future<void> addPayment(Payment payment) async {
    await _payments.doc(payment.id).set(payment.toFirestore());
  }

  Map<String, dynamic> _withTimestamp(Map<String, dynamic> data) {
    final mapped = Map<String, dynamic>.from(data);
    for (final key in mapped.keys.toList()) {
      final value = mapped[key];
      if (value is Timestamp) {
        mapped[key] = value.toDate();
      }
    }
    return mapped;
  }
}
