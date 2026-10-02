import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/seed_data.dart';
import '../models/models.dart';
import 'app_repository.dart';

class LocalRepository implements AppRepository {
  static const _userKey = 'tapago_user';
  static const _debtsKey = 'tapago_debts';
  static const _paymentsKey = 'tapago_payments';

  late SharedPreferences _prefs;

  @override
  bool get usesFirestore => false;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_prefs.containsKey(_userKey)) {
      await saveUser(SeedData.user());
      for (final debt in SeedData.debts()) {
        await upsertDebt(debt);
      }
      for (final payment in SeedData.payments()) {
        await addPayment(payment);
      }
    }
  }

  @override
  Future<AppUser> getCurrentUser() async {
    final raw = _prefs.getString(_userKey);
    if (raw == null) return SeedData.user();
    return AppUser.fromMap(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveUser(AppUser user) async {
    await _prefs.setString(_userKey, jsonEncode(user.toMap()));
  }

  @override
  Future<List<Debt>> getDebts() async {
    final list = _decodeList(_debtsKey);
    return list.map(Debt.fromMap).toList();
  }

  @override
  Future<void> upsertDebt(Debt debt) async {
    final current = await getDebts();
    final next = [
      ...current.where((item) => item.id != debt.id),
      debt,
    ];
    await _prefs.setString(
      _debtsKey,
      jsonEncode(next.map((item) => item.toMap()).toList()),
    );
  }

  @override
  Future<void> deleteDebt(String id) async {
    final current = await getDebts();
    final next = current.where((item) => item.id != id).toList();
    await _prefs.setString(
      _debtsKey,
      jsonEncode(next.map((item) => item.toMap()).toList()),
    );
  }

  @override
  Future<List<Payment>> getPayments({String? debtId}) async {
    final list = _decodeList(_paymentsKey).map(Payment.fromMap).toList();
    if (debtId == null) return list;
    return list.where((item) => item.debtId == debtId).toList();
  }

  @override
  Future<void> addPayment(Payment payment) async {
    final current = await getPayments();
    final next = [...current, payment];
    await _prefs.setString(
      _paymentsKey,
      jsonEncode(next.map((item) => item.toMap()).toList()),
    );
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
