double? extractReceiptAmount(String text) {
  final amount = RegExp(
    r'(?:r\$\s*)?(\d{1,3}(?:\.\d{3})+,\d{2}|\d{1,3}(?:\.\d{3})+|\d+,\d{2}|\d+[.,]\d{2})',
    caseSensitive: false,
  );
  double? best;
  var bestScore = -1;

  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    final line = rawLine.toLowerCase();
    for (final match in amount.allMatches(line)) {
      final value = _parseBr(match.group(1)!);
      if (value == null || value <= 0 || value > 10000000) continue;
      var score = 1;
      if (line.contains('valor')) score += 5;
      if (line.contains('total')) score += 4;
      if (line.contains('pago') ||
          line.contains('receb') ||
          line.contains('enviad')) {
        score += 4;
      }
      if (line.contains('pix')) score += 2;
      if (line.contains('líquido') || line.contains('liquido')) score += 3;
      if (line.contains('desconto') ||
          line.contains('troco') ||
          line.contains('tarifa')) {
        score -= 3;
      }
      if (score > bestScore || (score == bestScore && value > (best ?? 0))) {
        best = value;
        bestScore = score;
      }
    }
  }
  return best;
}

double? _parseBr(String raw) {
  if (raw.contains(',') && raw.contains('.')) {
    return double.tryParse(raw.replaceAll('.', '').replaceAll(',', '.'));
  }
  if (raw.contains(',')) {
    return double.tryParse(raw.replaceAll(',', '.'));
  }
  if (RegExp(r'^\d{1,3}(?:\.\d{3})+$').hasMatch(raw)) {
    return double.tryParse(raw.replaceAll('.', ''));
  }
  return double.tryParse(raw);
}
