import '../models/models.dart';
import '../utils/formatters.dart';
import '../utils/masks.dart';
import 'payment_ledger.dart';

const debtCsvTemplate = '''nome;telefone;valor;vencimento;juros
Maria Silva;11999998888;250,00;30/11/2026;0
João Souza;;1200,50;15/12/2026;2,5
''';

class DebtCsvRow {
  const DebtCsvRow({
    required this.line,
    required this.nome,
    required this.telefone,
    required this.valorCents,
    required this.vencimento,
    required this.juros,
    required this.errors,
    required this.duplicate,
  });

  final int line;
  final String nome;
  final String telefone;
  final int? valorCents;
  final DateTime? vencimento;
  final double? juros;
  final List<String> errors;
  final bool duplicate;

  bool get valid => errors.isEmpty && !duplicate;
}

class DebtCsvPreview {
  const DebtCsvPreview({required this.rows, required this.errors});

  final List<DebtCsvRow> rows;
  final List<String> errors;

  List<DebtCsvRow> get validRows => rows.where((row) => row.valid).toList();
  int get invalidCount => rows.where((row) => row.errors.isNotEmpty).length;
  int get duplicateCount => rows.where((row) => row.duplicate).length;
  bool get canImport => errors.isEmpty && validRows.isNotEmpty;
}

DebtCsvPreview previewDebtCsv(
  String source, {
  Iterable<Debt> existing = const [],
}) {
  final text = source.replaceFirst('\ufeff', '').trim();
  if (text.isEmpty) {
    return const DebtCsvPreview(rows: [], errors: ['O arquivo está vazio.']);
  }
  final delimiter = _delimiterOf(text);
  final parsed = _parseCsv(text, delimiter);
  if (parsed.error != null) {
    return DebtCsvPreview(rows: const [], errors: [parsed.error!]);
  }
  if (parsed.rows.isEmpty) {
    return const DebtCsvPreview(rows: [], errors: ['O arquivo está vazio.']);
  }
  final header = [
    for (final item in parsed.rows.first) item.trim().toLowerCase(),
  ];
  const required = ['nome', 'telefone', 'valor', 'vencimento', 'juros'];
  final missing = required.where((name) => !header.contains(name)).toList();
  if (missing.isNotEmpty) {
    return DebtCsvPreview(
      rows: const [],
      errors: [
        'Colunas ausentes: ${missing.join(', ')}. Use o arquivo-modelo.',
      ],
    );
  }
  final indexes = {for (final name in required) name: header.indexOf(name)};
  final known = <String>{for (final debt in existing) _debtKey(debt)};
  final seen = <String>{};
  final rows = <DebtCsvRow>[];

  for (var index = 1; index < parsed.rows.length; index++) {
    final values = parsed.rows[index];
    if (values.every((value) => value.trim().isEmpty)) continue;
    String field(String name) {
      final position = indexes[name]!;
      return position < values.length ? values[position].trim() : '';
    }

    final errors = <String>[];
    final nome = field('nome');
    final telefone = digitsOnly(field('telefone'));
    final valorCents = _money(field('valor'));
    final vencimento = _date(field('vencimento'));
    final juros = _percent(field('juros'));
    if (nome.isEmpty || nome.length > 80) errors.add('nome inválido');
    if (telefone.isNotEmpty && !isValidPhoneBr(telefone)) {
      errors.add('telefone inválido');
    }
    if (valorCents == null || valorCents <= 0 || valorCents > 10000000000) {
      errors.add('valor inválido');
    }
    if (vencimento == null) errors.add('vencimento inválido');
    if (juros == null || juros < 0 || juros > 1000) {
      errors.add('juros inválidos');
    }
    var duplicate = false;
    if (errors.isEmpty) {
      final key = _rowKey(nome, telefone, valorCents!, vencimento!, juros!);
      duplicate = known.contains(key) || !seen.add(key);
    }
    rows.add(
      DebtCsvRow(
        line: index + 1,
        nome: nome,
        telefone: telefone,
        valorCents: valorCents,
        vencimento: vencimento,
        juros: juros,
        errors: errors,
        duplicate: duplicate,
      ),
    );
  }

  final validCount = rows.where((row) => row.valid).length;
  final errors = <String>[];
  if (rows.isEmpty) errors.add('Nenhum lançamento encontrado.');
  if (validCount > 12) {
    errors.add(
      'Importe no máximo 12 lançamentos por vez para salvar tudo junto.',
    );
  }
  return DebtCsvPreview(rows: rows, errors: errors);
}

String _debtKey(Debt debt) => _rowKey(
  debt.nome,
  digitsOnly(debt.telefone),
  moneyCents(debt.valorPrincipal),
  debt.dataVencimento,
  debt.taxaJuros,
);

String _rowKey(
  String nome,
  String telefone,
  int cents,
  DateTime date,
  double rate,
) =>
    '${nome.trim().toLowerCase()}|$telefone|$cents|${date.year}-${date.month}-${date.day}|${moneyCents(rate)}';

int? _money(String raw) {
  var value = raw.replaceAll(RegExp(r'[Rr]\$|\s'), '');
  if (value.isEmpty) return null;
  if (value.contains(',')) {
    value = value.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(?:\.\d{3})+$').hasMatch(value)) {
    value = value.replaceAll('.', '');
  }
  final parsed = double.tryParse(value);
  return parsed == null || !parsed.isFinite ? null : moneyCents(parsed);
}

double? _percent(String raw) {
  if (raw.trim().isEmpty) return 0;
  var value = raw.trim().replaceAll('%', '');
  if (value.contains(',')) {
    value = value.replaceAll('.', '').replaceAll(',', '.');
  }
  final parsed = double.tryParse(value);
  return parsed != null && parsed.isFinite ? parsed : null;
}

DateTime? _date(String raw) {
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw);
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  final match = br ?? iso;
  if (match == null) return null;
  final year = int.parse(match.group(br == null ? 1 : 3)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(br == null ? 3 : 1)!);
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

String _delimiterOf(String source) {
  final first = source.split(RegExp(r'\r?\n')).first;
  var quoted = false;
  var commas = 0;
  var semicolons = 0;
  for (var i = 0; i < first.length; i++) {
    if (first[i] == '"') quoted = !quoted;
    if (!quoted && first[i] == ',') commas++;
    if (!quoted && first[i] == ';') semicolons++;
  }
  return semicolons >= commas ? ';' : ',';
}

({List<List<String>> rows, String? error}) _parseCsv(
  String source,
  String delimiter,
) {
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (char == '"') {
      if (quoted && i + 1 < source.length && source[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (!quoted && char == delimiter) {
      row.add(field.toString());
      field = StringBuffer();
    } else if (!quoted && (char == '\n' || char == '\r')) {
      if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') i++;
      row.add(field.toString());
      rows.add(row);
      row = <String>[];
      field = StringBuffer();
    } else {
      field.write(char);
    }
  }
  if (quoted) return (rows: const [], error: 'Há aspas não fechadas no CSV.');
  row.add(field.toString());
  rows.add(row);
  return (rows: rows, error: null);
}
