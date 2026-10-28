import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/daily_overview.dart';

Debt debt(String id, DateTime due, {bool paid = false}) => Debt(
  id: id,
  userId: 'u',
  nome: id,
  telefone: '',
  valorPrincipal: 10,
  taxaJuros: 0,
  dataVencimento: due,
  statusPago: paid,
  clientScore: 80,
);

void main() {
  test('today includes any time on due date and excludes paid records', () {
    final now = DateTime(2026, 10, 23, 17);
    final debts = [
      debt('early', DateTime(2026, 10, 23)),
      debt('late', DateTime(2026, 10, 23, 23, 59)),
      debt('tomorrow', DateTime(2026, 10, 24)),
      debt('paid', DateTime(2026, 10, 23), paid: true),
    ];
    expect(debtsForFocus(debts, DailyFocus.today, now: now).map((d) => d.id), [
      'early',
      'late',
    ]);
  });

  test(
    'seven-day outlook includes today, excludes overdue and the eighth date',
    () {
      final now = DateTime(2026, 10, 23);
      final debts = [
        debt('overdue', DateTime(2026, 10, 22)),
        debt('last', DateTime(2026, 10, 29)),
        debt('outside', DateTime(2026, 10, 30)),
        debt('today', DateTime(2026, 10, 23)),
      ];
      expect(
        debtsForFocus(debts, DailyFocus.upcoming, now: now).map((d) => d.id),
        ['today', 'last'],
      );
      expect(
        debtsForFocus(debts, DailyFocus.overdue, now: now).single.id,
        'overdue',
      );
    },
  );

  test('all retains only open records across month boundary', () {
    final debts = [
      debt('next', DateTime(2026, 11, 2)),
      debt('old', DateTime(2026, 9, 30)),
      debt('paid', DateTime(2026, 10, 31), paid: true),
    ];
    expect(debtsForFocus(debts, DailyFocus.all).map((d) => d.id), [
      'old',
      'next',
    ]);
  });
}
