import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/client_match.dart';
import 'package:pago_app/services/debt_balance.dart';
import 'package:pago_app/services/auth_messages.dart';
import 'package:pago_app/services/bill_installments.dart';
import 'package:pago_app/services/pix_status.dart';
import 'package:pago_app/services/password_hash.dart';
import 'package:pago_app/services/receipt_amount.dart';
import 'package:pago_app/services/reminder_service.dart';
import 'package:pago_app/services/trust_score.dart';
import 'package:pago_app/services/voice_debt_parser.dart';
import 'package:pago_app/services/whatsapp_service.dart';
import 'package:pago_app/utils/formatters.dart';
import 'package:pago_app/utils/masks.dart';
import 'package:pago_app/utils/premium_access.dart';

void main() {
  test('pagamento do total baixa juros e depois o principal', () {
    final aberto = debtBalance(principal: 100, taxaPercent: 10);
    expect(aberto.saldo, 110);
    expect(aberto.jurosRestantes, 10);

    final parcial = debtBalance(principal: 100, taxaPercent: 10, paid: 40);
    expect(parcial.saldo, 70);
    expect(parcial.principalRestante, 70);
    expect(parcial.jurosRestantes, 0);

    final outro = debtBalance(principal: 100, taxaPercent: 10, paid: 70);
    expect(outro.saldo, 40);

    final pago = debtBalance(principal: 100, taxaPercent: 10, paid: 110);
    expect(pago.quitado, isTrue);
    expect(pago.saldo, 0);
  });

  test('pagar só juros não come o principal', () {
    final depois = debtBalance(
      principal: 1000,
      taxaPercent: 20,
      lancamentos: const [LedgerPay(valor: 200, somenteJuros: true)],
    );
    expect(depois.jurosRestantes, 0);
    expect(depois.principalRestante, 1000);
    expect(depois.saldo, 1000);
  });

  test('depois dos juros o total baixa o principal', () {
    final depois = debtBalance(
      principal: 1000,
      taxaPercent: 20,
      lancamentos: const [
        LedgerPay(valor: 200, somenteJuros: true),
        LedgerPay(valor: 1000),
      ],
    );
    expect(depois.quitado, isTrue);
    expect(depois.saldo, 0);
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
    expect(
      extractReceiptAmount('Comprovante PIX\nValor pago: R\$ 200,00'),
      200,
    );
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

    final solto = parseVoiceDebt(
      'Carlos 450 reais vence amanhã',
      now: DateTime(2026, 10, 5),
    );
    expect(solto.nome, 'Carlos');
    expect(solto.valor, 450);
    expect(solto.vencimento, DateTime(2026, 10, 6));
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

  test('mensagem pronta preenche nome e valor', () {
    expect(WhatsAppService.preview(''), contains('Carlos'));
    expect(
      WhatsAppService.preview('Oi {primeiro}, paga {valor}{pix}'),
      'Oi Carlos, paga R\$ 450,00 PIX: sua-chave',
    );
  });

  test('chave PIX vai em toda cobrança do WhatsApp', () async {
    await initializeDateFormatting('pt_BR');
    final debt = Debt(
      id: '1',
      userId: 'u',
      nome: 'Carlos Oliveira',
      telefone: '11987654321',
      valorPrincipal: 450,
      taxaJuros: 0,
      dataVencimento: DateTime(2026, 10, 5),
      statusPago: false,
      clientScore: 80,
    );
    for (final action in WhatsAppAction.values) {
      final text = WhatsAppService.messageFor(
        action: action,
        tone: WhatsAppTone.amigavel,
        debt: debt,
        saldo: 450,
        chavePix: 'ana@email.com',
      );
      expect(text, contains('ana@email.com'));
    }
    expect(
      whatsAppActionForDue(DateTime(2026, 10, 6), now: DateTime(2026, 10, 5)),
      WhatsAppAction.preventivo,
    );
    expect(
      whatsAppActionForDue(DateTime(2026, 10, 6), now: DateTime(2026, 10, 6)),
      WhatsAppAction.cobrarHoje,
    );
    expect(
      whatsAppActionForDue(DateTime(2026, 10, 6), now: DateTime(2026, 10, 7)),
      WhatsAppAction.atraso,
    );
  });

  test('lembrete cobre véspera, dia e atraso', () {
    final due = DateTime(2026, 10, 6);
    expect(
      reminderKind(due: due, day: DateTime(2026, 10, 5), pago: false),
      ReminderKind.amanha,
    );
    expect(
      reminderKind(due: due, day: DateTime(2026, 10, 6), pago: false),
      ReminderKind.hoje,
    );
    expect(
      reminderKind(due: due, day: DateTime(2026, 10, 7), pago: false),
      ReminderKind.atraso,
    );
    expect(
      reminderKind(due: due, day: DateTime(2026, 10, 4), pago: false),
      isNull,
    );
    expect(
      reminderKind(due: due, day: DateTime(2026, 10, 6), pago: true),
      isNull,
    );
  });

  test('cadastro exige nome, e-mail, senha e aceite dos termos', () {
    expect(
      validateAccount(
        nome: 'A',
        email: 'a@b.com',
        password: '123456',
        creating: true,
        acceptedTerms: true,
      ),
      isNotNull,
    );
    expect(
      validateAccount(
        nome: 'Ana',
        email: 'ana@email.com',
        password: '123456',
        creating: true,
        acceptedTerms: false,
      ),
      'Aceite os Termos de Uso e a Política de Privacidade para criar a conta.',
    );
    expect(
      validateAccount(
        nome: 'Ana',
        email: 'ana@email.com',
        password: '123456',
        creating: true,
        passwordConfirm: '123457',
        acceptedTerms: true,
      ),
      'As senhas não coincidem.',
    );
    expect(
      validateAccount(
        nome: 'Ana',
        email: 'ana@email.com',
        password: '123456',
        creating: true,
        passwordConfirm: '123456',
        acceptedTerms: true,
      ),
      isNull,
    );
  });

  test('máscaras de telefone, CPF, PIX e dinheiro', () {
    expect(formatPhoneBr('11988881234'), '(11) 98888-1234');
    expect(formatCpf('12345678909'), '123.456.789-09');
    expect(isValidCpf('123.456.789-09'), isTrue);
    expect(isValidCpf('11111111111'), isFalse);
    expect(formatPixKey('ana@email.com'), 'ana@email.com');
    expect(formatPixKey('11988881234'), '(11) 98888-1234');
    expect(parseMoneyInput(r'R$ 1.250,50'), 1250.50);
    expect(formatPercentInput('20,00'), '20,00');
    expect(parsePercentInput('20,00'), 20);
    expect(isValidPixKey('ana@email.com'), isTrue);
    expect(isValidPixKey('ANA@EMAIL.COM'), isTrue);
    expect(isValidPixKey('123.456.789-09'), isTrue);
    expect(isValidPixKey('111.111.111-11'), isFalse);
    expect(isValidPixKey('11988881234'), isTrue);
    expect(isValidPixKey(''), isTrue);
  });

  test('histórico diz se foi juros ou valor total', () {
    expect(paymentKindLabel('Juros'), 'Somente juros do mês');
    expect(paymentKindLabel('Abatimento'), 'Parte do valor');
    expect(paymentKindLabel('Quitação'), 'Valor total');
  });

  test('cliente duplicado bate nome e telefone', () {
    final carlos = Debt(
      id: '1',
      userId: 'u',
      nome: 'Carlos Oliveira',
      telefone: '11987654321',
      valorPrincipal: 100,
      taxaJuros: 0,
      dataVencimento: DateTime(2026, 10, 5),
      statusPago: false,
      clientScore: 80,
    );
    final same = findClientHits(
      debts: [carlos],
      nome: 'Carlos Oliveira',
      telefone: '(11) 98765-4321',
    );
    expect(same.single.confirmed, isTrue);

    final onlyName = findClientHits(
      debts: [carlos],
      nome: 'Carlos Oliveira',
      telefone: '21999998888',
    );
    expect(onlyName.single.nameTaken, isTrue);

    final onlyPhone = findClientHits(
      debts: [carlos],
      nome: 'Outro Nome',
      telefone: '11987654321',
    );
    expect(onlyPhone.single.phoneTaken, isTrue);

    expect(
      firstBlockingHit(
        debts: [carlos],
        nome: 'Outro Nome',
        telefone: '11987654321',
      )?.phoneTaken,
      isTrue,
    );
    expect(
      firstBlockingHit(
        debts: [carlos],
        nome: 'Carlos Oliveira',
        telefone: '11987654321',
      ),
      isNotNull,
    );
    expect(
      firstBlockingHit(
        debts: [carlos],
        nome: 'Carlos Oliveira',
        telefone: '11987654321',
        allowPhone: '11987654321',
        allowNome: 'Carlos Oliveira',
      ),
      isNull,
    );
    expect(
      firstBlockingHit(
        debts: [carlos],
        nome: 'Carlos Oliveira',
        telefone: '21999998888',
      ),
      isNull,
    );

    expect(cadernetaMatchesQuery(carlos, 'oliveira'), isTrue);
    expect(cadernetaMatchesQuery(carlos, '98765'), isTrue);
    expect(cadernetaMatchesQuery(carlos, 'mariana'), isFalse);
  });

  test('caderneta agrupa a mesma pessoa e mostra quitado junto', () {
    final aberto = Debt(
      id: '1',
      userId: 'u',
      nome: 'Carlos Oliveira',
      telefone: '11987654321',
      valorPrincipal: 450,
      taxaJuros: 0,
      dataVencimento: DateTime(2026, 10, 5),
      statusPago: false,
      clientScore: 80,
    );
    final quitado = Debt(
      id: '2',
      userId: 'u',
      nome: 'Carlos Oliveira',
      telefone: '(11) 98765-4321',
      valorPrincipal: 200,
      taxaJuros: 0,
      dataVencimento: DateTime(2026, 8, 1),
      statusPago: true,
      clientScore: 80,
    );
    final outra = Debt(
      id: '3',
      userId: 'u',
      nome: 'Mariana',
      telefone: '21999998888',
      valorPrincipal: 80,
      taxaJuros: 0,
      dataVencimento: DateTime(2026, 9, 1),
      statusPago: true,
      clientScore: 80,
    );
    final grouped = groupContacts([aberto, quitado, outra]);
    expect(grouped, hasLength(2));
    expect(grouped.first.nome, 'Carlos Oliveira');
    expect(grouped.first.debts, hasLength(2));
    expect(grouped.last.nome, 'Mariana');
    expect(contactMatchesQuery(grouped.first, 'carlos'), isTrue);
    expect(contactMatchesQuery(grouped.first, 'mariana'), isFalse);
  });

  test('boleto parcelado divide em centavos e soma o total', () {
    final parcelas = splitBill(
      total: 1000,
      base: DateTime(2026, 10, 9),
      prazos: const [30, 60, 90],
    );
    expect(parcelas, hasLength(3));
    expect(parcelas.map((item) => item.valor), [333.33, 333.33, 333.34]);
    expect(parcelas.fold<double>(0, (sum, item) => sum + item.valor),
        closeTo(1000, 0.001));
    expect(parcelas.first.vencimento, DateTime(2026, 11, 8));
    expect(parcelas.last.vencimento, DateTime(2027, 1, 7));
    expect(parcelas.last.parcela, 3);
  });

  test('prazos e código do boleto', () {
    expect(parsePrazos('15/30/45'), [15, 30, 45]);
    expect(parsePrazos('28 56, 84'), [28, 56, 84]);
    expect(parsePrazos('30/30'), isNull);
    expect(parsePrazos('60/30'), isNull);
    expect(parsePrazos(''), isNull);
    expect(normalizeBoletoCode(''), '');
    expect(normalizeBoletoCode('123'), isNull);
    final linha =
        '23793.38128 60000.000003 00000.000400 1 84340000010000';
    expect(normalizeBoletoCode(linha), hasLength(47));
  });

  test('boleto no modelo e no lembrete', () {
    final bill = Bill(
      id: 'b1',
      userId: 'u',
      fornecedor: 'Distribuidora Silva',
      valor: 500,
      dataVencimento: DateTime(2026, 10, 10),
      parcela: 2,
      totalParcelas: 3,
    );
    final back = Bill.fromMap(bill.toMap());
    expect(back.fornecedor, 'Distribuidora Silva');
    expect(back.parcelaLabel, 'Parcela 2 de 3');
    expect(back.pago, isFalse);

    BillReminderKind? on(int day) => billReminderKind(
          due: bill.dataVencimento,
          day: DateTime(2026, 10, day),
          pago: false,
        );
    expect(on(7), BillReminderKind.tresDias);
    expect(on(8), isNull);
    expect(on(9), BillReminderKind.amanha);
    expect(on(10), BillReminderKind.hoje);
    expect(on(12), BillReminderKind.atraso);
    expect(on(5), isNull);
    expect(
      billReminderKind(
        due: bill.dataVencimento,
        day: DateTime(2026, 10, 12),
        pago: true,
      ),
      isNull,
    );
    expect(
      billReminderTitle(BillReminderKind.tresDias, [bill]),
      'Boleto de Distribuidora Silva vence em 3 dias.',
    );
    expect(billReminderTitle(BillReminderKind.atraso, [bill, bill]),
        '2 boletos atrasados.');
  });
}
