/// Prazo de pagamento em dias a partir da data da compra (ex: 30/45/60).
List<int>? parsePrazoDias(String text) {
  final dias = text
      .split(RegExp(r'[^0-9]+'))
      .where((part) => part.isNotEmpty)
      .map(int.parse)
      .toList();
  if (dias.isEmpty || dias.length > 24) return null;
  for (var i = 0; i < dias.length; i++) {
    if (dias[i] <= 0 || dias[i] > 730) return null;
    if (i > 0 && dias[i] <= dias[i - 1]) return null;
  }
  return dias;
}

/// Divide em centavos; a primeira parcela leva a sobra.
List<double> dividirParcelas(double total, int parcelas) {
  final cents = (total * 100).round();
  final base = cents ~/ parcelas;
  final sobra = cents - base * parcelas;
  return [
    for (var i = 0; i < parcelas; i++) (base + (i == 0 ? sobra : 0)) / 100,
  ];
}

List<DateTime> vencimentosParcelas(DateTime compra, List<int> dias) {
  return [
    for (final d in dias) DateTime(compra.year, compra.month, compra.day + d),
  ];
}
