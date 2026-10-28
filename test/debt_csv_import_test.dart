import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/debt_csv_import.dart';

void main() {
  test('lê modelo brasileiro, aspas e valores em centavos', () {
    final preview = previewDebtCsv('''nome;telefone;valor;vencimento;juros
"Maria; da Silva";11999998888;1.234,56;30/11/2026;2,5
João Souza;;99.90;2026-12-15;1.25
''');
    expect(preview.errors, isEmpty);
    expect(preview.validRows, hasLength(2));
    expect(preview.validRows.first.nome, 'Maria; da Silva');
    expect(preview.validRows.first.valorCents, 123456);
    expect(preview.validRows.first.juros, 2.5);
    expect(preview.validRows.last.valorCents, 9990);
    expect(preview.validRows.last.juros, 1.25);
  });

  test(
    'marca duplicatas no arquivo e na caderneta sem impedir linhas válidas',
    () {
      final existing = Debt(
        id: 'd',
        userId: 'u',
        nome: 'Maria',
        telefone: '11999998888',
        valorPrincipal: 100,
        taxaJuros: 0,
        dataVencimento: DateTime(2026, 11, 30),
        statusPago: false,
        clientScore: 80,
      );
      final preview = previewDebtCsv(
        '''nome;telefone;valor;vencimento;juros
Maria;11999998888;100,00;30/11/2026;0
João;;50,00;01/12/2026;0
João;;50,00;01/12/2026;0
''',
        existing: [existing],
      );
      expect(preview.validRows, hasLength(1));
      expect(preview.duplicateCount, 2);
      expect(preview.canImport, isTrue);
    },
  );

  test('expõe erros por linha e limita o lote atômico a 12 itens', () {
    final invalid = previewDebtCsv('''nome;telefone;valor;vencimento;juros
;123;zero;31/02/2026;2000
''');
    expect(invalid.invalidCount, 1);
    expect(invalid.canImport, isFalse);
    expect(
      invalid.rows.single.errors,
      containsAll([
        'nome inválido',
        'telefone inválido',
        'valor inválido',
        'vencimento inválido',
        'juros inválidos',
      ]),
    );

    final rows = List.generate(
      13,
      (index) =>
          'Cliente $index;;10,00;${(index + 1).toString().padLeft(2, '0')}/12/2026;0',
    ).join('\n');
    final tooMany = previewDebtCsv(
      'nome;telefone;valor;vencimento;juros\n$rows',
    );
    expect(tooMany.validRows, hasLength(13));
    expect(tooMany.canImport, isFalse);
    expect(tooMany.errors.single, contains('no máximo 12'));
  });

  test('recusa cabeçalho incompleto e aspas não fechadas', () {
    expect(
      previewDebtCsv('nome;valor\nMaria;10').errors.single,
      contains('Colunas ausentes'),
    );
    expect(
      previewDebtCsv('nome;telefone;valor;vencimento;juros\n"Maria;')
          .errors
          .single,
      contains('aspas não fechadas'),
    );
  });
}
