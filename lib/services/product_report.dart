import '../models/models.dart';

class ProductLine {
  const ProductLine({
    required this.nome,
    required this.quantidade,
    required this.total,
  });

  final String nome;
  final double quantidade;
  final double total;
}

class DayItems {
  const DayItems({required this.day, required this.itens});

  final DateTime day;
  final List<DebtItem> itens;

  double get total => itens.fold(0.0, (sum, item) => sum + item.total);
}

/// Itens de produto de um cliente em um mês. Só entra o que foi lançado
/// naquele mês (data e hora gravadas no momento do lançamento).
class ProductReport {
  ProductReport._(this.month, this.debts, this.itens);

  final DateTime month;

  /// Lançamentos que têm ao menos um item no mês.
  final List<Debt> debts;
  final List<DebtItem> itens;

  bool get isEmpty => itens.isEmpty;

  double get total => itens.fold(0.0, (sum, item) => sum + item.total);

  List<ProductLine> byProduct() {
    final names = <String, String>{};
    final qty = <String, double>{};
    final sum = <String, double>{};
    for (final item in itens) {
      final key = item.nome.trim().toLowerCase();
      names.putIfAbsent(key, () => item.nome.trim());
      qty[key] = (qty[key] ?? 0) + item.quantidade;
      sum[key] = (sum[key] ?? 0) + item.total;
    }
    final lines = [
      for (final key in names.keys)
        ProductLine(nome: names[key]!, quantidade: qty[key]!, total: sum[key]!),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return lines;
  }

  List<DayItems> byDay() {
    final days = <DateTime, List<DebtItem>>{};
    for (final item in itens) {
      final day = DateTime(item.em.year, item.em.month, item.em.day);
      days.putIfAbsent(day, () => []).add(item);
    }
    final keys = days.keys.toList()..sort();
    return [for (final day in keys) DayItems(day: day, itens: days[day]!)];
  }
}

ProductReport buildProductReport({
  required Iterable<Debt> debts,
  required DateTime month,
}) {
  bool inMonth(DateTime d) => d.year == month.year && d.month == month.month;
  final used = <Debt>[];
  final all = <DebtItem>[];
  for (final debt in debts) {
    final mine = debt.itens.where((item) => inMonth(item.em)).toList();
    if (mine.isEmpty) continue;
    used.add(debt);
    all.addAll(mine);
  }
  all.sort((a, b) => a.em.compareTo(b.em));
  return ProductReport._(DateTime(month.year, month.month), used, all);
}

/// Meses (do mais recente ao mais antigo) em que há itens lançados.
List<DateTime> monthsWithItems(Iterable<Debt> debts) {
  final months = <DateTime>{
    for (final debt in debts)
      for (final item in debt.itens) DateTime(item.em.year, item.em.month),
  };
  return months.toList()..sort((a, b) => b.compareTo(a));
}

const _monthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

String monthLabel(DateTime month) =>
    '${_monthNames[month.month - 1]} de ${month.year}';

/// "5" para inteiros, "1,5" para fracionados.
String quantityLabel(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2).replaceAll('.', ',');

String hourLabel(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String dayLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
