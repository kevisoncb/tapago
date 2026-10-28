import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/formatters.dart';
import 'product_report.dart';

enum ProductReportMode { byDate, byProduct }

/// Tudo o que entra no comprovante de itens (imagem ou PDF).
class ProductReportSheet {
  const ProductReportSheet({
    required this.merchant,
    required this.client,
    required this.report,
    required this.mode,
    required this.generatedAt,
    required this.paid,
    required this.due,
  });

  final String merchant;
  final String client;
  final ProductReport report;
  final ProductReportMode mode;
  final DateTime generatedAt;

  /// Já recebido e ainda devido dos lançamentos que têm itens no mês.
  final double paid;
  final double due;

  String get generatedLabel =>
      '${dayLabel(generatedAt)} às ${hourLabel(generatedAt)}';
}

const _blue = Color(0xFF2F6BFF);
const _ink = Color(0xFF141C30);
const _muted = Color(0xFF64708A);
const _line = Color(0xFFE1E8F4);
const _soft = Color(0xFFE8F0FF);
const _red = Color(0xFFC83232);
const _green = Color(0xFF16965A);
const _disclaimer =
    'Registro informado pelo comerciante. Não é comprovante bancário.';

/// Imagem JPG (1080 px de largura) pronta para mandar no WhatsApp.
Future<Uint8List> productReportJpg(ProductReportSheet sheet) async {
  const width = 1080.0;
  final measure = ui.PictureRecorder();
  final height = _paint(Canvas(measure), sheet, width);
  measure.endRecording().dispose();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  _paint(canvas, sheet, width);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.ceil());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  final raw = img.Image.fromBytes(
    width: width.toInt(),
    height: height.ceil(),
    bytes: data!.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodeJpg(raw, quality: 92));
}

double _text(
  Canvas canvas,
  String text,
  double x,
  double y,
  double maxWidth, {
  double size = 30,
  bool bold = false,
  Color color = _ink,
  TextAlign align = TextAlign.left,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: size,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        color: color,
        height: 1.25,
      ),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout(minWidth: align == TextAlign.left ? 0 : maxWidth, maxWidth: maxWidth);
  painter.paint(canvas, Offset(x, y));
  final h = painter.height;
  painter.dispose();
  return h;
}

/// Desenha o comprovante e devolve a altura usada.
double _paint(Canvas canvas, ProductReportSheet s, double w) {
  const pad = 56.0;
  final inner = w - pad * 2;

  // Faixa azul com a logo do Pagô.
  canvas.drawRect(Rect.fromLTWH(0, 0, w, 190), Paint()..color = _blue);
  final box = RRect.fromRectAndRadius(
    const Rect.fromLTWH(pad, 52, 86, 86),
    const Radius.circular(24),
  );
  canvas.drawRRect(box, Paint()..color = const Color(0xFFFFFFFF));
  final check = Path()
    ..moveTo(pad + 22, 96)
    ..lineTo(pad + 39, 113)
    ..lineTo(pad + 66, 76);
  canvas.drawPath(
    check,
    Paint()
      ..color = _blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
  _text(canvas, 'Pagô!', pad + 110, 54, 400,
      size: 64, bold: true, color: const Color(0xFFFFFFFF));
  _text(canvas, 'Itens do cliente', 0, 76, w - pad,
      size: 30, color: const Color(0xFFDEE9FF), align: TextAlign.right);

  var y = 232.0;
  if (s.merchant.trim().isNotEmpty) {
    y += _text(canvas, s.merchant, pad, y, inner, size: 46, bold: true) + 6;
  }
  y += _text(canvas, 'Cliente: ${s.client}', pad, y, inner, size: 34) + 4;
  y += _text(canvas, 'Período: ${monthLabel(s.report.month)}', pad, y, inner,
          size: 28, color: _muted) +
      4;
  y += _text(canvas, 'Gerado em ${s.generatedLabel}', pad, y, inner,
          size: 26, color: _muted) +
      22;
  canvas.drawLine(Offset(pad, y), Offset(w - pad, y), Paint()..color = _line..strokeWidth = 2);
  y += 22;

  if (s.mode == ProductReportMode.byDate) {
    for (final day in s.report.byDay()) {
      y += _text(canvas, dayLabel(day.day), pad, y, inner,
              size: 28, bold: true, color: _blue) +
          10;
      for (final item in day.itens) {
        final left = _text(
          canvas,
          '${quantityLabel(item.quantidade)} × ${item.nome}',
          pad + 110,
          y,
          inner - 110 - 210,
          size: 30,
        );
        _text(canvas, hourLabel(item.em), pad, y + 3, 100, size: 26, color: _muted);
        _text(canvas, Money.full(item.total), pad, y, inner,
            size: 30, bold: true, align: TextAlign.right);
        y += (left < 40 ? 40 : left) + 12;
      }
      y += 14;
    }
  } else {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pad, y, inner, 52),
        const Radius.circular(14),
      ),
      Paint()..color = _soft,
    );
    _text(canvas, 'Produto', pad + 16, y + 11, 400, size: 24, bold: true, color: _muted);
    _text(canvas, 'Qtd', pad, y + 11, inner - 230, size: 24, bold: true, color: _muted, align: TextAlign.right);
    _text(canvas, 'Total', pad, y + 11, inner - 16, size: 24, bold: true, color: _muted, align: TextAlign.right);
    y += 70;
    for (final line in s.report.byProduct()) {
      final left = _text(canvas, line.nome, pad + 16, y, inner - 16 - 380,
          size: 30, bold: true);
      _text(canvas, quantityLabel(line.quantidade), pad, y, inner - 230,
          size: 30, align: TextAlign.right);
      _text(canvas, Money.full(line.total), pad, y, inner - 16,
          size: 30, bold: true, align: TextAlign.right);
      y += (left < 40 ? 40 : left) + 8;
      canvas.drawLine(Offset(pad, y), Offset(w - pad, y), Paint()..color = _line..strokeWidth = 2);
      y += 14;
    }
    y += 10;
  }

  // Totais.
  final boxTop = y + 10;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(pad, boxTop, inner, 268),
      const Radius.circular(28),
    ),
    Paint()..color = _soft,
  );
  var ty = boxTop + 30;
  _text(canvas, 'Total em itens', pad + 30, ty, 500, size: 30, color: _muted);
  _text(canvas, Money.full(s.report.total), pad, ty, inner - 30,
      size: 32, bold: true, align: TextAlign.right);
  ty += 56;
  _text(canvas, 'Já pago', pad + 30, ty, 500, size: 30, color: _muted);
  _text(canvas, '− ${Money.full(s.paid)}', pad, ty, inner - 30,
      size: 32, bold: true, color: _green, align: TextAlign.right);
  ty += 62;
  canvas.drawLine(Offset(pad + 30, ty), Offset(w - pad - 30, ty),
      Paint()..color = const Color(0xFFBECDEB)..strokeWidth = 2);
  ty += 24;
  _text(canvas, 'Valor devido', pad + 30, ty + 8, 500, size: 36, bold: true);
  _text(canvas, Money.full(s.due), pad, ty, inner - 30,
      size: 54, bold: true, color: s.due > 0.009 ? _red : _green, align: TextAlign.right);
  y = boxTop + 268 + 40;

  y += _text(canvas, _disclaimer, pad, y, inner, size: 24, color: _muted, align: TextAlign.center) + 8;
  y += _text(canvas, 'Feito com o Pagô · usepago.web.app', pad, y, inner,
          size: 24, bold: true, color: _blue, align: TextAlign.center) +
      44;
  return y;
}

