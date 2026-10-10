import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'app_repository.dart';

class LocalRepository implements AppRepository {
  LocalRepository({required this.userId});

  final String userId;

  String get _userKey => 'pago_${userId}_user';
  String get _debtsKey => 'pago_${userId}_debts';
  String get _paymentsKey => 'pago_${userId}_payments';
  String get _billsKey => 'pago_${userId}_bills';

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
    return _decodeList(_debtsKey).map(Debt.fromMap).toList();
  }

  Future<void> replaceDebts(List<Debt> debts) async {
    await _prefs.setString(
      _debtsKey,
      jsonEncode(debts.map((item) => item.toMap()).toList()),
    );
  }

  @override
  Future<void> upsertDebt(Debt debt) async {
    final current = await getDebts();
    final next = [
      ...current.where((item) => item.id != debt.id),
      debt,
    ];
    await replaceDebts(next);
  }

  @override
  Future<void> deleteDebt(String id) async {
    final current = await getDebts();
    await replaceDebts(current.where((item) => item.id != id).toList());
    final payments = await getPayments();
    await replacePayments(payments.where((item) => item.debtId != id).toList());
  }

  @override
  Future<List<Payment>> getPayments({String? debtId}) async {
    final list = _decodeList(_paymentsKey).map(Payment.fromMap).toList();
    if (debtId == null) return list;
    return list.where((item) => item.debtId == debtId).toList();
  }

  Future<void> replacePayments(List<Payment> payments) async {
    await _prefs.setString(
      _paymentsKey,
      jsonEncode(payments.map((item) => item.toMap()).toList()),
    );
  }

  @override
  Future<void> addPayment(Payment payment) async {
    final current = await getPayments();
    final next = [
      ...current.where((item) => item.id != payment.id),
      payment,
    ];
    await replacePayments(next);
  }

  @override
  Future<List<Bill>> getBills() async {
    return _decodeList(_billsKey).map(Bill.fromMap).toList();
  }

  Future<void> replaceBills(List<Bill> bills) async {
    await _prefs.setString(
      _billsKey,
      jsonEncode(bills.map((item) => item.toMap()).toList()),
    );
  }

  @override
  Future<void> upsertBill(Bill bill) async {
    final current = await getBills();
    await replaceBills([
      ...current.where((item) => item.id != bill.id),
      bill,
    ]);
  }

  @override
  Future<void> deleteBill(String id) async {
    final current = await getBills();
    await replaceBills(current.where((item) => item.id != id).toList());
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
