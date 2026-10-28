import '../models/models.dart';
import 'payment_ledger.dart';

class AgingBucket {
  const AgingBucket({
    required this.label,
    required this.cents,
    required this.count,
  });

  final String label;
  final int cents;
  final int count;
}

class BusinessReport {
  const BusinessReport({
    required this.start,
    required this.end,
    required this.receivedCents,
    required this.receivedCount,
    required this.forecastCents,
    required this.forecastCount,
    required this.overdueCents,
    required this.overdueCount,
    required this.supplierPaidCents,
    required this.supplierPaidCount,
    required this.supplierDueCents,
    required this.supplierDueCount,
    required this.supplierOverdueCents,
    required this.supplierOverdueCount,
    required this.aging,
  });

  final DateTime start;
  final DateTime end;
  final int receivedCents;
  final int receivedCount;
  final int forecastCents;
  final int forecastCount;
  final int overdueCents;
  final int overdueCount;
  final int supplierPaidCents;
  final int supplierPaidCount;
  final int supplierDueCents;
  final int supplierDueCount;
  final int supplierOverdueCents;
  final int supplierOverdueCount;
  final List<AgingBucket> aging;
}

BusinessReport buildBusinessReport({
  required Iterable<Debt> debts,
  required Iterable<Payment> payments,
  required Iterable<Bill> bills,
  required DateTime start,
  required DateTime end,
  DateTime? now,
}) {
  final first = _day(start);
  final last = _day(end);
  if (last.isBefore(first)) {
    throw ArgumentError.value(
      end,
      'end',
      'O fim deve ser posterior ao início.',
    );
  }
  final today = _day(now ?? DateTime.now());
  final activePayments = payments
      .where((payment) => !payment.estornado)
      .toList();
  final received = activePayments
      .where((payment) => _inside(payment.data, first, last))
      .toList();

  var forecastCents = 0;
  var forecastCount = 0;
  var overdueCents = 0;
  var overdueCount = 0;
  final agingCents = [0, 0, 0];
  final agingCounts = [0, 0, 0];

  for (final debt in debts) {
    // Registros legados podem ter sido quitados antes de existir um histórico
    // detalhado de pagamentos. Neles, o marcador atual ainda é necessário.
    if (debt.statusPago) continue;
    final debtPayments = activePayments.where(
      (payment) => payment.debtId == debt.id,
    );
    final balanceCents = moneyCents(ledgerBalance(debt, debtPayments).saldo);
    if (balanceCents <= 0) continue;
    final due = _day(debt.dataVencimento);
    if (due.isBefore(today)) {
      overdueCents += balanceCents;
      overdueCount++;
      final age = today.difference(due).inDays;
      final index = age <= 7
          ? 0
          : age <= 30
          ? 1
          : 2;
      agingCents[index] += balanceCents;
      agingCounts[index]++;
    } else if (_inside(due, first, last)) {
      forecastCents += balanceCents;
      forecastCount++;
    }
  }

  final supplierPaid = bills
      .where(
        (bill) =>
            bill.pago &&
            bill.pagoEm != null &&
            _inside(bill.pagoEm!, first, last),
      )
      .toList();
  final supplierDue = bills
      .where(
        (bill) =>
            !bill.pago &&
            !_day(bill.dataVencimento).isBefore(today) &&
            _inside(bill.dataVencimento, first, last),
      )
      .toList();
  final supplierOverdue = bills
      .where((bill) => !bill.pago && _day(bill.dataVencimento).isBefore(today))
      .toList();

  return BusinessReport(
    start: first,
    end: last,
    receivedCents: received.fold(
      0,
      (sum, item) => sum + moneyCents(item.valor),
    ),
    receivedCount: received.length,
    forecastCents: forecastCents,
    forecastCount: forecastCount,
    overdueCents: overdueCents,
    overdueCount: overdueCount,
    supplierPaidCents: supplierPaid.fold(
      0,
      (sum, item) => sum + moneyCents(item.valor),
    ),
    supplierPaidCount: supplierPaid.length,
    supplierDueCents: supplierDue.fold(
      0,
      (sum, item) => sum + moneyCents(item.valor),
    ),
    supplierDueCount: supplierDue.length,
    supplierOverdueCents: supplierOverdue.fold(
      0,
      (sum, item) => sum + moneyCents(item.valor),
    ),
    supplierOverdueCount: supplierOverdue.length,
    aging: [
      AgingBucket(
        label: '1 a 7 dias',
        cents: agingCents[0],
        count: agingCounts[0],
      ),
      AgingBucket(
        label: '8 a 30 dias',
        cents: agingCents[1],
        count: agingCounts[1],
      ),
      AgingBucket(
        label: 'Mais de 30 dias',
        cents: agingCents[2],
        count: agingCounts[2],
      ),
    ],
  );
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

bool _inside(DateTime value, DateTime start, DateTime end) {
  final date = _day(value);
  return !date.isBefore(start) && !date.isAfter(end);
}
