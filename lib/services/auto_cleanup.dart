import '../models/models.dart';

const cleanupRetentionDays = 7;

/// Contagem regressiva da limpeza automática de uma caderneta quitada.
class CleanupNotice {
  const CleanupNotice({
    required this.closedAt,
    required this.deleteAt,
    required this.daysLeft,
    required this.kept,
  });

  final DateTime closedAt;
  final DateTime deleteAt;
  final int daysLeft;

  /// O dono marcou "manter": a limpeza não apaga esta caderneta.
  final bool kept;
}

/// Mesma regra do servidor (functions/cleanup.js): só entra quando TODOS os
/// lançamentos do cliente estão quitados; o prazo conta do último pagamento
/// (pagamento estornado não vale).
CleanupNotice? cleanupNoticeFor({
  required List<Debt> debts,
  required List<Payment> payments,
  required double Function(Debt debt) saldoOf,
  required DateTime now,
}) {
  if (debts.isEmpty) return null;
  final settled = debts.every(
    (debt) => debt.statusPago || saldoOf(debt) <= 0.009,
  );
  if (!settled) return null;
  final ids = debts.map((debt) => debt.id).toSet();
  DateTime? closed;
  for (final payment in payments) {
    if (!ids.contains(payment.debtId) || payment.estornado) continue;
    if (closed == null || payment.data.isAfter(closed)) closed = payment.data;
  }
  if (closed == null) {
    for (final debt in debts) {
      for (final candidate in [debt.createdAt, debt.dataVencimento]) {
        if (candidate != null && (closed == null || candidate.isAfter(closed))) {
          closed = candidate;
        }
      }
    }
  }
  if (closed == null) return null;
  final deleteAt = closed.add(const Duration(days: cleanupRetentionDays));
  final left = deleteAt.difference(now);
  final days = left.isNegative ? 0 : (left.inMinutes / 1440).ceil();
  return CleanupNotice(
    closedAt: closed,
    deleteAt: deleteAt,
    daysLeft: days,
    kept: debts.any((debt) => debt.manter),
  );
}
