import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/auto_cleanup.dart';

Debt _debt(String id, {bool pago = true, bool manter = false}) => Debt(
  id: id,
  userId: 'u',
  nome: 'Zeca',
  telefone: '',
  valorPrincipal: 61,
  taxaJuros: 0,
  dataVencimento: DateTime(2026, 11, 4),
  statusPago: pago,
  clientScore: 80,
  manter: manter,
);

Payment _pay(String debtId, DateTime when, {bool estornado = false}) => Payment(
  id: 'p$debtId${when.day}',
  debtId: debtId,
  userId: 'u',
  valor: 61,
  data: when,
  descricao: 'Quitação',
  estornadoEm: estornado ? when : null,
);

void main() {
  test('desmarcar manter sobrescreve o valor antigo ao salvar', () {
    expect(_debt('a', manter: true).toFirestore()['manter'], isTrue);
    expect(_debt('a').toFirestore()['manter'], isFalse);
  });

  final now = DateTime(2026, 11, 20, 12);
  double zero(Debt d) => 0;

  test('contagem regressiva a partir do último pagamento', () {
    final notice = cleanupNoticeFor(
      debts: [_debt('a')],
      payments: [_pay('a', DateTime(2026, 11, 18, 12))],
      saldoOf: zero,
      now: now,
    )!;
    expect(notice.daysLeft, 5);
    expect(notice.deleteAt, DateTime(2026, 11, 25, 12));
    expect(notice.kept, isFalse);
  });

  test('sem aviso se ainda há lançamento em aberto', () {
    expect(
      cleanupNoticeFor(
        debts: [_debt('a'), _debt('b', pago: false)],
        payments: [_pay('a', DateTime(2026, 11, 18))],
        saldoOf: (d) => d.id == 'b' ? 10 : 0,
        now: now,
      ),
      isNull,
    );
  });

  test('manter e estorno', () {
    final kept = cleanupNoticeFor(
      debts: [_debt('a', manter: true)],
      payments: [_pay('a', DateTime(2026, 11, 1))],
      saldoOf: zero,
      now: now,
    )!;
    expect(kept.kept, isTrue);
    expect(kept.daysLeft, 0);
    final estorno = cleanupNoticeFor(
      debts: [_debt('a')],
      payments: [
        _pay('a', DateTime(2026, 11, 10)),
        _pay('a', DateTime(2026, 11, 19), estornado: true),
      ],
      saldoOf: zero,
      now: now,
    )!;
    expect(estorno.closedAt, DateTime(2026, 11, 10));
  });
}
