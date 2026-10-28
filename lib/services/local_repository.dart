import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'app_repository.dart';
import 'payment_ledger.dart';

class LocalRepository implements AppRepository {
  LocalRepository({required this.userId});

  final String userId;

  String get _userKey => 'pago_${userId}_user';
  String get _debtsKey => 'pago_${userId}_debts';
  String get _paymentsKey => 'pago_${userId}_payments';
  String get _billsKey => 'pago_${userId}_bills';
  String get _financialKey => 'pago_${userId}_finance_v1';

  static final _pending = <String, Future<void>>{};

  late SharedPreferences _prefs;

  @override
  bool get usesFirestore => false;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Stream<AppUser>? watchCurrentUser() => null;

  @override
  Future<AppUser> getCurrentUser() async {
    final raw = _prefs.getString(_userKey);
    if (raw == null) {
      return AppUser(
        id: userId,
        nome: '',
        email: '',
        isPremium: false,
        chavePix: '',
      );
    }
    return AppUser.fromMap(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveUser(AppUser user) async {
    await _prefs.setString(_userKey, jsonEncode(user.toMap()));
  }

  @override
  Future<List<Debt>> getDebts() async {
    return _financialList('debts', _debtsKey).map(Debt.fromMap).toList();
  }

  Future<void> replaceDebts(List<Debt> debts) async {
    await _exclusive(() => _writeFinancial(debts: debts));
  }

  @override
  Future<void> upsertDebt(Debt debt) async {
    await upsertDebts([debt]);
  }

  @override
  Future<void> upsertDebts(List<Debt> debts) async {
    if (debts.length > 12 || debts.any((debt) => debt.userId != userId)) {
      throw StateError('Grupo de lançamentos inválido.');
    }
    await _exclusive(() async {
      final ids = debts.map((debt) => debt.id).toSet();
      final current = await getDebts();
      await _writeFinancial(
        debts: [...current.where((debt) => !ids.contains(debt.id)), ...debts],
      );
    });
  }

  @override
  Future<void> deleteDebt(String id) async {
    await _exclusive(() async {
      final payments = await getPayments();
      if (payments.any((payment) => payment.debtId == id)) {
        throw StateError(
          'Esta caderneta possui histórico de pagamentos e não pode ser apagada.',
        );
      }
      final debts = await getDebts();
      await _writeFinancial(
        debts: debts.where((debt) => debt.id != id).toList(),
      );
    });
  }

  @override
  Future<List<Payment>> getPayments({String? debtId}) async {
    final list = _financialList(
      'payments',
      _paymentsKey,
    ).map(Payment.fromMap).toList();
    if (debtId == null) return list;
    return list.where((item) => item.debtId == debtId).toList();
  }

  Future<void> replacePayments(List<Payment> payments) async {
    await _exclusive(() => _writeFinancial(payments: payments));
  }

  @override
  Future<void> addPayment(Payment payment) async {
    await recordPayment(payment);
  }

  @override
  Future<void> recordPayment(Payment payment) async {
    await _exclusive(() async {
      final debts = await getDebts();
      final payments = await getPayments();
      final existing = payments
          .where((item) => item.id == payment.id)
          .firstOrNull;
      if (existing != null) {
        if (!samePayment(existing, payment)) {
          throw StateError('Este registro já foi usado por outro pagamento.');
        }
        return;
      }
      final debt = debts.where((item) => item.id == payment.debtId).firstOrNull;
      if (debt == null || debt.userId != userId || payment.userId != userId) {
        throw StateError('Caderneta não encontrada nesta conta.');
      }
      validatePayment(
        debt,
        payments.where((item) => item.debtId == debt.id),
        payment,
      );
      final nextPayments = [...payments, payment];
      final balance = ledgerBalance(
        debt,
        nextPayments.where((item) => item.debtId == debt.id),
      );
      await _writeFinancial(
        payments: nextPayments,
        debts: [
          for (final item in debts)
            item.id == debt.id
                ? item.copyWith(statusPago: balance.quitado)
                : item,
        ],
      );
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
    await _exclusive(() async {
      final debts = await getDebts();
      final payments = await getPayments();
      final payment = payments
          .where((item) => item.id == paymentId)
          .firstOrNull;
      if (payment == null || payment.userId != userId) {
        throw StateError('Pagamento não encontrado.');
      }
      if (payment.estornado) return;
      final debt = debts.where((item) => item.id == payment.debtId).firstOrNull;
      if (debt == null) throw StateError('Caderneta não encontrada.');
      final nextPayments = [
        for (final item in payments)
          item.id == paymentId
              ? item.copyWith(estornadoEm: DateTime.now(), estornoMotivo: clean)
              : item,
      ];
      final balance = ledgerBalance(
        debt,
        nextPayments.where((item) => item.debtId == debt.id),
      );
      await _writeFinancial(
        payments: nextPayments,
        debts: [
          for (final item in debts)
            item.id == debt.id
                ? item.copyWith(statusPago: balance.quitado)
                : item,
        ],
      );
    });
  }

  @override
  Future<List<Bill>> getBills() async {
    return _financialList('bills', _billsKey).map(Bill.fromMap).toList();
  }

  Future<void> replaceBills(List<Bill> bills) async {
    await _exclusive(() => _writeFinancial(bills: bills));
  }

  @override
  Future<void> upsertBill(Bill bill) async {
    await upsertBills([bill]);
  }

  @override
  Future<void> upsertBills(List<Bill> bills) async {
    if (bills.length > 12 || bills.any((bill) => bill.userId != userId)) {
      throw StateError('Grupo de boletos inválido.');
    }
    await _exclusive(() async {
      final ids = bills.map((bill) => bill.id).toSet();
      await _writeFinancial(
        bills: [
          ...(await getBills()).where((item) => !ids.contains(item.id)),
          ...bills,
        ],
      );
    });
  }

  @override
  Future<void> deleteBill(String id) async {
    await _exclusive(() async {
      final current = await getBills();
      await _writeFinancial(
        bills: current.where((item) => item.id != id).toList(),
      );
    });
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final previous = _pending[userId] ?? Future<void>.value();
    final release = Completer<void>();
    _pending[userId] = release.future;
    try {
      await previous;
      return await action();
    } finally {
      release.complete();
      if (identical(_pending[userId], release.future)) _pending.remove(userId);
    }
  }

  List<Map<String, dynamic>> _financialList(String field, String legacyKey) {
    final raw = _prefs.getString(_financialKey);
    if (raw == null) return _decodeList(legacyKey);
    final list =
        (jsonDecode(raw) as Map<String, dynamic>)[field] as List? ?? [];
    return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  /// One preference write is the commit point for related financial lists.
  /// Existing keys remain readable for migration and are retained unchanged.
  Future<void> _writeFinancial({
    List<Debt>? debts,
    List<Payment>? payments,
    List<Bill>? bills,
  }) async {
    final data = {
      'debts': (debts ?? await getDebts()).map((item) => item.toMap()).toList(),
      'payments': (payments ?? await getPayments())
          .map((item) => item.toMap())
          .toList(),
      'bills': (bills ?? await getBills()).map((item) => item.toMap()).toList(),
    };
    if (!await _prefs.setString(_financialKey, jsonEncode(data))) {
      throw StateError('Não foi possível salvar os dados neste aparelho.');
    }
  }

  List<Map<String, dynamic>> _decodeList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }
}
