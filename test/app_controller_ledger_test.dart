import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/local_repository.dart';
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
      final state = AppController(repo);
      await state.load();
      await state.markPaid(state.debts.single);
      expect(state.payments, hasLength(1));
      expect(state.pendingDebts, isEmpty);
      expect(state.saldoOf(state.debts.single), 0);
      expect(
        await state.reversePayment(state.payments.single, reason: 'Duplicado'),
        isNull,
      );
      expect(state.payments.single.estornado, isTrue);
      expect(state.pendingDebts, hasLength(1));
      expect(state.saldoOf(state.debts.single), 100);
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
