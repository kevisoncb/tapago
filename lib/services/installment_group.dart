import '../models/models.dart';

/// Parcelas de um mesmo parcelamento (mesmo `grupoId`), da primeira à última.
class InstallmentGroup {
  InstallmentGroup(this.grupoId, List<Debt> parcelas)
    : parcelas = [...parcelas]..sort((a, b) => a.parcela.compareTo(b.parcela));

  final String grupoId;
  final List<Debt> parcelas;

  int get total => parcelas.first.totalParcelas;
  double get valorTotal =>
      parcelas.fold(0.0, (sum, debt) => sum + debt.valorAtualizado);

  double restante(double Function(Debt debt) saldoOf) => parcelas.fold(
    0.0,
    (sum, debt) => sum + (isSettled(debt, saldoOf) ? 0.0 : saldoOf(debt)),
  );

  List<Debt> abertas(double Function(Debt debt) saldoOf) =>
      parcelas.where((debt) => !isSettled(debt, saldoOf)).toList();

  int pagas(double Function(Debt debt) saldoOf) =>
      parcelas.length - abertas(saldoOf).length;

  static bool isSettled(Debt debt, double Function(Debt debt) saldoOf) =>
      debt.statusPago || saldoOf(debt) <= 0.009;
}

/// Junta parcelamentos; lançamentos avulsos continuam como estão. A ordem
/// segue a primeira aparição de cada item em [debts].
List<Object> groupInstallments(List<Debt> debts) {
  final groups = <String, List<Debt>>{};
  for (final debt in debts) {
    if (debt.grupoId.isNotEmpty && debt.parcelado) {
      groups.putIfAbsent(debt.grupoId, () => []).add(debt);
    }
  }
  final out = <Object>[];
  final emitted = <String>{};
  for (final debt in debts) {
    final id = debt.grupoId;
    if (id.isNotEmpty && debt.parcelado && groups[id]!.length > 1) {
      if (emitted.add(id)) out.add(InstallmentGroup(id, groups[id]!));
    } else {
      out.add(debt);
    }
  }
  return out;
}

class InstallmentPayment {
  const InstallmentPayment(this.debt, this.valor);
  final Debt debt;
  final double valor;
}

/// Distribui [valor] pelas parcelas em aberto, na ordem, até o saldo de cada
/// uma. Contas em centavos para não deixar resto de arredondamento.
List<InstallmentPayment> planInstallmentPayment({
  required List<Debt> abertas,
  required double Function(Debt debt) saldoOf,
  required double valor,
}) {
  var left = (valor * 100).round();
  final plan = <InstallmentPayment>[];
  for (final debt in abertas) {
    if (left <= 0) break;
    final cents = (saldoOf(debt) * 100).round();
    if (cents <= 0) continue;
    final pay = left < cents ? left : cents;
    plan.add(InstallmentPayment(debt, pay / 100));
    left -= pay;
  }
  return plan;
}
