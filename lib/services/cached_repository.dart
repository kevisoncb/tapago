import '../models/models.dart';
import 'app_repository.dart';
import 'local_repository.dart';

class CachedRepository implements AppRepository {
  CachedRepository({required this.remote, required this.cache});

  final AppRepository remote;
  final AppRepository cache;

  @override
  bool get usesFirestore => true;

  @override
  Future<void> init() async {}

  @override
  Future<AppUser> getCurrentUser() async {
    try {
      final user = await remote.getCurrentUser();
      await cache.saveUser(user);
      return user;
    } catch (_) {
      return cache.getCurrentUser();
    }
  }

  @override
  Future<void> saveUser(AppUser user) async {
    await remote.saveUser(user);
    await cache.saveUser(user);
  }

  @override
  Future<List<Debt>> getDebts() async {
    try {
      final debts = await remote.getDebts();
      final local = cache;
      if (local is LocalRepository) {
        await local.replaceDebts(debts);
      }
      return debts;
    } catch (_) {
      return cache.getDebts();
    }
  }

  @override
  Future<void> upsertDebt(Debt debt) async {
    await remote.upsertDebt(debt);
    await cache.upsertDebt(debt);
  }

  @override
  Future<void> deleteDebt(String id) async {
    await remote.deleteDebt(id);
    await cache.deleteDebt(id);
  }

  @override
  Future<List<Payment>> getPayments({String? debtId}) async {
    try {
      final payments = await remote.getPayments(debtId: debtId);
      final local = cache;
      if (debtId == null && local is LocalRepository) {
        await local.replacePayments(payments);
      }
      return payments;
    } catch (_) {
      return cache.getPayments(debtId: debtId);
    }
  }

  @override
  Future<void> addPayment(Payment payment) async {
    await remote.addPayment(payment);
    await cache.addPayment(payment);
  }

  @override
  Future<List<Bill>> getBills() async {
    try {
      final bills = await remote.getBills();
      final local = cache;
      if (local is LocalRepository) {
        await local.replaceBills(bills);
      }
      return bills;
    } catch (_) {
      return cache.getBills();
    }
  }

  @override
  Future<void> upsertBill(Bill bill) async {
    await remote.upsertBill(bill);
    await cache.upsertBill(bill);
  }

  @override
  Future<void> deleteBill(String id) async {
    await remote.deleteBill(id);
    await cache.deleteBill(id);
  }
}
