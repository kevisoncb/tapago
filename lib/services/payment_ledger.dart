import '../models/models.dart';
import 'debt_balance.dart';

int moneyCents(double value) {
  if (!value.isFinite) throw StateError('Informe um valor válido.');
  return (value * 100).round();
}

List<Payment> activeLedger(Iterable<Payment> payments) =>
    payments.where((payment) => !payment.estornado).toList()..sort((a, b) {
      final date = a.data.compareTo(b.data);
      return date != 0 ? date : a.id.compareTo(b.id);
    });

DebtBalance ledgerBalance(Debt debt, Iterable<Payment> payments) => debtBalance(
  principal: debt.valorPrincipal,
  taxaPercent: debt.taxaJuros,
  lancamentos: [
    for (final payment in activeLedger(payments))
      LedgerPay(
        valor: payment.valor,
        somenteJuros: payment.descricao == 'Juros',
      ),
  ],
);

bool samePayment(Payment a, Payment b) =>
    a.id == b.id &&
    a.debtId == b.debtId &&
    a.userId == b.userId &&
    moneyCents(a.valor) == moneyCents(b.valor) &&
    a.data.isAtSameMomentAs(b.data) &&
    a.descricao == b.descricao;

void validatePayment(Debt debt, Iterable<Payment> payments, Payment payment) {
  if (payment.userId != debt.userId || payment.debtId != debt.id) {
    throw StateError('Este pagamento não pertence a esta caderneta.');
  }
  final cents = moneyCents(payment.valor);
  if (cents <= 0 || cents > 10000000000 || payment.estornado) {
    throw StateError('Informe um valor de pagamento válido.');
  }
  final balance = ledgerBalance(debt, payments);
  if (debt.statusPago || balance.quitado) {
    throw StateError('Esta caderneta já está quitada. Atualize os dados.');
  }
  final available = payment.descricao == 'Juros'
      ? balance.jurosRestantes
      : balance.saldo;
  if (cents > moneyCents(available)) {
    throw StateError(
      'O pagamento ultrapassa o saldo atual. Atualize os dados.',
    );
  }
}
