import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/client_match.dart';
import '../services/export_share.dart';
import '../services/product_report.dart';
import '../services/product_report_export.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'premium_page.dart';

/// Itens de produto de um cliente, mês a mês: por data ou por produto, com o
/// total devido e exportação em imagem (JPG) ou PDF.
class ProductItemsPage extends StatefulWidget {
  const ProductItemsPage({super.key, required this.contactKey});

  final String contactKey;

  @override
  State<ProductItemsPage> createState() => _ProductItemsPageState();
}

class _ProductItemsPageState extends State<ProductItemsPage> {
  DateTime? _month;
  ProductReportMode _mode = ProductReportMode.byDate;
  bool _exporting = false;

  ProductReportSheet _sheet(
    AppController state,
    CadernetaContact contact,
    ProductReport report,
  ) {
    var gross = 0.0, open = 0.0;
    for (final debt in report.debts) {
      gross += debt.valorAtualizado;
      open += InstallmentSafe.openOf(state, debt);
    }
    final merchant = state.user.nomeLoja.trim().isNotEmpty
        ? state.user.nomeLoja.trim()
        : state.user.nome;
    return ProductReportSheet(
      merchant: merchant,
      client: contact.nome,
      report: report,
      mode: _mode,
      generatedAt: DateTime.now(),
      paid: (gross - open).clamp(0, double.infinity).toDouble(),
      due: open,
    );
  }

  Future<void> _export(ProductReportSheet sheet, {required bool pdf}) async {
    if (_exporting) return;
    final state = context.read<AppController>();
    if (!state.user.premiumAtivo) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PremiumPage()));
      return;
    }
    setState(() => _exporting = true);
    try {
      final bytes = pdf
          ? await productReportPdf(sheet)
          : await productReportJpg(sheet);
      if (!mounted) return;
      final stamp = sheet.generatedAt.toIso8601String().substring(0, 10);
      await shareExport(
        context,
        bytes: bytes,
        filename: 'pago-itens-$stamp.${pdf ? 'pdf' : 'jpg'}',
        mimeType: pdf ? 'application/pdf' : 'image/jpeg',
        subject: 'Itens de ${sheet.client} — ${monthLabel(sheet.report.month)}',
      );
    } catch (_) {
      if (mounted) {
        showPagoSnack(
          context,
          'Não foi possível preparar o arquivo. Seus registros foram preservados. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final contact = groupContacts(
      state.debts,
    ).where((item) => item.key == widget.contactKey).firstOrNull;
    if (contact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Itens do cliente')),
        body: const Center(child: Text('Este contato não está mais na caderneta.')),
      );
    }
    final months = monthsWithItems(contact.debts);
    final month =
        _month ?? (months.isNotEmpty ? months.first : DateTime.now());
    final report = buildProductReport(debts: contact.debts, month: month);
    final index = months.indexWhere(
      (m) => m.year == month.year && m.month == month.month,
    );
    final sheet = _sheet(state, contact, report);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Itens · ${contact.nome}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mês anterior',
                onPressed: index >= 0 && index < months.length - 1
                    ? () => setState(() => _month = months[index + 1])
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  monthLabel(month),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Próximo mês',
                onPressed: index > 0
                    ? () => setState(() => _month = months[index - 1])
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Por data'),
                selected: _mode == ProductReportMode.byDate,
                onSelected: (_) =>
                    setState(() => _mode = ProductReportMode.byDate),
              ),
              ChoiceChip(
                label: const Text('Por produto'),
                selected: _mode == ProductReportMode.byProduct,
                onSelected: (_) =>
                    setState(() => _mode = ProductReportMode.byProduct),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (report.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Nenhum item lançado neste mês.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: AppColors.mutedDark),
              ),
            )
          else ...[
            if (_mode == ProductReportMode.byDate)
              for (final day in report.byDay()) ...[
                Text(
                  dayLabel(day.day),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                for (final item in day.itens)
                  _ItemRow(
                    lead: hourLabel(item.em),
                    title: '${quantityLabel(item.quantidade)} × ${item.nome}',
                    value: Money.full(item.total),
                  ),
                const SizedBox(height: 12),
              ]
            else
              for (final line in report.byProduct())
                _ItemRow(
                  title: line.nome,
                  subtitle: '${quantityLabel(line.quantidade)} un.',
                  value: Money.full(line.total),
                ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _TotalLine('Total em itens', Money.full(report.total)),
                  const SizedBox(height: 6),
                  _TotalLine(
                    'Já pago',
                    '− ${Money.full(sheet.paid)}',
                    color: AppColors.success,
                  ),
                  const Divider(height: 22),
                  _TotalLine(
                    'Valor devido',
                    Money.full(sheet.due),
                    big: true,
                    color: sheet.due > 0.009
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _exporting
                        ? null
                        : () => _export(sheet, pdf: false),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Imagem (JPG)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exporting
                        ? null
                        : () => _export(sheet, pdf: true),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF'),
                  ),
                ),
              ],
            ),
            if (!state.user.premiumAtivo)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Exportar é um recurso Premium.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.mutedDark,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Quanto ainda falta de um lançamento (zero se quitado).
class InstallmentSafe {
  static double openOf(AppController state, Debt debt) =>
      debt.statusPago ? 0 : state.saldoOf(debt).clamp(0, double.infinity);
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    this.lead,
    required this.title,
    this.subtitle,
    required this.value,
  });

  final String? lead;
  final String title;
  final String? subtitle;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        if (lead != null)
          SizedBox(
            width: 52,
            child: Text(
              lead!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: AppColors.mutedDark,
              ),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.mutedDark,
                  ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _TotalLine extends StatelessWidget {
  const _TotalLine(this.label, this.value, {this.color, this.big = false});

  final String label;
  final String value;
  final Color? color;
  final bool big;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: big ? FontWeight.w800 : FontWeight.w600,
            fontSize: big ? 16 : 14,
            color: big ? AppColors.text : AppColors.mutedDark,
          ),
        ),
      ),
      Text(
        value,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          fontSize: big ? 22 : 15,
          color: color,
        ),
      ),
    ],
  );
}
