import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/local_repository.dart';
import 'package:pago_app/services/payment_ledger.dart';
import 'package:shared_preferences/shared_preferences.dart';

Debt debt({String id = 'd', double principal = 100, double rate = 10}) => Debt(
  id: id,
  userId: 'u',
  nome: 'Cliente de teste',
  telefone: '',
  valorPrincipal: principal,
  taxaJuros: rate,
  dataVencimento: DateTime(2026, 11, 1),
  statusPago: false,
  clientScore: 80,
);

Payment payment(String id, double value, {String description = 'Abatimento'}) =>
    Payment(
      id: id,
      debtId: 'd',
      userId: 'u',
      valor: value,
      data: DateTime(2026, 10, 23),
      descricao: description,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy fields and installment/reversal metadata round trip', () {
    final legacy = Debt.fromMap(debt().toMap());
    expect(legacy.grupoId, '');
    expect(legacy.totalParcelas, 1);
    final installment = legacy.copyWith(
      grupoId: 'g',
      parcela: 2,
      totalParcelas: 3,
    );
    final restored = Debt.fromMap(installment.toMap());
    expect(restored.grupoId, 'g');
    expect(restored.parcelaLabel, 'Parcela 2 de 3');
    final reversed = payment('p', 10).copyWith(
      estornadoEm: DateTime(2026, 10, 24),
      estornoMotivo: 'Valor digitado incorretamente',
    );
    expect(Payment.fromMap(reversed.toMap()).estornado, isTrue);
    expect(
      Payment.fromMap(reversed.toMap()).estornoMotivo,
      'Valor digitado incorretamente',
    );
  });

  test('reversed payments remain in history but not in the balance', () {
    final entries = [
      payment('p1', 10, description: 'Juros'),
      payment('p2', 40).copyWith(
        estornadoEm: DateTime(2026, 10, 24),
        estornoMotivo: 'Correção',
      ),
    ];
    final balance = ledgerBalance(debt(), entries);
    expect(balance.saldo, 100);
    expect(balance.pago, 10);
  });

  test('payment guards reject invalid and overpaid amounts', () {
    expect(
      () => validatePayment(debt(), [], payment('p', double.nan)),
      throwsStateError,
    );
    expect(
      () => validatePayment(debt(), [], payment('p', 111)),
      throwsStateError,
    );
    expect(
      () => validatePayment(debt(), [], payment('p', 11, description: 'Juros')),
      throwsStateError,
    );
    expect(
      () => validatePayment(debt(), [], payment('p', 110)),
      returnsNormally,
    );
  });

  group('atomic local repository', () {
    late LocalRepository repo;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = LocalRepository(userId: 'u');
      await repo.init();
      await repo.upsertDebt(debt());
    });

    test('payment retry is idempotent and settles the same debt', () async {
      final full = payment('p', 110);
      await repo.recordPayment(full);
      await repo.recordPayment(full);
      expect(await repo.getPayments(), hasLength(1));
      expect((await repo.getDebts()).single.statusPago, isTrue);
      expect(() => repo.recordPayment(payment('p', 109)), throwsStateError);
    });

    test(
      'concurrent payments cannot spend the same remaining balance',
      () async {
        final outcomes = await Future.wait([
          repo
              .recordPayment(payment('a', 80))
              .then((_) => true)
              .catchError((_) => false),
          repo
              .recordPayment(payment('b', 80))
              .then((_) => true)
              .catchError((_) => false),
        ]);
        expect(outcomes.where((ok) => ok), hasLength(1));
        final entries = await repo.getPayments();
        expect(entries, hasLength(1));
        expect(
          ledgerBalance((await repo.getDebts()).single, entries).saldo,
          30,
        );
      },
    );

    test('reversal reopens settled debt and is itself idempotent', () async {
      await repo.recordPayment(payment('p', 110));
      await repo.reversePayment('p', reason: 'Correção de digitação');
      await repo.reversePayment('p', reason: 'Correção de digitação');
      final entries = await repo.getPayments();
      expect(entries, hasLength(1));
      expect(entries.single.estornado, isTrue);
      expect((await repo.getDebts()).single.statusPago, isFalse);
      expect(ledgerBalance((await repo.getDebts()).single, entries).saldo, 110);
    });

    test('cannot delete a debt with retained payment history', () async {
      await repo.recordPayment(payment('p', 10));
      await expectLater(repo.deleteDebt('d'), throwsStateError);
      expect(await repo.getPayments(), hasLength(1));
    });

    test(
      'batch debt and bill writes preserve the complete installment group',
      () async {
        final entries = [
          debt(id: 'd1', principal: 33.33),
          debt(id: 'd2', principal: 33.33),
          debt(id: 'd3', principal: 33.34),
        ];
        await repo.upsertDebts(entries);
        expect(
          (await repo.getDebts()).where((item) => item.id != 'd'),
          hasLength(3),
        );
        await repo.upsertDebts(entries);
        expect(
          (await repo.getDebts()).where((item) => item.id != 'd'),
          hasLength(3),
        );
      },
    );
  });
}
