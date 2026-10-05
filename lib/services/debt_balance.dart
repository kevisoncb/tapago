/// Saldo de um débito depois dos pagamentos.
///
/// Juros do ciclo = principal × taxa. Pagamento marcado como juros só baixa
/// essa fatia. Pagamento do total baixa juros em aberto e depois o principal.
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

enum AbateKind { juros, parcial, total }

class LedgerPay {
  const LedgerPay({required this.valor, this.somenteJuros = false});

  final double valor;
  final bool somenteJuros;
}

DebtBalance debtBalance({
  required double principal,
  required double taxaPercent,
  double paid = 0,
  List<LedgerPay> lancamentos = const [],
  bool quitado = false,
}) {
  final rate = taxaPercent / 100;
  final jurosCiclo = _money(principal * rate);
  final contracted = _money(principal + jurosCiclo);
  final entries = [
    ...lancamentos,
    if (paid > 0 && lancamentos.isEmpty) LedgerPay(valor: paid),
  ];

  if (quitado) {
    final pago = entries.fold<double>(0, (sum, item) => sum + item.valor);
    return DebtBalance(
      contratado: contracted,
      pago: pago,
      saldo: 0,
      principalRestante: 0,
      jurosRestantes: 0,
    );
  }

  var restoPrincipal = principal;
  var restoJuros = jurosCiclo;
  var pago = 0.0;

  for (final item in entries) {
    var left = item.valor < 0 ? 0.0 : item.valor;
    if (left <= 0) continue;
    pago += left;

    if (item.somenteJuros) {
      final take = left < restoJuros ? left : restoJuros;
      restoJuros = _money(restoJuros - take);
      continue;
    }

    final takeJuros = left < restoJuros ? left : restoJuros;
    restoJuros = _money(restoJuros - takeJuros);
    left = _money(left - takeJuros);
    if (left <= 0.009) continue;
    final takePrincipal = left < restoPrincipal ? left : restoPrincipal;
    restoPrincipal = _money(restoPrincipal - takePrincipal);
  }

  final saldo = _money(restoPrincipal + restoJuros);
  return DebtBalance(
    contratado: contracted,
    pago: pago,
    saldo: saldo <= 0.009 ? 0 : saldo,
    principalRestante: restoPrincipal < 0 ? 0 : restoPrincipal,
    jurosRestantes: restoJuros < 0 ? 0 : restoJuros,
  );
}

double _money(double value) {
  return (value * 100).round() / 100;
}
