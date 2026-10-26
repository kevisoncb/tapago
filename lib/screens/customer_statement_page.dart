import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/client_match.dart';
import '../services/customer_statement.dart';
import '../services/export_share.dart';
import '../services/statement_pdf.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class CustomerStatementPage extends StatefulWidget {
  const CustomerStatementPage({super.key, required this.contactKey});

  final String contactKey;

  @override
  State<CustomerStatementPage> createState() => _CustomerStatementPageState();
}

class _CustomerStatementPageState extends State<CustomerStatementPage> {
  bool _exporting = false;

  Future<void> _export(CustomerStatement statement, {required bool pdf}) async {
    if (_exporting) return;
    final merchant = context.read<AppController>().user.nome;
    setState(() => _exporting = true);
    try {
      final bytes = pdf
          ? await statementPdf(statement, merchantName: merchant)
          : Uint8List.fromList(utf8.encode(statementCsv(statement)));
      if (!mounted) return;
      await shareExport(
        context,
        bytes: bytes,
        filename:
            'pago-extrato-${statement.generatedAt.toIso8601String().substring(0, 10)}.${pdf ? 'pdf' : 'csv'}',
        mimeType: pdf ? 'application/pdf' : 'text/csv',
        subject: 'Extrato da caderneta — ${statement.name}',
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
    final debts = state.debts
        .where((debt) => contactKeyOf(debt) == widget.contactKey)
        .toList();
    if (debts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Extrato do cliente')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Este cliente não está mais na caderneta.'),
          ),
        ),
      );
    }
    final contact = groupContacts(debts).first;
    final statement = CustomerStatement.build(
      name: contact.nome,
      phone: contact.telefone,
      debts: debts,
      payments: state.payments,
    );
    final payments = {
      for (final payment in statement.payments)
        'payment_${payment.id}': payment,
    };
    final entries = statement.entries.reversed.toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Extrato do cliente')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            statement.name,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (statement.phone.isNotEmpty)
            Text(
              statement.phone,
              style: const TextStyle(color: AppColors.mutedDark),
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saldo a receber'),
                Text(
                  Money.full(statement.balanceCents / 100),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                _TotalLine(
                  label: 'Vendas registradas',
                  cents: statement.contractedCents,
                ),
                const SizedBox(height: 6),
                _TotalLine(
                  label: 'Recebimentos não estornados',
                  cents: statement.receivedCents,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Este extrato mostra registros informados por você. Não comprova movimentação bancária.',
            style: TextStyle(fontSize: 12, color: AppColors.mutedDark),
          ),
          if (statement.legacyAdjustmentCents != 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Há diferença de ${Money.full(statement.legacyAdjustmentCents / 100)} entre o histórico e o saldo atual. Lançamentos antigos podem ter sido quitados sem pagamentos detalhados. Isso não registra um novo recebimento.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _exporting
                    ? null
                    : () => _export(statement, pdf: true),
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Compartilhar PDF'),
              ),
              OutlinedButton.icon(
                onPressed: _exporting
                    ? null
                    : () => _export(statement, pdf: false),
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Exportar CSV'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Confira o destinatário antes de compartilhar: o arquivo contém dados do cliente e valores.',
            style: TextStyle(fontSize: 11, color: AppColors.mutedDark),
          ),
          const SizedBox(height: 26),
          const SectionLabel('LINHA DO TEMPO'),
          const SizedBox(height: 12),
          for (final entry in entries)
            _StatementRow(
              entry: entry,
              payment: payments[entry.id],
              onReverse: payments[entry.id]?.estornado == false
                  ? () => confirmPaymentReversal(context, payments[entry.id]!)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.label, required this.cents});
  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: 12,
    children: [
      Text(label, style: const TextStyle(fontSize: 12)),
      Text(
        Money.full(cents / 100),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({required this.entry, this.payment, this.onReverse});
  final StatementEntry entry;
  final Payment? payment;
  final VoidCallback? onReverse;

  @override
  Widget build(BuildContext context) {
    final isPayment = entry.kind == StatementEntryKind.payment;
    final color = entry.kind == StatementEntryKind.reversal
        ? AppColors.mutedDark
        : isPayment
        ? AppColors.success
        : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE6ECF4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                entry.kind == StatementEntryKind.reversal
                    ? Icons.undo_rounded
                    : isPayment
                    ? Icons.check_circle_outline
                    : Icons.receipt_long_outlined,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${entry.kind.label}${entry.installment.isEmpty ? '' : ' · parcela ${entry.installment}'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${entry.cents < 0 ? '−' : '+'} ${Money.full(entry.cents.abs() / 100)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          Text(
            Dates.history(entry.date),
            style: const TextStyle(fontSize: 12, color: AppColors.mutedDark),
          ),
          Text(entry.description, style: const TextStyle(fontSize: 12)),
          if (entry.due != null)
            Text(
              'Vencimento: ${Dates.full(entry.due!)}',
              style: const TextStyle(fontSize: 12, color: AppColors.mutedDark),
            ),
          if (payment?.estornado == true)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Este pagamento foi estornado; não reduz o saldo atual.',
                style: TextStyle(fontSize: 12, color: AppColors.mutedDark),
              ),
            ),
          if (onReverse != null)
            TextButton.icon(
              onPressed: onReverse,
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('Estornar registro'),
            ),
        ],
      ),
    );
  }
}

Future<void> confirmPaymentReversal(
  BuildContext context,
  Payment payment,
) async {
  final controller = context.read<AppController>();
  final done = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ReversalDialog(payment: payment, controller: controller),
  );
  if (done == true && context.mounted) {
    showPagoSnack(context, 'Registro estornado. O histórico foi preservado.');
  }
}

class _ReversalDialog extends StatefulWidget {
  const _ReversalDialog({required this.payment, required this.controller});
  final Payment payment;
  final AppController controller;

  @override
  State<_ReversalDialog> createState() => _ReversalDialogState();
}

class _ReversalDialogState extends State<_ReversalDialog> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy) return;
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Informe o motivo do estorno.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await widget.controller.reversePayment(
        widget.payment,
        reason: reason,
      );
      if (!mounted) return;
      if (message != null) {
        setState(() {
          _busy = false;
          _error = message;
        });
        return;
      }
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'Não foi possível estornar. Confira a conexão e tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Estornar pagamento?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O registro de ${Money.full(widget.payment.valor)} deixará de reduzir o saldo. O histórico será preservado. Isso não devolve dinheiro nem cancela uma transferência bancária.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              enabled: !_busy,
              maxLength: 200,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Motivo da correção',
                hintText: 'Ex.: valor registrado em duplicidade',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _confirm,
          child: Text(_busy ? 'Estornando…' : 'Confirmar estorno'),
        ),
      ],
    ),
  );
}
