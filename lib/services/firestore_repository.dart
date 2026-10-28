import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/firestore_schema.dart';
import '../data/seed_data.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import 'app_repository.dart';
import 'payment_ledger.dart';

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

  CollectionReference<Map<String, dynamic>> get _bills =>
      _db.collection(FirestoreSchema.bills);

  @override
  bool get usesFirestore => true;

  @override
  Future<void> init() async {
    await ensureProfile(SeedData.user().copyWith(id: _userId));
  }

  Future<void> ensureProfile(AppUser profile) async {
    final snap = await _users
        .doc(profile.id)
        .get(const GetOptions(source: Source.server));
    if (snap.exists) return;
    await _users.doc(profile.id).set({
      'email': profile.email,
      'nome': profile.nome,
      'chave_pix': profile.chavePix,
      'telefone': profile.telefone,
      'whatsapp_conectado': profile.whatsappConectado,
      'notificacoes_diarias': profile.notificacoesDiarias,
      'lembretes_acompanhamento': profile.lembretesAcompanhamento,
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
    final snap = await _users
        .doc(_userId)
        .get(const GetOptions(source: Source.server));
    final data = snap.data() ?? {};
    return AppUser.fromMap(data, id: _userId);
  }

  @override
  Stream<AppUser> watchCurrentUser() => _users
      .doc(_userId)
      .snapshots()
      .where((snap) => snap.exists)
      .map((snap) => AppUser.fromMap(snap.data() ?? {}, id: _userId));

  @override
  Future<void> saveUser(AppUser user) async {
    await _users.doc(user.id).set({
      'email': user.email,
      'nome': user.nome,
      'chave_pix': user.chavePix,
      'telefone': user.telefone,
      'whatsapp_conectado': user.whatsappConectado,
      'notificacoes_diarias': user.notificacoesDiarias,
      'lembretes_acompanhamento': user.lembretesAcompanhamento,
      'acesso_biometrico': user.acessoBiometrico,
      'banco': user.banco,
      'agencia': user.agencia,
      'conta': user.conta,
      'mensagem_cobranca': user.mensagemCobranca,
      'mensagem_atraso': user.mensagemAtraso,
      'mensagem_atraso_forte': user.mensagemAtrasoForte,
      'aceite_termos_em': user.aceiteTermosEm,
      'aceite_privacidade_em': user.aceitePrivacidadeEm,
    }, SetOptions(merge: true));
  }

  @override
  Future<List<Debt>> getDebts() async {
    final snap = await _debts
        .where('user_id', isEqualTo: _userId)
        .get(const GetOptions(source: Source.server));
    return snap.docs
        .map((doc) => Debt.fromMap(_withTimestamp(doc.data()), id: doc.id))
        .toList();
  }

  @override
  Future<void> upsertDebt(Debt debt) async {
    await upsertDebts([debt]);
  }

  @override
  Future<void> upsertDebts(List<Debt> debts) async {
    if (debts.isEmpty) return;
    if (debts.length > 12 || debts.any((debt) => debt.userId != _userId)) {
      throw StateError('Grupo de lançamentos inválido.');
    }
    final batch = _db.batch();
    for (final debt in debts) {
      batch.set(
        _debts.doc(debt.id),
        debt.toFirestore(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  @override
  Future<void> deleteDebt(String id) async {
    await _debts.doc(id).delete();
  }

  @override
  Future<List<Payment>> getPayments({String? debtId}) async {
    Query<Map<String, dynamic>> query = _payments.where(
      'user_id',
      isEqualTo: _userId,
    );
    if (debtId != null) {
      query = query.where('debt_id', isEqualTo: debtId);
    }
    final snap = await query.get(const GetOptions(source: Source.server));
    return snap.docs
        .map((doc) => Payment.fromMap(_withTimestamp(doc.data()), id: doc.id))
        .toList();
  }

  @override
  Future<void> addPayment(Payment payment) async {
    await recordPayment(payment);
  }

  @override
  Future<void> recordPayment(Payment payment) async {
    if (payment.userId != _userId) {
      throw StateError('O pagamento não pertence à conta atual.');
    }
    await _changeLedger(payment.debtId, payment.id, (debt, ledger, existing) {
      if (existing != null) {
        if (!samePayment(existing, payment)) {
          throw StateError('Este registro já foi usado por outro pagamento.');
        }
        return null; // Retrying an acknowledged operation must not charge twice.
      }
      validatePayment(debt, ledger, payment);
      return payment;
    });
  }

  @override
  Future<void> reversePayment(
    String paymentId, {
    required String reason,
  }) async {
    final clean = reason.trim();
    if (clean.isEmpty || clean.length > 200) {
      throw StateError('Informe o motivo do estorno (até 200 caracteres).');
    }
    final target = await _payments
        .doc(paymentId)
        .get(const GetOptions(source: Source.server));
    if (!target.exists) throw StateError('Pagamento não encontrado.');
    final payment = Payment.fromMap(
      _withTimestamp(target.data()!),
      id: target.id,
    );
    if (payment.userId != _userId) {
      throw StateError('Pagamento de outra conta.');
    }
    await _changeLedger(payment.debtId, paymentId, (debt, ledger, existing) {
      if (existing == null) throw StateError('Pagamento não encontrado.');
      if (existing.estornado) return null;
      return existing.copyWith(
        estornadoEm: DateTime.now(),
        estornoMotivo: clean,
      );
    });
  }

  /// Queries are outside the mobile transaction. A parent revision turns the
  /// fetched ledger into an optimistic snapshot; mismatch repeats the query.
  /// Rules require every write on an initialized ledger to advance this same
  /// revision. Older app versions can still read it, but must update to pay it.
  Future<void> _changeLedger(
    String debtId,
    String paymentId,
    Payment? Function(Debt debt, List<Payment> ledger, Payment? existing)
    change,
  ) async {
    final debtRef = _debts.doc(debtId);
    final paymentRef = _payments.doc(paymentId);
    for (var attempt = 0; attempt < 5; attempt++) {
      final before = await debtRef.get(const GetOptions(source: Source.server));
      if (!before.exists || before.data()?['user_id'] != _userId) {
        throw StateError('Caderneta não encontrada nesta conta.');
      }
      final revision =
          (before.data()?['ledger_revision'] as num?)?.toInt() ?? 0;
      final snapshots = await _payments
          .where('user_id', isEqualTo: _userId)
          .where('debt_id', isEqualTo: debtId)
          .limit(401)
          .get(const GetOptions(source: Source.server));
      if (snapshots.docs.length > 400) {
        throw StateError(
          'Este histórico precisa de atendimento para uma operação segura.',
        );
      }
      try {
        await _db.runTransaction((transaction) async {
          final current = await transaction.get(debtRef);
          final stored = await transaction.get(paymentRef);
          if (!current.exists || current.data()?['user_id'] != _userId) {
            throw StateError('Caderneta não encontrada nesta conta.');
          }
          final data = current.data()!;
          if (((data['ledger_revision'] as num?)?.toInt() ?? 0) != revision ||
              data['valor_principal'] != before.data()?['valor_principal'] ||
              data['taxa_juros'] != before.data()?['taxa_juros'] ||
              data['status_pago'] != before.data()?['status_pago']) {
            throw const _LedgerChanged();
          }
          final debt = Debt.fromMap(_withTimestamp(data), id: debtId);
          final ledger = <Payment>[];
          for (final snapshot in snapshots.docs) {
            final latest = snapshot.id == stored.id
                ? stored
                : await transaction.get(snapshot.reference);
            if (latest.exists) {
              ledger.add(
                Payment.fromMap(_withTimestamp(latest.data()!), id: latest.id),
              );
            }
          }
          final existing = stored.exists
              ? Payment.fromMap(_withTimestamp(stored.data()!), id: stored.id)
              : null;
          final next = change(debt, ledger, existing);
          if (next == null) return;
          final nextLedger = [
            ...ledger.where((item) => item.id != next.id),
            next,
          ];
          final balance = ledgerBalance(debt, nextLedger);
          final paymentData = next.toFirestore();
          if (next.estornado && !(existing?.estornado ?? false)) {
            paymentData['estornado_em'] = FieldValue.serverTimestamp();
          }
          transaction.set(paymentRef, paymentData);
          transaction.update(debtRef, {
            'status_pago': balance.quitado,
            'ledger_revision': revision + 1,
            'ledger_payment_id': next.id,
          });
        });
        return;
      } on _LedgerChanged {
        // The other session committed first. Re-read its payment as well.
        continue;
      }
    }
    throw StateError(
      'A caderneta foi alterada em outro aparelho. Atualize e tente novamente.',
    );
  }

  @override
  Future<List<Bill>> getBills() async {
    final snap = await _bills
        .where('user_id', isEqualTo: _userId)
        .get(const GetOptions(source: Source.server));
    return snap.docs
        .map((doc) => Bill.fromMap(_withTimestamp(doc.data()), id: doc.id))
        .toList();
  }

  @override
  Future<void> upsertBill(Bill bill) async {
    await upsertBills([bill]);
  }

  @override
  Future<void> upsertBills(List<Bill> bills) async {
    if (bills.isEmpty) return;
    if (bills.length > 12 || bills.any((bill) => bill.userId != _userId)) {
      throw StateError('Grupo de boletos inválido.');
    }
    final batch = _db.batch();
    for (final bill in bills) {
      batch.set(_bills.doc(bill.id), bill.toFirestore());
    }
    await batch.commit();
  }

  @override
  Future<void> deleteBill(String id) async {
    await _bills.doc(id).delete();
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

class _LedgerChanged implements Exception {
  const _LedgerChanged();
}
