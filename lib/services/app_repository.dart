import '../models/models.dart';

abstract class AppRepository {
  bool get usesFirestore;

  Future<void> init();

  Future<AppUser> getCurrentUser();

  /// Null when the source has no live updates (local storage).
  Stream<AppUser>? watchCurrentUser();

  Future<void> saveUser(AppUser user);

  Future<List<Debt>> getDebts();

  Future<void> upsertDebt(Debt debt);

  /// Saves a complete installment group as one atomic operation.
  Future<void> upsertDebts(List<Debt> debts);

  Future<void> deleteDebt(String id);

  Future<List<Payment>> getPayments({String? debtId});

  Future<void> addPayment(Payment payment);

  /// Idempotent payment + debt settlement, checked against current records.
  Future<void> recordPayment(Payment payment);

  Future<void> reversePayment(String paymentId, {required String reason});

  Future<List<Bill>> getBills();

  Future<void> upsertBill(Bill bill);

  Future<void> upsertBills(List<Bill> bills);

  Future<void> deleteBill(String id);
}

/// A cache can be displayed, but must not be mistaken for a server refresh.
abstract interface class RepositorySyncStatus {
  bool get usingCachedData;
  DateTime? get lastSyncedAt;
}

/// O que ficou salvo no aparelho na última atualização, para abrir a tela
/// na hora enquanto a internet responde.
class SavedData {
  const SavedData({
    required this.user,
    required this.debts,
    required this.payments,
    required this.bills,
  });

  final AppUser user;
  final List<Debt> debts;
  final List<Payment> payments;
  final List<Bill> bills;
}

abstract interface class SavedDataSource {
  /// Null quando este aparelho ainda não tem dados desta conta.
  Future<SavedData?> readSaved();
}
