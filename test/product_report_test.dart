import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/product_report.dart';

DebtItem _item(String nome, double qtd, double valor, DateTime em) =>
    DebtItem(nome: nome, quantidade: qtd, valorUnitario: valor, em: em);

Debt _debt(String id, List<DebtItem> itens) => Debt(
  id: id,
  userId: 'u',
  nome: 'Juca',
  telefone: '',
  valorPrincipal: itens.fold(0.0, (s, i) => s + i.total),
  taxaJuros: 0,
  dataVencimento: DateTime(2026, 11, 5),
  statusPago: false,
  clientScore: 80,
  itens: itens,
);

void main() {
  final oct3 = DateTime(2026, 10, 3, 14, 32);
  final oct10 = DateTime(2026, 10, 10, 9, 5);
  final nov2 = DateTime(2026, 11, 2, 18, 0);

  test('total do item é quantidade × valor em centavos', () {
    expect(_item('Skol', 5, 8, oct3).total, 40);
    expect(_item('Pão', 3, 0.1, oct3).total, 0.3);
  });

  test('relatório do mês soma e agrupa por produto sem diferenciar caixa', () {
    final debts = [
      _debt('a', [_item('Skol Beats 550ml', 5, 8, oct3), _item('Coxinha', 3, 7, oct3)]),
      _debt('b', [_item('skol beats 550ml', 10, 8, oct10), _item('Pão', 12, 1.5, nov2)]),
    ];
    final report = buildProductReport(debts: debts, month: DateTime(2026, 10));
    expect(report.total, 141);
    final lines = report.byProduct();
    expect(lines.first.nome, 'Skol Beats 550ml');
    expect(lines.first.quantidade, 15);
    expect(lines.first.total, 120);
    expect(lines.length, 2);
    expect(report.debts.length, 2);
  });

  test('agrupa por dia em ordem e ignora itens de outros meses', () {
    final debts = [
      _debt('a', [_item('Skol', 5, 8, oct3), _item('Coxinha', 3, 7, oct3)]),
      _debt('b', [_item('Skol', 1, 8, oct10), _item('Pão', 12, 1.5, nov2)]),
    ];
    final report = buildProductReport(debts: debts, month: DateTime(2026, 10));
    final days = report.byDay();
    expect(days.map((d) => d.day.day), [3, 10]);
    expect(days.first.total, 61);
    expect(report.itens.any((i) => i.nome == 'Pão'), isFalse);
    expect(monthsWithItems(debts), [DateTime(2026, 11), DateTime(2026, 10)]);
  });

  test('itens sobrevivem ao salvar e ler', () {
    final debt = _debt('a', [_item('Skol', 5, 8, oct3)]);
    final back = Debt.fromMap(debt.toMap(), id: 'a');
    expect(back.itens.single.nome, 'Skol');
    expect(back.itens.single.quantidade, 5);
    expect(back.itens.single.em, oct3);
  });

  test('rótulos', () {
    expect(monthLabel(DateTime(2026, 10)), 'Outubro de 2026');
    expect(quantityLabel(1.5), '1,50');
    expect(quantityLabel(5), '5');
    expect(hourLabel(oct10), '09:05');
  });
}
