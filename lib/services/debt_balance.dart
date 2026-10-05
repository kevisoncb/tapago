/// Saldo de um débito depois dos pagamentos.
///
/// O combinado é o principal mais a taxa. Cada pagamento abate esse total.
/// O que sobra ainda carrega a mesma taxa, então o juro fica só sobre o restante.
class DebtBalance {
  const DebtBalance({
    required this.contratado,
    required this.pago,
    required this.saldo,
    required this.principalRestante,
    required this.jurosRestantes,
  });

  final double contratado;
  final double pago;
  final double saldo;
  final double principalRestante;
  final double jurosRestantes;

  bool get quitado => saldo <= 0.009;
}

DebtBalance debtBalance({
  required double principal,
  required double taxaPercent,
  required double paid,
  bool quitado = false,
}) {
  final rate = taxaPercent / 100;
  final contracted = _money(principal * (1 + rate));
  final paidSafe = paid < 0 ? 0.0 : paid;
  if (quitado) {
    return DebtBalance(
      contratado: contracted,
      pago: paidSafe,
      saldo: 0,
      principalRestante: 0,
      jurosRestantes: 0,
    );
  }

  final raw = contracted - paidSafe;
  final saldo = raw <= 0.009 ? 0.0 : _money(raw);
  final divisor = 1 + rate;
  final principalRestante = divisor == 0 ? saldo : _money(saldo / divisor);
  final juros = _money(saldo - principalRestante);
  return DebtBalance(
    contratado: contracted,
    pago: paidSafe,
    saldo: saldo,
    principalRestante: principalRestante,
    jurosRestantes: juros < 0 ? 0 : juros,
  );
}

double _money(double value) {
  return (value * 100).round() / 100;
}
