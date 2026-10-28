import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/customer_statement.dart';
import 'package:pago_app/services/statement_pdf.dart';

Debt debt({String id = 'd1', bool paid = false}) => Debt(
  id: id,
  userId: 'u1',
  nome: 'João Exemplo',
  telefone: '11987654321',
  valorPrincipal: 100,
  taxaJuros: 10,
  dataVencimento: DateTime(2026, 10, 30),
  statusPago: paid,
  clientScore: 80,
  createdAt: DateTime(2026, 10, 1),
  grupoId: 'g1',
  parcela: 1,
  totalParcelas: 3,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('statement reconciles centavos, installments and reversal history', () {
    final statement = CustomerStatement.build(
      name: 'João Exemplo',
      phone: '',
      debts: [debt()],
      payments: [
        Payment(
          id: 'p1',
          debtId: 'd1',
          userId: 'u1',
          valor: 40,
          data: DateTime(2026, 10, 3),
        ),
        Payment(
          id: 'p2',
          debtId: 'd1',
          userId: 'u1',
          valor: 30,
          data: DateTime(2026, 10, 4),
          estornadoEm: DateTime(2026, 10, 5),
          estornoMotivo: 'Registro duplicado',
        ),
        Payment(
          id: 'other',
          debtId: 'd2',
          userId: 'u1',
          valor: 500,
          data: DateTime(2026, 10, 6),
        ),
      ],
      generatedAt: DateTime(2026, 10, 7),
    );
    expect(statement.contractedCents, 11000);
    expect(statement.receivedCents, 4000);
    expect(statement.balanceCents, 7000);
    expect(statement.legacyAdjustmentCents, 0);
    expect(statement.entries.map((entry) => entry.kind), [
      StatementEntryKind.sale,
      StatementEntryKind.payment,
      StatementEntryKind.payment,
      StatementEntryKind.reversal,
    ]);
    expect(statement.entries.last.description, contains('Registro duplicado'));
    expect(
      statement.entries.every((entry) => entry.installment == '1/3'),
      isTrue,
    );
    expect(
      statement.entries.fold<int>(0, (sum, entry) => sum + entry.cents),
      statement.balanceCents,
    );
  });

  test(
    'historical paid flag is disclosed rather than fabricating a payment',
    () {
      final statement = CustomerStatement.build(
        name: 'João',
        phone: '',
        debts: [debt(paid: true)],
        payments: const [],
      );
      expect(statement.balanceCents, 0);
      expect(statement.receivedCents, 0);
      expect(statement.legacyAdjustmentCents, -11000);
      expect(statement.entries, hasLength(1));
      expect(
        statementCsv(statement),
        contains('Diferença de registros históricos'),
      );
    },
  );

  test('CSV quotes delimiters/newlines and neutralizes formula-like text', () {
    expect(
      csvCell('=HYPERLINK("https://example.test")'),
      '"\'=HYPERLINK(""https://example.test"")"',
    );
    expect(csvCell('   +SUM(A1)'), '"\'   +SUM(A1)"');
    expect(csvCell('@SUM(A1)'), '"\'@SUM(A1)"');
    expect(csvCell('nome;"apelido"\nlinha'), '"nome;""apelido""\nlinha"');
    expect(csvCell('-100,50'), '"-100,50"');
    expect(decimalCents(-10005), '-100,05');
    expect(
      csvDocument([
        ['Cliente', 'Nome'],
      ]),
      startsWith('\uFEFF'),
    );
  });

  test(
    'account CSV preserves reversed payments and separate supplier bills',
    () {
      final csv = accountCsv(
        debts: [debt()],
        payments: [
          Payment(
            id: 'p1',
            debtId: 'd1',
            userId: 'u1',
            valor: 10.01,
            data: DateTime(2026, 10, 3),
            estornadoEm: DateTime(2026, 10, 4),
            estornoMotivo: 'Correção',
          ),
        ],
        bills: [
          Bill(
            id: 'b1',
            userId: 'u1',
            fornecedor: 'Fornecedor',
            valor: 50,
            dataVencimento: DateTime(2026, 10, 30),
          ),
        ],
      );
      expect(csv, contains('"Estornado"'));
      expect(csv, contains('"10,01"'));
      expect(csv, contains('"Boleto a pagar"'));
      expect(csv, contains('"Correção"'));
      expect(csv, isNot(contains('password')));
    },
  );

  test(
    'PDF export renders a multipage statement without fetching fonts',
    () async {
      final loans = [for (var i = 0; i < 55; i++) debt(id: 'd$i')];
      final statement = CustomerStatement.build(
        name: 'João Exemplo',
        phone: '',
        debts: loans,
        payments: const [],
        generatedAt: DateTime(2026, 10, 23),
      );
      final bytes = await statementPdf(
        statement,
        merchantName: 'Comércio São José',
      );
      final data = latin1.decode(bytes);
      expect(data, startsWith('%PDF-'));
      expect(data.trimRight(), endsWith('%%EOF'));
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(data).length,
        greaterThan(1),
      );
    },
  );
}
