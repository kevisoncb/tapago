import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/business_report.dart';

Debt _debt(String id, double value, DateTime due, {bool paid = false}) => Debt(
  id: id,
  userId: 'u',
  nome: 'Cliente $id',
  telefone: '',
  valorPrincipal: value,
  taxaJuros: 0,
  dataVencimento: due,
  statusPago: paid,
  clientScore: 80,
);

void main() {
  test('separa recebido, previsto, vencido e boletos sem calcular lucro', () {
    final report = buildBusinessReport(
      start: DateTime(2026, 10),
      end: DateTime(2026, 10, 31),
      now: DateTime(2026, 10, 20, 18),
      debts: [
        _debt('futuro', 100, DateTime(2026, 10, 25)),
        _debt('ontem', 50, DateTime(2026, 10, 19)),
        _debt('antigo', 30, DateTime(2026, 9)),
        _debt('quitado', 500, DateTime(2026, 10, 30), paid: true),
      ],
      payments: [
        Payment(
          id: 'p1',
          debtId: 'futuro',
          userId: 'u',
          valor: 40,
          data: DateTime(2026, 10, 10),
        ),
        Payment(
          id: 'p2',
          debtId: 'ontem',
          userId: 'u',
          valor: 10,
          data: DateTime(2026, 10, 5),
          estornadoEm: DateTime(2026, 10, 6),
          estornoMotivo: 'Correção',
        ),
      ],
      bills: [
        Bill(
          id: 'pago',
          userId: 'u',
          fornecedor: 'Fornecedor A',
          valor: 25,
          dataVencimento: DateTime(2026, 10, 3),
          pago: true,
          pagoEm: DateTime(2026, 10, 3),
        ),
        Bill(
          id: 'aberto',
          userId: 'u',
          fornecedor: 'Fornecedor B',
          valor: 70,
          dataVencimento: DateTime(2026, 10, 22),
        ),
        Bill(
          id: 'atrasado',
          userId: 'u',
          fornecedor: 'Fornecedor C',
          valor: 20,
          dataVencimento: DateTime(2026, 10),
        ),
      ],
    );

    expect(report.receivedCents, 4000);
    expect(report.receivedCount, 1);
    expect(report.forecastCents, 6000);
    expect(report.forecastCount, 1);
    expect(report.overdueCents, 8000);
    expect(report.overdueCount, 2);
    expect(report.aging.map((bucket) => bucket.cents), [5000, 0, 3000]);
    expect(report.supplierPaidCents, 2500);
    expect(report.supplierDueCents, 7000);
    expect(report.supplierOverdueCents, 2000);
  });

  test('intervalo é inclusivo e rejeita datas invertidas', () {
    final payment = Payment(
      id: 'p',
      debtId: 'd',
      userId: 'u',
      valor: 12.34,
      data: DateTime(2026, 10, 31, 23, 59),
    );
    final report = buildBusinessReport(
      debts: const [],
      payments: [payment],
      bills: const [],
      start: DateTime(2026, 10, 31),
      end: DateTime(2026, 10, 31),
      now: DateTime(2026, 10, 20),
    );
    expect(report.receivedCents, 1234);
    expect(
      () => buildBusinessReport(
        debts: const [],
        payments: const [],
        bills: const [],
        start: DateTime(2026, 11),
        end: DateTime(2026, 10),
      ),
      throwsArgumentError,
    );
  });
}
