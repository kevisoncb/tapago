import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/product_report.dart';
import 'package:pago_app/services/product_report_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final debt = Debt(
    id: 'a',
    userId: 'u',
    nome: 'Juca',
    telefone: '',
    valorPrincipal: 61,
    taxaJuros: 0,
    dataVencimento: DateTime(2026, 11, 5),
    statusPago: false,
    clientScore: 80,
    itens: [
      DebtItem(
        nome: 'Skol Beats 550ml',
        quantidade: 5,
        valorUnitario: 8,
        em: DateTime(2026, 10, 3, 14, 32),
      ),
      DebtItem(
        nome: 'Coxinha',
        quantidade: 3,
        valorUnitario: 7,
        em: DateTime(2026, 10, 3, 14, 40),
      ),
    ],
  );

  ProductReportSheet sheet(ProductReportMode mode) => ProductReportSheet(
    merchant: 'Bar do Zé',
    client: 'Juca',
    report: buildProductReport(debts: [debt], month: DateTime(2026, 10)),
    mode: mode,
    generatedAt: DateTime(2026, 10, 28, 21, 5),
    paid: 0,
    due: 61,
  );

  testWidgets('gera imagem JPG do comprovante nos dois modos', (tester) async {
    for (final mode in ProductReportMode.values) {
      final bytes = (await tester.runAsync(() => productReportJpg(sheet(mode))))!;
      // Assinatura de um arquivo JPEG: FF D8 FF.
      expect(bytes.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
      expect(bytes.length, greaterThan(5000));
    }
  });

  testWidgets('gera PDF do comprovante', (tester) async {
    final bytes = (await tester.runAsync(
      () => productReportPdf(sheet(ProductReportMode.byProduct)),
    ))!;
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
  });
}
