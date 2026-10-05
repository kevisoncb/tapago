import 'package:flutter_test/flutter_test.dart';
import 'package:tapago_app/services/debt_balance.dart';
import 'package:tapago_app/services/auth_messages.dart';
import 'package:tapago_app/services/pix_status.dart';
import 'package:tapago_app/services/password_hash.dart';
import 'package:tapago_app/services/receipt_amount.dart';
import 'package:tapago_app/services/trust_score.dart';
import 'package:tapago_app/services/voice_debt_parser.dart';
import 'package:tapago_app/utils/premium_access.dart';

void main() {
  test('pagamento parcial abate e o juro fica no restante', () {
    final aberto = debtBalance(principal: 100, taxaPercent: 10, paid: 0);
    expect(aberto.saldo, 110);
    expect(aberto.jurosRestantes, 10);

    final parcial = debtBalance(principal: 100, taxaPercent: 10, paid: 40);
    expect(parcial.saldo, 70);
    expect(parcial.principalRestante, closeTo(63.64, 0.01));
    expect(parcial.jurosRestantes, closeTo(6.36, 0.01));

    final outro = debtBalance(principal: 100, taxaPercent: 10, paid: 70);
    expect(outro.saldo, 40);

    final pago = debtBalance(principal: 100, taxaPercent: 10, paid: 110);
    expect(pago.quitado, isTrue);
    expect(pago.saldo, 0);
  });

  test('premium só vale com data futura', () {
    final now = DateTime(2026, 10, 2);
    expect(
      premiumIsActive(isPremium: true, until: null, now: now),
      isFalse,
    );
    expect(
      premiumIsActive(
        isPremium: true,
        until: now.subtract(const Duration(days: 1)),
        now: now,
      ),
      isFalse,
    );
    expect(
      premiumIsActive(
        isPremium: true,
        until: now.add(const Duration(days: 10)),
        now: now,
      ),
      isTrue,
    );
    expect(
      premiumIsActive(
        isPremium: false,
        until: now.add(const Duration(days: 10)),
        now: now,
      ),
      isFalse,
    );
  });

  test('score cai com atraso e sobe com pagamento em dia', () {
    final now = DateTime(2026, 10, 2);
    final late = trustScore(
      due: DateTime(2026, 9, 1),
      paid: false,
      principal: 100,
      paidSum: 0,
      now: now,
    );
    final onTime = trustScore(
      due: DateTime(2026, 10, 20),
      paid: true,
      principal: 100,
      paidSum: 100,
      now: now,
    );
    expect(late, lessThan(50));
    expect(onTime, greaterThan(90));
  });

  test('ocr lê o valor pago e ignora o troco', () {
    const receipt = '''
PIX
Valor: R\$ 1.250,00
Troco: R\$ 0,00
''';
    expect(extractReceiptAmount(receipt), 1250);
  });

  test('voz preenche nome, telefone, valor, juros e prazo', () {
    final draft = parseVoiceDebt(
      'Nome João Silva telefone 11 98888-1234 valor 750 reais juros 5 por cento vence em 30 dias',
      now: DateTime(2026, 10, 2),
    );
    expect(draft.nome, 'João Silva');
    expect(draft.telefone, '11988881234');
    expect(draft.valor, 750);
    expect(draft.juros, 5);
    expect(draft.vencimento, DateTime(2026, 11, 1));
  });

  test('senha errada não gera o mesmo hash', () {
    final salt = 'salt-fixo';
    expect(hashPassword('123456', salt), hashPassword('123456', salt));
    expect(hashPassword('123456', salt), isNot(hashPassword('123457', salt)));
  });

  test('PIX só libera Premium quando o Asaas confirma', () {
    expect(pixStatusGrantsPremium('PENDING'), isFalse);
    expect(pixStatusGrantsPremium('RECEIVED'), isTrue);
    expect(pixStatusGrantsPremium('CONFIRMED'), isTrue);
  });

  test('cadastro exige nome, e-mail e senha', () {
    expect(
      validateAccount(
        nome: 'A',
        email: 'a@b.com',
        password: '123456',
        creating: true,
      ),
      isNotNull,
    );
    expect(
      validateAccount(
        nome: 'Ana',
        email: 'ana@email.com',
        password: '123456',
        creating: true,
      ),
      isNull,
    );
  });
}
