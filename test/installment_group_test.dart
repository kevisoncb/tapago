import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/installment_group.dart';

Debt _parcela(int n, double valor, {String grupo = 'g1', int total = 3}) => Debt(
  id: 'd$n$grupo',
  userId: 'u',
  nome: 'Juca',
  telefone: '',
  valorPrincipal: valor,
  taxaJuros: 0,
  dataVencimento: DateTime(2026, 10 + n, 30),
  statusPago: false,
  clientScore: 0,
  grupoId: grupo,
  parcela: n,
  totalParcelas: total,
);

void main() {
  final p1 = _parcela(1, 166.66);
  final p2 = _parcela(2, 166.66);
  final p3 = _parcela(3, 166.68);
  final paid = <String, double>{};
  double saldoOf(Debt d) => d.valorAtualizado - (paid[d.id] ?? 0);

  setUp(paid.clear);

  test('agrupa parcelas do mesmo grupo e mantém avulsos', () {
    final avulso = Debt(
      id: 'x',
      userId: 'u',
      nome: 'Juca',
      telefone: '',
      valorPrincipal: 1800,
      taxaJuros: 20,
      dataVencimento: DateTime(2026, 11, 30),
      statusPago: false,
      clientScore: 0,
    );
    final items = groupInstallments([p3, p1, avulso, p2]);
    expect(items.length, 2);
    final group = items.first as InstallmentGroup;
    expect(group.parcelas.map((d) => d.parcela), [1, 2, 3]);
    expect(group.valorTotal, closeTo(500.0, 0.001));
    expect(items.last, same(avulso));
  });

  test('parcela atual avança conforme as pagas', () {
    final group = InstallmentGroup('g1', [p1, p2, p3]);
    expect(group.pagas(saldoOf), 0);
    expect(group.abertas(saldoOf).first.parcela, 1);
    paid[p1.id] = 166.66;
    expect(group.pagas(saldoOf), 1);
    expect(group.abertas(saldoOf).first.parcela, 2);
    expect(group.restante(saldoOf), closeTo(333.34, 0.001));
  });

  test('distribui um valor pelas parcelas na ordem', () {
    final group = InstallmentGroup('g1', [p1, p2, p3]);
    final plan = planInstallmentPayment(
      abertas: group.abertas(saldoOf),
      saldoOf: saldoOf,
      valor: 250,
    );
    expect(plan.map((e) => e.debt.parcela), [1, 2]);
    expect(plan[0].valor, 166.66);
    expect(plan[1].valor, 83.34);
  });

  test('quitar tudo paga o saldo exato de cada parcela', () {
    final group = InstallmentGroup('g1', [p1, p2, p3]);
    final plan = planInstallmentPayment(
      abertas: group.abertas(saldoOf),
      saldoOf: saldoOf,
      valor: group.restante(saldoOf),
    );
    expect(plan.length, 3);
    expect(plan.last.valor, 166.68);
  });
}
