import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/bill_installments.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';
import 'add_bill_page.dart';
import 'premium_page.dart';

class BillsPage extends StatelessWidget {
  const BillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final premium = state.user.premiumAtivo;
    final pending = state.pendingBills;
    final paid = state.paidBills.take(20).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Boletos a pagar'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                premium ? const AddBillPage() : const PremiumPage(),
          ),
        ),
        icon: Icon(premium ? Icons.add : Icons.lock_outline_rounded),
        label: Text(
          'Novo boleto',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 108),
        children: [
          Row(
            children: [
              Expanded(
                child: _Total(
                  label: 'A pagar',
                  value: Money.compact(state.aPagarAberto),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Total(
                  label: 'Esta semana',
                  value: Money.compact(state.aPagarNaSemana),
                ),
              ),
            ],
          ),
          if (!premium) ...[
            const SizedBox(height: 16),
            const _PremiumLock(),
          ],
          const SizedBox(height: 22),
          if (pending.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Nenhum boleto em aberto. Cadastre o do fornecedor e o Pagô avisa antes de vencer.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: AppColors.mutedDark),
              ),
            )
          else
            for (final bill in pending) ...[
              BillTile(bill: bill, editable: premium),
              const SizedBox(height: 10),
            ],
          if (paid.isNotEmpty) ...[
            const SizedBox(height: 14),
            const SectionLabel('PAGOS'),
            const SizedBox(height: 10),
            for (final bill in paid) ...[
              BillTile(bill: bill, editable: premium),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.text,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumLock extends StatelessWidget {
  const _PremiumLock();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F8FF),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PremiumPage()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Boletos a pagar é Premium: parcelas 30/60/90, código para copiar e aviso antes de vencer.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BillTile extends StatelessWidget {
  const BillTile({super.key, required this.bill, required this.editable});

  final Bill bill;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final overdue = bill.isOverdue;
    final detail = [
      if (bill.parcelado) bill.parcelaLabel,
      bill.pago && bill.pagoEm != null
          ? 'Pago em ${Dates.due(bill.pagoEm!)}'
          : 'Vence em ${Dates.due(bill.dataVencimento)}',
    ].join(' · ');

    return Material(
      color: overdue ? AppColors.dangerSoft : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: editable ? () => _openActions(context) : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: overdue ? AppColors.dangerBorder : AppColors.line,
            ),
          ),
          child: Row(
            children: [
              Icon(
                bill.pago
                    ? Icons.check_circle_rounded
                    : Icons.receipt_long_rounded,
                color: bill.pago
                    ? AppColors.success
                    : overdue
                        ? AppColors.danger
                        : AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.fornecedor,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: overdue ? AppColors.danger : AppColors.mutedDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                Money.full(bill.valor),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: overdue ? AppColors.danger : AppColors.text,
                ),
              ),
              if (bill.codigo.isNotEmpty && !bill.pago) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Copiar código',
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy_rounded, size: 20),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: bill.codigo));
    if (!context.mounted) return;
    showPagoSnack(context, 'Código copiado. Cole no app do banco.');
  }

  Future<void> _openActions(BuildContext context) async {
    final state = context.read<AppController>();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                bill.fornecedor,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 8),
              if (bill.codigo.isNotEmpty && !bill.pago)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copiar código'),
                  onTap: () => Navigator.pop(sheet, 'copiar'),
                ),
              if (!bill.pago)
                ListTile(
                  leading: const Icon(Icons.qr_code_2_rounded),
                  title: Text(
                    bill.codigo.isEmpty ? 'Colar código' : 'Trocar código',
                  ),
                  onTap: () => Navigator.pop(sheet, 'codigo'),
                ),
              ListTile(
                leading: Icon(
                  bill.pago ? Icons.undo_rounded : Icons.check_circle_outline,
                ),
                title: Text(bill.pago ? 'Desmarcar pago' : 'Marcar como pago'),
                onTap: () => Navigator.pop(sheet, 'pago'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Excluir',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () => Navigator.pop(sheet, 'excluir'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || choice == null) return;

    try {
      switch (choice) {
        case 'copiar':
          await _copy(context);
        case 'codigo':
          final codigo = await _askCode(context);
          if (codigo == null) return;
          await state.addBills([bill.copyWith(codigo: codigo)]);
          if (context.mounted) showPagoSnack(context, 'Código salvo.');
        case 'pago':
          await state.setBillPaid(bill, !bill.pago);
        case 'excluir':
          await state.deleteBill(bill);
      }
    } catch (_) {
      if (context.mounted) {
        showPagoSnack(context, 'Não foi possível salvar. Confira a conexão.');
      }
    }
  }

  Future<String?> _askCode(BuildContext context) async {
    final controller = TextEditingController(text: bill.codigo);
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Código do boleto'),
        content: AppTextField(
          label: 'Linha digitável',
          hint: 'Cole aqui',
          icon: Icons.qr_code_2_rounded,
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 60,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (result == null) return null;
    final codigo = normalizeBoletoCode(result);
    if (codigo == null && context.mounted) {
      showPagoSnack(context, 'O código do boleto tem 47 ou 48 números.');
    }
    return codigo;
  }
}
