import '../models/models.dart';

abstract class AppRepository {
  bool get usesFirestore;

  Future<void> init();

  Future<AppUser> getCurrentUser();

  Future<void> saveUser(AppUser user);

  Future<List<Debt>> getDebts();

  Future<void> upsertDebt(Debt debt);

  Future<void> deleteDebt(String id);

  Future<List<Payment>> getPayments({String? debtId});

  Future<void> addPayment(Payment payment);
}
