import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/app_repository.dart';
import '../services/billing_service.dart';
import '../services/biometric_service.dart';
import '../services/debt_balance.dart';
import '../services/reminder_service.dart';
import '../services/trust_score.dart';
import '../utils/constants.dart';

class AppController extends ChangeNotifier {
  AppController(
    this._repository, {
    required this.onSignOut,
    BillingService? billing,
    ReminderService? reminders,
    BiometricService? biometrics,
  })  : _billing = billing ?? BillingService(),
        _reminders = reminders ?? ReminderService(),
        _biometrics = biometrics ?? BiometricService() {
    _billing.onUpdate = handlePurchase;
  }

  final AppRepository _repository;
  final Future<void> Function() onSignOut;
  final BillingService _billing;
  final ReminderService _reminders;
  final BiometricService _biometrics;
  final _uuid = const Uuid();
  var _disposed = false;

  AppUser user = const AppUser(
    id: '',
    nome: '',
    email: '',
    isPremium: false,
    chavePix: '',
  );
  List<Debt> debts = [];
  List<Payment> payments = [];
  bool loading = true;
  bool billingBusy = false;
  String? errorMessage;
  String? billingMessage;

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
        (sum, debt) => sum + balanceFor(debt).principalRestante,
      );

  double get lucroProjetado => pendingDebts.fold(
        0,
        (sum, debt) => sum + balanceFor(debt).jurosRestantes,
      );

  double get aReceberNaSemana => pendingDebts
      .where((debt) => debt.isDueThisWeek || debt.isOverdue)
      .fold(0, (sum, debt) => sum + balanceFor(debt).saldo);

  List<Payment> paymentsFor(String debtId) {
    final list = payments.where((item) => item.debtId == debtId).toList()
      ..sort((a, b) => b.data.compareTo(a.data));
    return list;
  }

  DebtBalance balanceFor(Debt debt) {
    final paid = payments
        .where((item) => item.debtId == debt.id)
        .fold<double>(0, (sum, item) => sum + item.valor);
    return debtBalance(
      principal: debt.valorPrincipal,
      taxaPercent: debt.taxaJuros,
      paid: paid,
      quitado: debt.statusPago,
    );
  }

  bool get reachedFreeLimit =>
      !user.premiumAtivo && pendingDebts.length >= AppConstants.freeDebtLimit;

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      user = await _repository.getCurrentUser();
      await _expirePremium();
      debts = await _repository.getDebts();
      payments = await _repository.getPayments();
      await _persistScores();
      await _syncReminders();
    } catch (error) {
      errorMessage = 'Não foi possível carregar os dados.';
      debugPrint('$error');
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> saveUser(AppUser next) async {
    user = next;
    _notify();
    await _repository.saveUser(next);
  }

  Future<void> upsertDebt(Debt debt) async {
    final scored = _scored(debt);
    await _repository.upsertDebt(scored);
    final exists = debts.any((item) => item.id == scored.id);
    if (exists) {
      debts = [
        for (final item in debts)
          if (item.id == scored.id) scored else item,
      ];
    } else {
      debts = [...debts, scored];
    }
    await _syncReminders();
    _notify();
  }

  Future<void> deleteDebt(String id) async {
    await _repository.deleteDebt(id);
    debts = debts.where((item) => item.id != id).toList();
    payments = payments.where((item) => item.debtId != id).toList();
    await _syncReminders();
    _notify();
  }

  Future<void> addPayment(Payment payment) async {
    await _repository.addPayment(payment);
    payments = [...payments.where((item) => item.id != payment.id), payment];
    final index = debts.indexWhere((item) => item.id == payment.debtId);
    if (index >= 0) {
      var debt = debts[index];
      if (!debt.statusPago && balanceFor(debt).quitado) {
        debt = debt.copyWith(statusPago: true);
      }
      debt = _scored(debt);
      debts = [...debts]..[index] = debt;
      await _repository.upsertDebt(debt);
    }
    await _syncReminders();
    _notify();
  }

  Future<void> markPaid(Debt debt) async {
    final saldo = balanceFor(debt).saldo;
    if (saldo <= 0.009) {
      await upsertDebt(debt.copyWith(statusPago: true));
      return;
    }
    await addPayment(
      Payment(
        id: newId(),
        debtId: debt.id,
        userId: debt.userId,
        valor: saldo,
        data: DateTime.now(),
        descricao: 'Quitação',
      ),
    );
  }

  Future<String?> setDailyReminders(bool enabled) async {
    if (enabled) {
      final allowed = await _reminders.requestPermission();
      if (!allowed) return 'Permissão de notificação negada.';
    }
    await saveUser(user.copyWith(notificacoesDiarias: enabled));
    await _syncReminders();
    return null;
  }

  Future<String?> setBiometric(bool enabled) async {
    if (enabled) {
      final supported = await _biometrics.isSupported;
      if (!supported) {
        return 'Este aparelho não tem biometria disponível.';
      }
      final ok = await _biometrics.authenticate();
      if (!ok) return 'Biometria não confirmada.';
    }
    await saveUser(user.copyWith(acessoBiometrico: enabled));
    return null;
  }

  Future<String?> subscribePremium() {
    return _runBilling(_billing.buy, emptyMessage: 'A compra não foi concluída.');
  }

  Future<String?> restorePremium() {
    return _runBilling(
      _billing.restore,
      emptyMessage: 'Nenhuma compra ativa foi encontrada na carteira do telefone.',
    );
  }

  Future<void> handlePurchase(PurchaseUpdate update) async {
    if (_disposed) return;
    switch (update.outcome) {
      case PurchaseOutcome.pending:
        billingBusy = true;
        billingMessage = null;
      case PurchaseOutcome.purchased:
      case PurchaseOutcome.restored:
        billingBusy = false;
        billingMessage = null;
        await _grantPremium(update.transactionId);
      case PurchaseOutcome.canceled:
        billingBusy = false;
        billingMessage = null;
      case PurchaseOutcome.unavailable:
      case PurchaseOutcome.missing:
      case PurchaseOutcome.error:
        billingBusy = false;
        billingMessage = update.message;
    }
    _notify();
  }

  Future<void> grantConfirmedPix(String paymentId) {
    return _grantPremium('asaas_$paymentId');
  }

  Future<void> signOut() => onSignOut();

  String newId() => _uuid.v4();

  Future<void> _expirePremium() async {
    if (!user.isPremium || user.premiumAtivo) return;
    user = user.copyWith(isPremium: false);
    await _repository.saveUser(user);
  }

  Future<void> _grantPremium(String? transactionId) async {
    if (transactionId != null &&
        transactionId == user.premiumTransactionId &&
        user.premiumAtivo) {
      return;
    }
    final next = user.copyWith(
      isPremium: true,
      premiumVenceEm: DateTime.now().add(const Duration(days: 30)),
      premiumTransactionId: transactionId,
    );
    await saveUser(next);
  }

  Future<String?> _runBilling(
    Future<PurchaseUpdate> Function() start, {
    required String emptyMessage,
  }) async {
    billingBusy = true;
    billingMessage = null;
    _notify();
    final done = Completer<PurchaseUpdate>();
    _billing.onUpdate = (update) async {
      await handlePurchase(update);
      if (update.outcome != PurchaseOutcome.pending && !done.isCompleted) {
        done.complete(update);
      }
    };
    try {
      final immediate = await start();
      if (immediate.outcome != PurchaseOutcome.pending) {
        await handlePurchase(immediate);
        return immediate.message;
      }
      final result = await done.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => const PurchaseUpdate(
          outcome: PurchaseOutcome.error,
          message: 'A Play Store não respondeu. Tente de novo.',
        ),
      );
      if (result.outcome == PurchaseOutcome.purchased ||
          result.outcome == PurchaseOutcome.restored) {
        return null;
      }
      if (result.outcome == PurchaseOutcome.canceled) return null;
      return result.message ?? emptyMessage;
    } finally {
      _billing.onUpdate = handlePurchase;
      if (billingBusy) {
        billingBusy = false;
        _notify();
      }
    }
  }

  Future<void> _persistScores() async {
    final next = <Debt>[];
    for (final debt in debts) {
      final scored = _scored(debt);
      if (scored.clientScore != debt.clientScore) {
        await _repository.upsertDebt(scored);
      }
      next.add(scored);
    }
    debts = next;
  }

  Debt _scored(Debt debt) {
    final paidSum = payments
        .where((item) => item.debtId == debt.id)
        .fold<double>(0, (sum, item) => sum + item.valor);
    return debt.copyWith(
      clientScore: trustScore(
        due: debt.dataVencimento,
        paid: debt.statusPago,
        principal: debt.valorPrincipal,
        paidSum: paidSum,
        now: DateTime.now(),
      ),
    );
  }

  Future<void> _syncReminders() {
    return _reminders.sync(
      enabled: user.notificacoesDiarias,
      debts: debts,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
