class VoiceDebtDraft {
  const VoiceDebtDraft({
    this.nome,
    this.telefone,
    this.valor,
    this.juros,
    this.vencimento,
  });

  final String? nome;
  final String? telefone;
  final double? valor;
  final double? juros;
  final DateTime? vencimento;

  bool get hasAny =>
      (nome != null && nome!.isNotEmpty) ||
      telefone != null ||
      valor != null ||
      juros != null ||
      vencimento != null;
}

VoiceDebtDraft parseVoiceDebt(String transcript, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final original = transcript.trim();
  if (original.isEmpty) return const VoiceDebtDraft();
  final normalized = _strip(original);

  return VoiceDebtDraft(
    nome: _name(original, normalized),
    telefone: _phone(original),
    valor: _amount(normalized),
    juros: _interest(normalized),
    vencimento: _due(normalized, clock),
  );
}

String? _phone(String original) {
  final groups = RegExp(r'(?:\d[\s().-]*){10,13}').allMatches(original);
  for (final match in groups) {
    var digits = match.group(0)!.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('55') && digits.length > 11) {
      digits = digits.substring(2);
    }
    if (digits.length == 10 || digits.length == 11) return digits;
  }
  return null;
}

double? _interest(String normalized) {
  final labeled = RegExp(
    r'juros(?: de)?\s+(\d+(?:[.,]\d+)?)',
  ).firstMatch(normalized);
  if (labeled != null) return _number(labeled.group(1)!);
  final percent = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(?:%|por\s*cento)',
  ).firstMatch(normalized);
  if (percent != null) return _number(percent.group(1)!);
  return null;
}

double? _amount(String normalized) {
  const pattern =
      r'(\d{1,3}(?:\.\d{3})+,\d{2}|\d+(?:[.,]\d{1,2})?)';
  final withReais = RegExp(
    '(?:valor(?: de)?\\s+)?(?:r\\\$\\s*)?$pattern\\s*reais',
  ).firstMatch(normalized);
  if (withReais != null) return _number(withReais.group(1)!);
  final labeled = RegExp(
    'valor(?: de)?\\s+(?:r\\\$\\s*)?$pattern',
  ).firstMatch(normalized);
  if (labeled != null) return _number(labeled.group(1)!);
  return null;
}

DateTime? _due(String normalized, DateTime clock) {
  if (RegExp(r'\bhoje\b').hasMatch(normalized)) {
    return DateTime(clock.year, clock.month, clock.day);
  }
  if (RegExp(r'\bamanha\b').hasMatch(normalized)) {
    final next = clock.add(const Duration(days: 1));
    return DateTime(next.year, next.month, next.day);
  }
  final inDays = RegExp(
    r'(?:em|daqui a|vence em)\s+(\d+)\s+dias?',
  ).firstMatch(normalized);
  if (inDays != null) {
    final next = clock.add(Duration(days: int.parse(inDays.group(1)!)));
    return DateTime(next.year, next.month, next.day);
  }
  final slash = RegExp(
    r'(\d{1,2})[\/\-](\d{1,2})(?:[\/\-](\d{2,4}))?',
  ).firstMatch(normalized);
  if (slash != null) {
    final day = int.parse(slash.group(1)!);
    final month = int.parse(slash.group(2)!);
    var year = slash.group(3) == null ? clock.year : int.parse(slash.group(3)!);
    if (year < 100) year += 2000;
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return DateTime(year, month, day);
    }
  }
  final named = RegExp(
    r'(\d{1,2})\s+de\s+([a-z]+)(?:\s+de\s+(\d{4}))?',
  ).firstMatch(normalized);
  if (named != null) {
    final month = _month(named.group(2)!);
    if (month != null) {
      final year = named.group(3) == null
          ? clock.year
          : int.parse(named.group(3)!);
      return DateTime(year, month, int.parse(named.group(1)!));
    }
  }
  return null;
}

String? _name(String original, String normalized) {
  final labeled = RegExp(
    r'(?:nome|cliente)\s+(.+?)(?=\s+(?:telefone|whatsapp|valor|juros|vence|vencimento)\b|$)',
  ).firstMatch(normalized);
  if (labeled != null) {
    final name = _cleanName(_slice(original, normalized, labeled.group(1)!, labeled.start));
    if (name != null) return name;
  }
  final cut = RegExp(
    r'\b(telefone|whatsapp|valor|juros|vence|vencimento|reais)\b',
  ).firstMatch(normalized);
  final head = cut == null ? original : original.substring(0, cut.start);
  return _cleanName(head);
}

String _slice(String original, String normalized, String group, int matchStart) {
  final index = normalized.indexOf(group, matchStart);
  if (index < 0 || index + group.length > original.length) return group;
  return original.substring(index, index + group.length);
}

String? _cleanName(String raw) {
  final cleaned = raw
      .replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final words = cleaned.split(' ').where((word) => word.length > 1).toList();
  if (words.isEmpty) return null;
  if (words.length == 1 && words.first.length < 3) return null;
  return words
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

double? _number(String raw) {
  final normalized = raw.contains(',')
      ? raw.replaceAll('.', '').replaceAll(',', '.')
      : raw;
  return double.tryParse(normalized);
}

int? _month(String name) {
  const months = {
    'janeiro': 1,
    'fevereiro': 2,
    'marco': 3,
    'abril': 4,
    'maio': 5,
    'junho': 6,
    'julho': 7,
    'agosto': 8,
    'setembro': 9,
    'outubro': 10,
    'novembro': 11,
    'dezembro': 12,
  };
  return months[name];
}

String _strip(String input) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString();
}
