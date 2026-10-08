import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/firestore_schema.dart';
import '../data/seed_data.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import 'app_repository.dart';

class FirestoreRepository implements AppRepository {
  FirestoreRepository({FirebaseFirestore? firestore, String? userId})
      : _db = firestore ?? FirebaseFirestore.instance,
        _userId = userId ?? AppConstants.demoUserId;

  final FirebaseFirestore _db;
  final String _userId;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(FirestoreSchema.users);

  CollectionReference<Map<String, dynamic>> get _debts =>
      _db.collection(FirestoreSchema.debts);

  CollectionReference<Map<String, dynamic>> get _payments =>
      _db.collection(FirestoreSchema.payments);

  CollectionReference<Map<String, dynamic>> get _boletos =>
      _db.collection(FirestoreSchema.boletos);

  @override
  bool get usesFirestore => true;

  @override
  Future<void> init() async {
    await ensureProfile(SeedData.user().copyWith(id: _userId));
  }

  Future<void> ensureProfile(AppUser profile) async {
    final snap = await _users.doc(profile.id).get();
    if (snap.exists) return;
    await _users.doc(profile.id).set({
      'email': profile.email,
      'nome': profile.nome,
      'chave_pix': profile.chavePix,
      'telefone': profile.telefone,
      'whatsapp_conectado': profile.whatsappConectado,
      'notificacoes_diarias': profile.notificacoesDiarias,
      'acesso_biometrico': profile.acessoBiometrico,
      'banco': profile.banco,
      'agencia': profile.agencia,
      'conta': profile.conta,
      'mensagem_cobranca': profile.mensagemCobranca,
      'aceite_termos_em': profile.aceiteTermosEm,
      'aceite_privacidade_em': profile.aceitePrivacidadeEm,
      'is_premium': false,
    }, SetOptions(merge: true));
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
      'nome': user.nome,
      'chave_pix': user.chavePix,
      'telefone': user.telefone,
      'whatsapp_conectado': user.whatsappConectado,
      'notificacoes_diarias': user.notificacoesDiarias,
      'acesso_biometrico': user.acessoBiometrico,
      'banco': user.banco,
      'agencia': user.agencia,
      'conta': user.conta,
      'mensagem_cobranca': user.mensagemCobranca,
      'aceite_termos_em': user.aceiteTermosEm,
      'aceite_privacidade_em': user.aceitePrivacidadeEm,
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
    await _debts.doc(id).delete();
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

  @override
  Future<List<Boleto>> getBoletos() async {
    final snap = await _boletos.where('user_id', isEqualTo: _userId).get();
    return snap.docs
        .map((doc) => Boleto.fromMap(_withTimestamp(doc.data()), id: doc.id))
        .toList();
  }

  @override
  Future<void> upsertBoleto(Boleto boleto) async {
    await _boletos.doc(boleto.id).set(boleto.toFirestore());
  }

  @override
  Future<void> deleteBoleto(String id) async {
    await _boletos.doc(id).delete();
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
