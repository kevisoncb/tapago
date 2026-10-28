import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/local_repository.dart';
import 'package:pago_app/services/mmp_service.dart';
import 'package:pago_app/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DelayedRepository extends LocalRepository {
  DelayedRepository() : super(userId: 'u');
  final gate = Completer<void>();
  int writes = 0;
  @override
  Future<void> recordPayment(Payment payment) async {
    writes++;
    await gate.future;
    await super.recordPayment(payment);
  }
}

class RecordingMetrics implements ProductMetrics {
  final debts = <({bool first, bool installment, String source, int count})>[];
  final payments = <bool>[];
  var reversals = 0;

  @override
  Future<void> logDebtCreated({
    required bool firstDebt,
    required bool installment,
    required String source,
    required int recordCount,
  }) async {
    debts.add((
      first: firstDebt,
      installment: installment,
      source: source,
      count: recordCount,
    ));
  }

  @override
  Future<void> logManualWriteOffRecorded({
    required bool settledReceivable,
  }) async {
    payments.add(settledReceivable);
  }

  @override
  Future<void> logManualWriteOffCorrected() async => reversals++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final debt = Debt(
    id: 'd',
    userId: 'u',
    nome: 'Cliente',
    telefone: '',
    valorPrincipal: 100,
    taxaJuros: 0,
    dataVencimento: DateTime(2026, 11),
    statusPago: false,
    clientScore: 80,
  );

  test(
    'quitação registra pagamento e estorno reabre o saldo no controller',
    () async {
      final repo = LocalRepository(userId: 'u');
      await repo.init();
      await repo.upsertDebt(debt);
      final metrics = RecordingMetrics();
      final state = AppController(repo, metrics: metrics);
      await state.load();
      await state.markPaid(state.debts.single);
      expect(state.payments, hasLength(1));
      expect(state.pendingDebts, isEmpty);
      expect(state.saldoOf(state.debts.single), 0);
      expect(metrics.payments, [true]);
      expect(
        await state.reversePayment(state.payments.single, reason: 'Duplicado'),
        isNull,
      );
      expect(state.payments.single.estornado, isTrue);
      expect(state.pendingDebts, hasLength(1));
      expect(state.saldoOf(state.debts.single), 100);
      expect(metrics.reversals, 1);
      state.dispose();
    },
  );

  test(
    'métrica de lançamento não leva dados pessoais ou financeiros',
    () async {
      final repo = LocalRepository(userId: 'u');
      await repo.init();
      final metrics = RecordingMetrics();
      final state = AppController(repo, metrics: metrics);
      await state.load();

      await state.createDebts([debt], source: 'csv');

      expect(metrics.debts, [
        (first: true, installment: false, source: 'csv', count: 1),
      ]);
      state.dispose();
    },
  );

  test('segundo toque durante gravação não cria outro pagamento', () async {
    final repo = DelayedRepository();
    await repo.init();
    await repo.upsertDebt(debt);
    final state = AppController(repo);
    await state.load();
    final first = state.abate(debt: debt, valor: 30);
    expect(await state.abate(debt: debt, valor: 30), isNotNull);
    expect(repo.writes, 1);
    repo.gate.complete();
    expect(await first, isNull);
    expect(state.payments, hasLength(1));
    expect(state.saldoOf(state.debts.single), 70);
    state.dispose();
  });
}
