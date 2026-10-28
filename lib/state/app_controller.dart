import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/app_repository.dart';
import '../services/analytics_service.dart';
import '../services/asaas_client.dart';
import '../services/billing_service.dart';
import '../services/biometric_service.dart';
import '../services/collection_follow_up.dart';
import '../services/debt_balance.dart';
import '../services/mmp_service.dart';
import '../services/push_service.dart';
import '../services/reminder_service.dart';
import '../services/store_ids.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class AppController extends ChangeNotifier {
  AppController(
    this._repository, {
    this._onSignOut,
    this._billing,
    this._reminders,
    this._push,
    ProductMetrics? metrics,
    BiometricService? biometrics,
  }) : _metrics =
           metrics ??
           MetricsFanOut([MmpService.instance, AnalyticsService.instance]);

  final AppRepository _repository;
  final Future<void> Function()? _onSignOut;
  final BillingService? _billing;
  final ReminderService? _reminders;
  final PushRegistrar? _push;
  bool _pushActive = false;
  final ProductMetrics _metrics;
  final _uuid = const Uuid();
  StreamSubscription<AppUser>? _userSubscription;

  AppUser user = AppUser(
    id: AppConstants.demoUserId,
    nome: '',
    email: '',
    isPremium: false,
    chavePix: '',
  );
  List<Debt> debts = [];
  List<Payment> payments = [];
  List<Bill> bills = [];
  bool loading = true;
  DateTime? lastSyncedAt;
  String? syncWarning;
  final Set<String> _pendingPayments = {};
  bool _disposed = false;
  int _dataRevision = 0;
  Future<void>? _loading;
  String? errorMessage;
  bool billingBusy = false;
  bool restoringPurchases = false;
  String? billingMessage;
  String? storePriceLabel;

  StoreKind get store => _billing?.store ?? StoreKind.googlePlay;

  bool get usesFirestore => _repository.usesFirestore;

  List<Debt> get pendingDebts {
    final pending =
        debts
            .where((debt) => !debt.statusPago && balanceOf(debt).saldo > 0.009)
            .toList()
          ..sort((a, b) {
            if (a.isOverdue && !b.isOverdue) return -1;
            if (!a.isOverdue && b.isOverdue) return 1;
            return a.dataVencimento.compareTo(b.dataVencimento);
          });
    return pending;
  }

  double paidFor(String debtId) {
    return paymentsFor(debtId)
        .where((item) => !item.estornado)
        .fold(0, (sum, item) => sum + item.valor);
  }

  DebtBalance balanceOf(Debt debt) {
    final ledger =
        payments
            .where((item) => item.debtId == debt.id && !item.estornado)
            .toList()
          ..sort((a, b) => a.data.compareTo(b.data));
    return debtBalance(
      principal: debt.valorPrincipal,
      taxaPercent: debt.taxaJuros,
      quitado: debt.statusPago,
      lancamentos: [
        for (final item in ledger)
          LedgerPay(valor: item.valor, somenteJuros: item.descricao == 'Juros'),
      ],
    );
  }

  double saldoOf(Debt debt) => balanceOf(debt).saldo;

  double get saldoAberto =>
      pendingDebts.fold(0, (sum, debt) => sum + saldoOf(debt));

  double get aReceberNaSemana => pendingDebts
      .where((debt) => debt.isDueThisWeek)
      .fold(0, (sum, debt) => sum + saldoOf(debt));

  double get aReceberVencido => pendingDebts
      .where((debt) => debt.isOverdue)
      .fold(0, (sum, debt) => sum + saldoOf(debt));

  List<Bill> get pendingBills =>
      bills.where((bill) => !bill.pago).toList()
        ..sort((a, b) => a.dataVencimento.compareTo(b.dataVencimento));

  List<Bill> get paidBills => bills.where((bill) => bill.pago).toList()
    ..sort(
      (a, b) => (b.pagoEm ?? b.dataVencimento).compareTo(
        a.pagoEm ?? a.dataVencimento,
      ),
    );

  double get aPagarAberto =>
      pendingBills.fold(0, (sum, bill) => sum + bill.valor);

  double get aPagarNaSemana => pendingBills
      .where((bill) => bill.isDueThisWeek)
      .fold(0, (sum, bill) => sum + bill.valor);

  List<Bill> get overdueBills =>
      pendingBills.where((bill) => bill.isOverdue).toList();

  double get aPagarAtrasado =>
      overdueBills.fold(0, (sum, bill) => sum + bill.valor);

  /// Boleto novo (uma ou várias parcelas): salva e conta um único evento de
  /// funil. `addBills` também serve para marcar pago e colar código, que não
  /// são criação.
  Future<void> createBills(List<Bill> next) async {
    await addBills(next);
    unawaited(MmpService.instance.logBillCreated());
  }

  Future<void> addBills(List<Bill> next) async {
    await _repository.upsertBills(next);
    _dataRevision++;
    final ids = next.map((bill) => bill.id).toSet();
    bills = [...bills.where((bill) => !ids.contains(bill.id)), ...next];
    notifyListeners();
    await _syncReminders();
  }

  Future<void> setBillPaid(Bill bill, bool pago) async {
    await addBills([
      bill.copyWith(
        pago: pago,
        pagoEm: pago ? DateTime.now() : null,
        clearPagoEm: !pago,
      ),
    ]);
  }

  Future<void> deleteBill(Bill bill) async {
    await _repository.deleteBill(bill.id);
    _dataRevision++;
    bills = bills.where((item) => item.id != bill.id).toList();
    notifyListeners();
    await _syncReminders();
  }

  List<Payment> paymentsFor(String debtId) {
    final list = payments.where((item) => item.debtId == debtId).toList()
      ..sort((a, b) => b.data.compareTo(a.data));
    return list;
  }

  Future<void> load() {
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    final revision = _dataRevision;
    try {
      final nextUser = await _repository.getCurrentUser();
      final nextDebts = await _repository.getDebts();
      final nextPayments = await _repository.getPayments();
      final nextBills = await _repository.getBills();
      if (_disposed || revision != _dataRevision) return;
      user = nextUser;
      debts = nextDebts;
      payments = nextPayments;
      bills = nextBills;
      _updateSyncStatus();
      _billing?.onUpdate = _onPurchase;
      await _billing?.start();
      await _syncReminders();
      _watchUser();
    } catch (error) {
      if (_disposed) return;
      errorMessage = 'Não foi possível atualizar seus dados. Confira a conexão e tente novamente.';
      debugPrint('Carregamento: $error');
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void _updateSyncStatus() {
    final repository = _repository;
    if (repository is RepositorySyncStatus) {
      final status = repository as RepositorySyncStatus;
      lastSyncedAt = status.lastSyncedAt;
      syncWarning = status.usingCachedData
          ? 'Mostrando dados salvos neste aparelho. Conecte-se e atualize antes de registrar pagamentos.'
          : null;
    } else {
      lastSyncedAt = DateTime.now();
      syncWarning = null;
    }
  }

  Future<void> saveUser(AppUser next) async {
    await _repository.saveUser(next);
    if (_disposed) return;
    _dataRevision++;
    user = next;
    notifyListeners();
    await _syncReminders();
  }

  Future<bool> setFollowUpReminders(bool enabled) async {
    if (enabled &&
        !await (_reminders?.requestPermission() ?? Future.value(false))) {
      return false;
    }
    await saveUser(user.copyWith(lembretesAcompanhamento: enabled));
    return true;
  }

  Future<void> refreshReminders() => _syncReminders();

  Future<void> createDebts(List<Debt> next, {String source = 'manual'}) async {
    if (next.isEmpty) return;
    final firstDebt = debts.isEmpty;
    await _repository.upsertDebts(next);
    if (_disposed) return;
    _dataRevision++;
    final ids = next.map((debt) => debt.id).toSet();
    debts = [...debts.where((debt) => !ids.contains(debt.id)), ...next];
    _updateSyncStatus();
    notifyListeners();
    await _syncReminders();
    unawaited(
      _metrics.logDebtCreated(
        firstDebt: firstDebt,
        installment:
            next.length > 1 || next.any((debt) => debt.totalParcelas > 1),
        source: source,
        recordCount: next.length,
      ),
    );
  }

  /// "Manter" na limpeza automática: vale para todos os lançamentos do cliente.
  Future<void> setKeepNotebook(List<Debt> items, bool keep) async {
    for (final debt in items) {
      await upsertDebt(debt.copyWith(manter: keep));
    }
  }

  Future<void> upsertDebt(Debt debt) async {
    final existed = debts.any((item) => item.id == debt.id);
    final firstDebt = debts.isEmpty;
    await _repository.upsertDebt(debt);
    if (_disposed) return;
    _dataRevision++;
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
    if (!existed) {
      unawaited(
        _metrics.logDebtCreated(
          firstDebt: firstDebt,
          installment: debt.totalParcelas > 1,
          source: 'manual',
          recordCount: 1,
        ),
      );
    }
  }

  Future<void> addPayment(Payment payment) async {
    await _repository.recordPayment(payment);
    await _refreshLedger();
    final debt = debts.where((item) => item.id == payment.debtId).firstOrNull;
    unawaited(
      _metrics.logManualWriteOffRecorded(
        settledReceivable: debt != null && saldoOf(debt) <= 0.009,
      ),
    );
  }

  Future<void> _refreshLedger() async {
    // Retain the previous coherent snapshot until both queries succeed.
    final nextDebts = await _repository.getDebts();
    final nextPayments = await _repository.getPayments();
    if (_disposed) return;
    _dataRevision++;
    debts = nextDebts;
    payments = nextPayments;
    _updateSyncStatus();
    notifyListeners();
    await _syncReminders();
  }

  Future<String?> abate({
    required Debt debt,
    required double valor,
    bool somenteJuros = false,
  }) async {
    if (_pendingPayments.isNotEmpty) {
      return 'Um pagamento desta caderneta já está sendo registrado. Aguarde.';
    }
    if (!valor.isFinite || valor <= 0 || valor > 100000000) {
      return 'Digite um valor válido.';
    }
    final balance = balanceOf(debt);
    final cents = (valor * 100).round();
    if (cents <= 0) return 'O valor mínimo é R\$ 0,01.';
    final normalized = cents / 100;
    if (somenteJuros) {
      if (balance.jurosRestantes <= 0.009) {
        return 'Não há juros em aberto nesta caderneta.';
      }
      if (normalized > balance.jurosRestantes + 0.009) {
        return 'Juros em aberto: ${Money.full(balance.jurosRestantes)}.';
      }
    } else if (normalized > balance.saldo + 0.009) {
      return 'Não dá para abater mais que o saldo (${Money.full(balance.saldo)}).';
    }
    _pendingPayments.add(debt.id);
    notifyListeners();
    try {
      await _repository.recordPayment(
        Payment(
          id: newId(),
          debtId: debt.id,
          userId: user.id,
          valor: normalized,
          data: DateTime.now(),
          descricao: somenteJuros
              ? 'Juros'
              : normalized >= balance.saldo - 0.009
              ? 'Quitação'
              : 'Abatimento',
        ),
      );
      try {
        await _refreshLedger();
      } catch (_) {
        await load();
        if (errorMessage != null || syncWarning != null) {
          errorMessage = 'O pagamento foi salvo. Atualize a caderneta para conferir o saldo; não registre novamente.';
        }
      }
      final refreshed = debts.where((item) => item.id == debt.id).firstOrNull;
      unawaited(
        _metrics.logManualWriteOffRecorded(
          settledReceivable: refreshed != null && saldoOf(refreshed) <= 0.009,
        ),
      );
      return null;
    } catch (error) {
      debugPrint('Pagamento: $error');
      return 'Não foi possível confirmar o pagamento. Atualize a caderneta e confira o histórico antes de tentar novamente.';
    } finally {
      _pendingPayments.remove(debt.id);
      if (!_disposed) notifyListeners();
    }
  }

  Future<String?> reversePayment(
    Payment payment, {
    required String reason,
  }) async {
    if (payment.estornado) return 'Este pagamento já foi estornado.';
    if (reason.trim().isEmpty) return 'Informe o motivo do estorno.';
    if (_pendingPayments.contains(payment.debtId)) {
      return 'Aguarde a operação em andamento.';
    }
    _pendingPayments.add(payment.debtId);
    notifyListeners();
    try {
      await _repository.reversePayment(payment.id, reason: reason.trim());
      try {
        await _refreshLedger();
      } catch (_) {
        errorMessage = 'Estorno salvo. Atualize para conferir o saldo antes de repetir a operação.';
      }
      unawaited(_metrics.logManualWriteOffCorrected());
      return null;
    } catch (error) {
      debugPrint('Estorno: $error');
      return 'Não foi possível confirmar o estorno. Atualize o histórico antes de tentar novamente.';
    } finally {
      _pendingPayments.remove(payment.debtId);
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> markPaid(Debt debt) async {
    final result = await abate(debt: debt, valor: saldoOf(debt));
    if (result != null) throw StateError(result);
  }

  Future<void> activatePremium() async {
    final next = user.copyWith(
      isPremium: true,
      premiumVenceEm: DateTime.now().add(const Duration(days: 30)),
    );
    await saveUser(next);
  }

  Future<String?> subscribePremium() async {
    if (billingBusy || restoringPurchases) {
      return 'Aguarde a confirmação da loja.';
    }
    billingBusy = true;
    billingMessage = null;
    notifyListeners();
    try {
      final update =
          await _billing?.buy(userId: user.id) ??
          PurchaseUpdate.unavailable(store);
      switch (update.outcome) {
        case PurchaseOutcome.purchased:
        case PurchaseOutcome.restored:
          await _grantFromStore(update);
          return null;
        case PurchaseOutcome.pending:
          return 'A loja está confirmando o pagamento.';
        case PurchaseOutcome.canceled:
          return 'Compra cancelada.';
        case PurchaseOutcome.nothingToRestore:
          return update.message;
        case PurchaseOutcome.unavailable:
        case PurchaseOutcome.missing:
          if ((kDebugMode || AppConstants.demoBuild) && !usesFirestore) {
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

  /// Botão "Restaurar Compras": recupera a assinatura da conta da loja sem
  /// comprar de novo (troca de aparelho, reinstalação).
  Future<String?> restorePremium() async {
    if (restoringPurchases || billingBusy) return 'Aguarde a operação da loja.';
    restoringPurchases = true;
    billingMessage = null;
    notifyListeners();
    try {
      final update =
          await _billing?.restorePurchases() ??
          PurchaseUpdate.unavailable(store);
      if (update.outcome == PurchaseOutcome.restored ||
          update.outcome == PurchaseOutcome.purchased) {
        // BillingService has already awaited validation before acknowledging.
        return null;
      }
      if (user.premiumAtivo) return null;
      return update.message ?? 'Nada para restaurar nesta conta.';
    } on AsaasException catch (error) {
      return error.message;
    } finally {
      restoringPurchases = false;
      notifyListeners();
    }
  }

  Future<void> loadStorePrice() async {
    final label = await _billing?.priceLabel();
    if (label == null || label == storePriceLabel) return;
    storePriceLabel = label;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _push?.unregister();
    } catch (error) {
      debugPrint('Push: $error');
    }
    _pushActive = false;
    await _reminders?.sync(enabled: false, debts: const []);
    await _onSignOut?.call();
  }

  String newId() => _uuid.v4();

  Future<void> _onPurchase(PurchaseUpdate update) async {
    if (_disposed) {
      throw StateError(
        'Sessão encerrada; restaure a compra ao entrar novamente.',
      );
    }
    if (update.outcome == PurchaseOutcome.purchased ||
        update.outcome == PurchaseOutcome.restored) {
      try {
        await _grantFromStore(update);
        billingMessage = null;
      } catch (error) {
        billingMessage = error is AsaasException ? error.message : 'Não foi possível confirmar a assinatura. Tente restaurar quando a conexão voltar.';
        if (!_disposed) notifyListeners();
        rethrow;
      }
      if (!_disposed) notifyListeners();
      return;
    }
    if (update.outcome == PurchaseOutcome.error) {
      billingMessage = update.message;
      notifyListeners();
    }
  }

  Future<void> _grantFromStore(PurchaseUpdate update) async {
    if (_disposed) throw StateError('Sessão encerrada.');
    final expectedUserId = user.id;
    if (usesFirestore) {
      final api = AsaasClient();
      final mmpId = MmpService.instance.appsFlyerId;
      if (update.store == StoreKind.appStore) {
        await api.confirmApplePurchase(
          transactionId: update.transactionId,
          signedTransaction: update.purchaseToken,
          mmpId: mmpId,
        );
      } else {
        await api.confirmPlayPurchase(
          transactionId: update.transactionId,
          purchaseToken: update.purchaseToken,
          mmpId: mmpId,
        );
      }
      if (update.outcome == PurchaseOutcome.purchased) {
        final price = _billing?.price ?? AppConstants.premiumPrice;
        final currency = _billing?.currency ?? 'BRL';
        unawaited(MmpService.instance.logFrontendPurchase(price, currency));
        unawaited(AnalyticsService.instance.logPurchase(price, currency));
      }
      final verifiedUser = await _repository.getCurrentUser();
      if (_disposed || user.id != expectedUserId) {
        throw StateError('Sessão encerrada.');
      }
      user = verifiedUser;
      notifyListeners();
      await _syncReminders();
      return;
    }
    final next = user.copyWith(
      isPremium: true,
      premiumVenceEm: DateTime.now().add(const Duration(days: 30)),
      premiumTransactionId: update.transactionId,
    );
    await saveUser(next);
  }

  /// Registra o aparelho no push do servidor quando há avisos ligados e a
  /// permissão já foi dada. Sem confirmação do servidor, os avisos locais
  /// continuam valendo.
  Future<void> _syncPush({bool askPermission = false}) async {
    final push = _push;
    if (push == null) return;
    final wanted = user.notificacoesDiarias || user.lembretesAcompanhamento;
    if (!wanted) {
      _pushActive = false;
      await push.unregister();
      return;
    }
    _pushActive = await push.register(askPermission: askPermission);
  }

  /// Liga os lembretes diários: pede a permissão do sistema e registra o
  /// aparelho para o aviso das 9h. Retorna `false` se a permissão for negada.
  Future<bool> enableDailyReminders() async {
    final allowed = await (_reminders?.requestPermission() ??
        Future.value(true));
    if (!allowed) return false;
    await saveUser(user.copyWith(notificacoesDiarias: true));
    await _syncPush(askPermission: true);
    await _syncReminders();
    unawaited(AnalyticsService.instance.logRemindersEnabled());
    return true;
  }

  /// Pode oferecer o aviso das 9h: há serviço de avisos e ainda não está ativo.
  bool get canOfferDailyReminders => _reminders != null && !_pushActive;

  Future<void> _syncReminders() async {
    try {
      await _syncPush();
      final followUps = user.lembretesAcompanhamento
          ? await CollectionFollowUpStore(
              usesFirestore: usesFirestore,
              userId: user.id,
            ).list()
          : const <CollectionFollowUp>[];
      await _reminders?.sync(
        enabled: user.notificacoesDiarias,
        followUpsEnabled: user.lembretesAcompanhamento,
        debts: pendingDebts,
        followUps: followUps,
        saldos: {for (final debt in pendingDebts) debt.id: saldoOf(debt)},
        chavePix: user.chavePix,
        customTemplate: user.mensagemCobranca,
        isPremium: user.premiumAtivo,
        bills: user.premiumAtivo ? pendingBills : const [],
        serverPush: _pushActive,
      );
    } catch (error) {
      debugPrint('Lembretes: $error');
    }
  }

  void _watchUser() {
    _userSubscription?.cancel();
    _userSubscription = _repository.watchCurrentUser()?.listen((next) {
      final premiumChanged = next.premiumAtivo != user.premiumAtivo;
      user = next;
      notifyListeners();
      if (premiumChanged) _syncReminders();
    }, onError: (Object error) => debugPrint('Conta ao vivo: $error'));
  }

  @override
  void dispose() {
    _disposed = true;
    _userSubscription?.cancel();
    _billing?.onUpdate = null;
    super.dispose();
  }
}
