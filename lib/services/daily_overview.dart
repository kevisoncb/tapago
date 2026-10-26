import '../models/models.dart';

enum DailyFocus { today, overdue, upcoming, all }

extension DailyFocusInfo on DailyFocus {
  String get label => switch (this) {
    DailyFocus.today => 'Hoje',
    DailyFocus.overdue => 'Em atraso',
    DailyFocus.upcoming => 'Próximos 7 dias',
    DailyFocus.all => 'Todos',
  };

  String get emptyLabel => switch (this) {
    DailyFocus.today => 'Nenhum recebimento vence hoje',
    DailyFocus.overdue => 'Nenhum recebimento em atraso',
    DailyFocus.upcoming => 'Nenhum vencimento nos próximos 7 dias',
    DailyFocus.all => 'Nenhum lançamento em aberto',
  };
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Uses calendar dates so time-of-day does not hide a due payment.
/// "Próximos 7 dias" includes today through six calendar days ahead.
List<Debt> debtsForFocus(
  Iterable<Debt> debts,
  DailyFocus focus, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final today = DateTime.utc(clock.year, clock.month, clock.day);
  final end = today.add(const Duration(days: 7));
  final selected = debts.where((debt) {
    if (debt.statusPago) return false;
    final due = DateTime.utc(
      debt.dataVencimento.year,
      debt.dataVencimento.month,
      debt.dataVencimento.day,
    );
    return switch (focus) {
      DailyFocus.today => due == today,
      DailyFocus.overdue => due.isBefore(today),
      DailyFocus.upcoming => !due.isBefore(today) && due.isBefore(end),
      DailyFocus.all => true,
    };
  }).toList()..sort((a, b) => a.dataVencimento.compareTo(b.dataVencimento));
  return selected;
}
