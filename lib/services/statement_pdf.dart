import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'customer_statement.dart';

Future<Uint8List> statementPdf(
  CustomerStatement statement, {
  required String merchantName,
}) async {
  final document = pw.Document();
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'),
  );
  final blue = PdfColor.fromHex('#2F6BFF');
  final muted = PdfColor.fromHex('#52616B');
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      margin: const pw.EdgeInsets.all(32),
      maxPages: 500,
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Pagô | Extrato da caderneta',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: blue,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Comerciante: $merchantName',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Cliente: ${statement.name}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (statement.phone.trim().isNotEmpty)
            pw.Text(
              'Telefone: ${statement.phone}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          pw.Text(
            'Gerado em ${_dateTime(statement.generatedAt)}',
            style: pw.TextStyle(fontSize: 9, color: muted),
          ),
          pw.SizedBox(height: 16),
        ],
      ),
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                'Registros informados pelo comerciante. Não é comprovante bancário.',
                style: pw.TextStyle(fontSize: 8, color: muted),
              ),
            ),
            pw.Text(
              '${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
      build: (_) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          color: PdfColor.fromHex('#EEF3FF'),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Vendas registradas: R\$ ${decimalCents(statement.contractedCents)}',
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Recebimentos não estornados: R\$ ${decimalCents(statement.receivedCents)}',
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Saldo atual: R\$ ${decimalCents(statement.balanceCents)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
        if (statement.legacyAdjustmentCents != 0) ...[
          pw.SizedBox(height: 12),
          pw.Text(
            'Há diferença de R\$ ${decimalCents(statement.legacyAdjustmentCents)} entre o saldo atual e a soma do histórico. Registros antigos podem ter sido quitados sem pagamentos detalhados. Essa diferença não representa um novo pagamento.',
            style: pw.TextStyle(fontSize: 9, color: muted),
          ),
        ],
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: ['Data', 'Movimento', 'Parcela', 'Valor no saldo'],
          data: [
            for (final entry in statement.entries)
              [
                _date(entry.date),
                '${entry.description}${entry.due == null ? '' : '\nVencimento: ${_date(entry.due!)}'}',
                entry.installment,
                'R\$ ${decimalCents(entry.cents)}',
              ],
          ],
          headerStyle: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: blue),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 8,
          ),
          cellAlignments: {
            0: pw.Alignment.topLeft,
            1: pw.Alignment.topLeft,
            2: pw.Alignment.topCenter,
            3: pw.Alignment.topRight,
          },
          columnWidths: {
            0: const pw.FixedColumnWidth(63),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FixedColumnWidth(38),
            3: const pw.FixedColumnWidth(82),
          },
          border: pw.TableBorder.all(
            color: PdfColor.fromHex('#E2E7EF'),
            width: 0.5,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Valores positivos aumentam o saldo. Pagamentos o reduzem e estornos desfazem o registro original. Este documento não verifica se o dinheiro foi recebido pelo banco.',
          style: pw.TextStyle(fontSize: 9, color: muted),
        ),
      ],
    ),
  );
  return document.save();
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _dateTime(DateTime date) =>
    '${_date(date)} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