Future<Uint8List> productReportPdf(ProductReportSheet s) async {
  final document = pw.Document();
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'),
  );
  final blue = PdfColor.fromHex('#2F6BFF');
  final muted = PdfColor.fromHex('#64708A');
  final soft = PdfColor.fromHex('#E8F0FF');
  final red = PdfColor.fromHex('#C83232');

  pw.Widget logo() => pw.Row(
    children: [
      pw.Container(
        width: 34,
        height: 34,
        decoration: pw.BoxDecoration(
          color: blue,
          borderRadius: pw.BorderRadius.circular(9),
        ),
        child: pw.CustomPaint(
          painter: (canvas, size) {
            canvas
              ..setStrokeColor(PdfColors.white)
              ..setLineWidth(3.4)
              ..setLineCap(PdfLineCap.round)
              ..setLineJoin(PdfLineJoin.round)
              ..moveTo(size.x * 0.26, size.y * 0.48)
              ..lineTo(size.x * 0.44, size.y * 0.32)
              ..lineTo(size.x * 0.74, size.y * 0.72)
              ..strokePath();
          },
        ),
      ),
      pw.SizedBox(width: 10),
      pw.Text(
        'Pagô!',
        style: pw.TextStyle(
          fontSize: 24,
          fontWeight: pw.FontWeight.bold,
          color: blue,
        ),
      ),
    ],
  );

  pw.Widget row(String l, String r, {bool strong = false, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                l,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: strong ? pw.FontWeight.bold : null,
                ),
              ),
            ),
            pw.Text(
              r,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );

  final body = <pw.Widget>[];
  if (s.mode == ProductReportMode.byDate) {
    for (final day in s.report.byDay()) {
      body.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 2),
          child: pw.Text(
            dayLabel(day.day),
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: blue,
            ),
          ),
        ),
      );
      for (final item in day.itens) {
        body.add(
          row(
            '${hourLabel(item.em)}   ${quantityLabel(item.quantidade)} × ${item.nome}',
            Money.full(item.total),
          ),
        );
      }
    }
  } else {
    body.add(
      pw.Container(
        color: soft,
        padding: const pw.EdgeInsets.all(6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                'Produto',
                style: pw.TextStyle(fontSize: 9, color: muted),
              ),
            ),
            pw.SizedBox(
              width: 60,
              child: pw.Text(
                'Qtd',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: 9, color: muted),
              ),
            ),
            pw.SizedBox(
              width: 90,
              child: pw.Text(
                'Total',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: 9, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
    for (final line in s.report.byProduct()) {
      body.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  line.nome,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(
                width: 60,
                child: pw.Text(
                  quantityLabel(line.quantidade),
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
              pw.SizedBox(
                width: 90,
                child: pw.Text(
                  Money.full(line.total),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      margin: const pw.EdgeInsets.all(32),
      maxPages: 200,
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          logo(),
          pw.SizedBox(height: 12),
          if (s.merchant.trim().isNotEmpty)
            pw.Text(
              s.merchant,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          pw.Text(
            'Cliente: ${s.client}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.Text(
            'Período: ${monthLabel(s.report.month)}',
            style: pw.TextStyle(fontSize: 10, color: muted),
          ),
          pw.Text(
            'Gerado em ${s.generatedLabel}',
            style: pw.TextStyle(fontSize: 9, color: muted),
          ),
          pw.SizedBox(height: 14),
        ],
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              _disclaimer,
              style: pw.TextStyle(fontSize: 8, color: muted),
            ),
          ),
          pw.Text(
            '${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
      build: (_) => [
        ...body,
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: soft,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            children: [
              row('Total em itens', Money.full(s.report.total)),
              row('Já pago', '− ${Money.full(s.paid)}'),
              pw.Divider(color: PdfColors.grey400),
              row(
                'Valor devido',
                Money.full(s.due),
                strong: true,
                color: s.due > 0.009 ? red : null,
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return document.save();
}
