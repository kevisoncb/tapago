import '../models/models.dart';

class TopDebtor {
  const TopDebtor({
    required this.nome,
    required this.valor,
    required this.diasAtraso,
  });

  final String nome;
  final double valor;
  final int diasAtraso;
}

class CashSummary {
  const CashSummary({
    required this.receber7,
    required this.pagar7,
    required this.receber30,
    required this.pagar30,
    required this.vencidoReceber,
    required this.devedores,
  });

  final double receber7;
  final double pagar7;
  final double receber30;
  final double pagar30;
  final double vencidoReceber;
  final List<TopDebtor> devedores;

  double get saldo7 => receber7 - pagar7;
  double get saldo30 => receber30 - pagar30;
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

/// A receber × a pagar nos próximos 7 e 30 dias (vencido entra em ambos) e
/// quem mais deve em atraso. Débito quitado e boleto pago ficam de fora.
CashSummary buildCashSummary({
  required List<Debt> debts,
  required double Function(Debt debt) saldoOf,
  required List<Bill> bills,
  required DateTime now,
  int topCount = 3,
}) {
  final today = _day(now);
  final end7 = today.add(const Duration(days: 7));
  final end30 = today.add(const Duration(days: 30));

  var receber7 = 0.0, receber30 = 0.0, vencido = 0.0;
  final atraso = <String, TopDebtor>{};
  for (final debt in debts) {
    if (debt.statusPago) continue;
    final saldo = saldoOf(debt);
    if (saldo <= 0) continue;
    final due = _day(debt.dataVencimento);
    if (due.isBefore(end7)) receber7 += saldo;
    if (due.isBefore(end30)) receber30 += saldo;
    if (due.isBefore(today)) {
      vencido += saldo;
      final key = debt.nome.trim().toLowerCase();
      final dias = today.difference(due).inDays;
      final prev = atraso[key];
      atraso[key] = TopDebtor(
        nome: prev?.nome ?? debt.nome,
        valor: (prev?.valor ?? 0) + saldo,
        diasAtraso: dias > (prev?.diasAtraso ?? 0) ? dias : prev!.diasAtraso,
      );
    }
  }

  var pagar7 = 0.0, pagar30 = 0.0;
  for (final bill in bills) {
    if (bill.pago) continue;
    final due = _day(bill.dataVencimento);
    if (due.isBefore(end7)) pagar7 += bill.valor;
    if (due.isBefore(end30)) pagar30 += bill.valor;
  }

  final top = atraso.values.toList()
    ..sort((a, b) => b.valor.compareTo(a.valor));
  return CashSummary(
    receber7: receber7,
    pagar7: pagar7,
    receber30: receber30,
    pagar30: pagar30,
    vencidoReceber: vencido,
    devedores: top.take(topCount).toList(),
  );
}
