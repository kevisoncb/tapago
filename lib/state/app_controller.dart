import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/app_repository.dart';
import '../services/asaas_client.dart';
import '../services/billing_service.dart';
import '../services/biometric_service.dart';
import '../services/debt_balance.dart';
import '../services/reminder_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class AppController extends ChangeNotifier {
  AppController(
    this._repository, {
    Future<void> Function()? onSignOut,
    BillingService? billing,
    ReminderService? reminders,
    BiometricService? biometrics,
  })  : _onSignOut = onSignOut,
        _billing = billing,
        _reminders = reminders,
        _biometrics = biometrics;

  final AppRepository _repository;
  final Future<void> Function()? _onSignOut;
  final BillingService? _billing;
  final ReminderService? _reminders;
  final BiometricService? _biometrics;
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
  List<Boleto> boletos = [];
  bool loading = true;
  String? errorMessage;
  bool billingBusy = false;
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

  double paidFor(String debtId) {
    return paymentsFor(debtId).fold(0, (sum, item) => sum + item.valor);
  }

  DebtBalance balanceOf(Debt debt) {
    final ledger = payments.where((item) => item.debtId == debt.id).toList()
      ..sort((a, b) => a.data.compareTo(b.data));
    return debtBalance(
      principal: debt.valorPrincipal,
      taxaPercent: debt.taxaJuros,
      quitado: debt.statusPago,
      lancamentos: [
        for (final item in ledger)
          LedgerPay(
            valor: item.valor,
            somenteJuros: item.descricao == 'Juros',
          ),
      ],
    );
  }

  double saldoOf(Debt debt) => balanceOf(debt).saldo;

  double get saldoAberto => pendingDebts.fold(
        0,
        (sum, debt) => sum + saldoOf(debt),
      );

  double get dinheiroNaRua => saldoAberto;

  double get lucroProjetado => saldoAberto;

  double get aReceberNaSemana => pendingDebts
      .where((debt) => debt.isDueThisWeek || debt.isOverdue)
      .fold(0, (sum, debt) => sum + saldoOf(debt));

  List<Boleto> get boletosAbertos {
    return boletos.where((item) => !item.statusPago).toList()
      ..sort((a, b) => a.dataVencimento.compareTo(b.dataVencimento));
  }

  List<Boleto> get boletosPagos {
    return boletos.where((item) => item.statusPago).toList()
      ..sort((a, b) => (b.pagoEm ?? b.dataVencimento)
          .compareTo(a.pagoEm ?? a.dataVencimento));
  }

  double get boletosAPagar =>
      boletosAbertos.fold(0, (sum, item) => sum + item.valor);

  int get boletosVencidos =>
      boletosAbertos.where((item) => item.isOverdue).length;

  int get boletosVencendo =>
      boletosAbertos.where((item) => item.venceLogo).length;

  List<Payment> paymentsFor(String debtId) {
    final list = payments.where((item) => item.debtId == debtId).toList()
      ..sort((a, b) => b.data.compareTo(a.data));
    return list;
  }

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      user = await _repository.getCurrentUser();
      debts = await _repository.getDebts();
      payments = await _repository.getPayments();
      try {
        boletos = await _repository.getBoletos();
      } catch (error) {
        debugPrint('Boletos: $error');
      }
      _billing?.onUpdate = _onPurchase;
      await _billing?.start();
      await _syncReminders();
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
    await _syncReminders();
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
    await _syncReminders();
  }

  Future<void> addPayment(Payment payment) async {
    await _repository.addPayment(payment);
    payments = [...payments, payment];
    notifyListeners();
  }

  Future<String?> abate({
    required Debt debt,
    required double valor,
    bool somenteJuros = false,
  }) async {
    if (valor <= 0) return 'Digite um valor.';
    final balance = balanceOf(debt);
    if (somenteJuros) {
      if (balance.jurosRestantes <= 0.009) {
        return 'Não há juros em aberto nesta caderneta.';
      }
      if (valor > balance.jurosRestantes + 0.009) {
        return 'Juros em aberto: ${Money.full(balance.jurosRestantes)}.';
      }
    } else if (valor > balance.saldo + 0.009) {
      return 'Não dá para abater mais que o saldo (${Money.full(balance.saldo)}).';
    }

    final next = debtBalance(
      principal: debt.valorPrincipal,
      taxaPercent: debt.taxaJuros,
      lancamentos: [
        ...payments
            .where((item) => item.debtId == debt.id)
            .map(
              (item) => LedgerPay(
                valor: item.valor,
                somenteJuros: item.descricao == 'Juros',
              ),
            ),
        LedgerPay(valor: valor, somenteJuros: somenteJuros),
      ],
    );

    await addPayment(
      Payment(
        id: newId(),
        debtId: debt.id,
        userId: user.id,
        valor: valor,
        data: DateTime.now(),
        descricao: next.quitado
            ? 'Quitação'
            : somenteJuros
                ? 'Juros'
                : 'Abatimento',
      ),
    );

    if (next.quitado) {
      await markPaid(debt);
    }
    return null;
  }

  Future<void> markPaid(Debt debt) async {
    await upsertDebt(debt.copyWith(statusPago: true));
  }

  Future<void> upsertBoleto(Boleto boleto) async {
    await _repository.upsertBoleto(boleto);
    final exists = boletos.any((item) => item.id == boleto.id);
    boletos = exists
        ? [
            for (final item in boletos)
              if (item.id == boleto.id) boleto else item,
          ]
        : [...boletos, boleto];
    notifyListeners();
    await _syncReminders();
  }

  Future<void> deleteBoleto(String id) async {
    await _repository.deleteBoleto(id);
    boletos = boletos.where((item) => item.id != id).toList();
    notifyListeners();
    await _syncReminders();
  }

  Future<void> setBoletoPago(Boleto boleto, bool pago) async {
    await upsertBoleto(
      pago
          ? boleto.copyWith(statusPago: true, pagoEm: DateTime.now())
          : boleto.copyWith(statusPago: false, clearPagoEm: true),
    );
  }

  Future<void> activatePremium() async {
    if (usesFirestore) {
      await _grantFromStore();
      return;
    }
    final next = user.copyWith(
      isPremium: true,
      premiumVenceEm: DateTime.now().add(const Duration(days: 30)),
    );
    await saveUser(next);
  }

  Future<void> grantConfirmedPix(String paymentId) async {
    user = await _repository.getCurrentUser();
    notifyListeners();
    if (user.premiumAtivo) return;
    if (!usesFirestore) {
      await saveUser(
        user.copyWith(
          isPremium: true,
          premiumVenceEm: DateTime.now().add(const Duration(days: 30)),
          premiumTransactionId: paymentId,
        ),
      );
    }
  }

  Future<String?> subscribePremium() async {
    billingBusy = true;
    billingMessage = null;
    notifyListeners();
    try {
      final update = await _billing?.buy() ?? PurchaseUpdate.unavailable;
      switch (update.outcome) {
        case PurchaseOutcome.purchased:
        case PurchaseOutcome.restored:
          await _grantFromStore(transactionId: update.transactionId);
          return null;
        case PurchaseOutcome.pending:
          return 'A loja está confirmando o pagamento.';
        case PurchaseOutcome.canceled:
          return 'Compra cancelada.';
        case PurchaseOutcome.unavailable:
        case PurchaseOutcome.missing:
          if (kDebugMode && !usesFirestore) {
            await activatePremium();
            return null;
          }
          return update.message;
        case PurchaseOutcome.error:
          billingMessage = update.message;
          return update.message;
      }
    } on AsaasException catch (error) {
      billingMessage = error.message;
      return error.message;
    } finally {
      billingBusy = false;
      notifyListeners();
    }
  }

  Future<String?> restorePremium() async {
    if (user.premiumAtivo) return null;
    final update = await _billing?.restore();
    if (update?.outcome == PurchaseOutcome.restored ||
        update?.outcome == PurchaseOutcome.purchased) {
      await _grantFromStore(transactionId: update?.transactionId);
      return null;
    }
    return update?.message ?? 'Nada para restaurar neste aparelho.';
  }

  Future<void> signOut() async {
    await _onSignOut?.call();
  }

  String newId() => _uuid.v4();

  Future<void> _onPurchase(PurchaseUpdate update) async {
    if (update.outcome == PurchaseOutcome.purchased ||
        update.outcome == PurchaseOutcome.restored) {
      try {
        await _grantFromStore(transactionId: update.transactionId);
        billingMessage = null;
      } on AsaasException catch (error) {
        billingMessage = error.message;
      }
      notifyListeners();
      return;
    }
    if (update.outcome == PurchaseOutcome.error) {
      billingMessage = update.message;
      notifyListeners();
    }
  }

  Future<void> _grantFromStore({String? transactionId}) async {
    if (usesFirestore) {
      await AsaasClient().confirmPlayPurchase(transactionId: transactionId);
      user = await _repository.getCurrentUser();
      notifyListeners();
      return;
    }
    final next = user.copyWith(
      isPremium: true,
      premiumVenceEm: DateTime.now().add(const Duration(days: 30)),
      premiumTransactionId: transactionId,
    );
    await saveUser(next);
  }

  Future<void> _syncReminders() async {
    try {
      await _reminders?.sync(
        enabled: user.notificacoesDiarias,
        debts: pendingDebts,
        saldos: {
          for (final debt in pendingDebts) debt.id: saldoOf(debt),
        },
        chavePix: user.chavePix,
        customTemplate: user.mensagemCobranca,
        isPremium: user.isPremium,
        boletos: boletosAbertos,
      );
    } catch (error) {
      debugPrint('Lembretes: $error');
    }
  }

  @override
  void dispose() {
    _billing?.onUpdate = null;
    super.dispose();
  }
}
