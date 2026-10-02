import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/app_repository.dart';
import '../utils/constants.dart';

class AppController extends ChangeNotifier {
  AppController(this._repository);

  final AppRepository _repository;
  final _uuid = const Uuid();

  AppUser user = AppUser(
    id: AppConstants.demoUserId,
    nome: '',
    email: '',
    isPremium: false,
    chavePix: '',
  );
  List<Debt> debts = [];
  List<Payment> payments = [];
  bool loading = true;
  String? errorMessage;

  bool get usesFirestore => _repository.usesFirestore;

  List<Debt> get pendingDebts {
    final pending = debts.where((debt) => !debt.statusPago).toList()
      ..sort((a, b) {
        if (a.isOverdue && !b.isOverdue) return -1;
        if (!a.isOverdue && b.isOverdue) return 1;
        return a.dataVencimento.compareTo(b.dataVencimento);
      });
    return pending;
  }

  double get dinheiroNaRua => pendingDebts.fold(
        0,
        (sum, debt) => sum + debt.valorPrincipal,
      );

  double get lucroProjetado => pendingDebts.fold(
        0,
        (sum, debt) => sum + debt.valorAtualizado,
      );

  double get aReceberNaSemana => pendingDebts
      .where((debt) => debt.isDueThisWeek || debt.isOverdue)
      .fold(0, (sum, debt) => sum + debt.valorAtualizado);

  List<Payment> paymentsFor(String debtId) {
    final list = payments.where((item) => item.debtId == debtId).toList()
      ..sort((a, b) => b.data.compareTo(a.data));
    return list;
  }

  bool get reachedFreeLimit =>
      !user.isPremium && pendingDebts.length >= AppConstants.freeDebtLimit;

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      user = await _repository.getCurrentUser();
      debts = await _repository.getDebts();
      payments = await _repository.getPayments();
    } catch (error) {
      errorMessage = 'Não foi possível carregar os dados.';
      debugPrint('$error');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> saveUser(AppUser next) async {
    user = next;
    notifyListeners();
    await _repository.saveUser(next);
  }

  Future<void> upsertDebt(Debt debt) async {
    await _repository.upsertDebt(debt);
    final exists = debts.any((item) => item.id == debt.id);
    if (exists) {
      debts = [
        for (final item in debts)
          if (item.id == debt.id) debt else item,
      ];
    } else {
      debts = [...debts, debt];
    }
    notifyListeners();
  }

  Future<void> addPayment(Payment payment) async {
    await _repository.addPayment(payment);
    payments = [...payments, payment];
    notifyListeners();
  }

  Future<void> markPaid(Debt debt) async {
    await upsertDebt(debt.copyWith(statusPago: true));
  }

  Future<void> activatePremium() async {
    final next = user.copyWith(
      isPremium: true,
      premiumVenceEm: DateTime.now().add(const Duration(days: 30)),
    );
    await saveUser(next);
  }

  String newId() => _uuid.v4();
}
