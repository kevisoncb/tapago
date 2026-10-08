import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/boleto_code.dart';
import '../utils/formatters.dart';
import '../utils/masks.dart';
import '../widgets/common.dart';
import 'add_boleto_page.dart';

class BoletosPage extends StatelessWidget {
  const BoletosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final abertos = state.boletosAbertos;
    final pagos = state.boletosPagos.take(10).toList();

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
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Novo boleto',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 108),
        children: [
          _Resumo(
            total: state.boletosAPagar,
            vencidos: state.boletosVencidos,
            vencendo: state.boletosVencendo,
          ),
          if (!state.user.notificacoesDiarias) ...[
            const SizedBox(height: 12),
            Text(
              'Os avisos estão desligados em Ajustes > Notificações.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
          const SizedBox(height: 22),
          const SectionLabel('Em aberto'),
          const SizedBox(height: 10),
          if (abertos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Nenhum boleto em aberto. Cadastre as contas da empresa e o Pagô! avisa antes de vencer.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: AppColors.mutedDark),
              ),
            )
          else
            for (final boleto in abertos) ...[
              _BoletoTile(boleto: boleto),
              const SizedBox(height: 10),
            ],
          if (pagos.isNotEmpty) ...[
            const SizedBox(height: 14),
            const SectionLabel('Pagos'),
            const SizedBox(height: 10),
            for (final boleto in pagos) ...[
              _BoletoTile(boleto: boleto),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  static void _openForm(BuildContext context, [Boleto? boleto]) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddBoletoPage(boleto: boleto)),
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({
    required this.total,
    required this.vencidos,
    required this.vencendo,
  });

  final double total;
  final int vencidos;
  final int vencendo;

  @override
  Widget build(BuildContext context) {
    final alerta = vencidos > 0
        ? '$vencidos vencido${vencidos == 1 ? '' : 's'}'
        : vencendo > 0
            ? '$vencendo vence${vencendo == 1 ? '' : 'm'} em até 3 dias'
            : 'Tudo em dia';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total a pagar',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.86),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            Money.full(total),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            alerta,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoletoTile extends StatelessWidget {
  const _BoletoTile({required this.boleto});

  final Boleto boleto;

  @override
  Widget build(BuildContext context) {
    final status = _statusOf(boleto);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showActions(context, boleto),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(status.icon, color: status.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      boleto.empresa,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      boleto.descricao.isEmpty
                          ? status.label
                          : '${status.label} · ${boleto.descricao}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: status.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Money.full(boleto.valor),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  decoration:
                      boleto.statusPago ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Status {
  const _Status(this.label, this.icon, this.color, this.background);

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
}

_Status _statusOf(Boleto boleto) {
  if (boleto.statusPago) {
    final quando = boleto.pagoEm ?? boleto.dataVencimento;
    return _Status(
      'Pago em ${Dates.due(quando)}',
      Icons.check_circle_outline_rounded,
      AppColors.premiumGreen,
      AppColors.successSoft,
    );
  }
  final dias = boleto.diasParaVencer();
  if (dias < 0) {
    return _Status(
      'Vencido há ${-dias} dia${dias == -1 ? '' : 's'}',
      Icons.error_outline_rounded,
      AppColors.danger,
      AppColors.dangerSoft,
    );
  }
  if (dias == 0) {
    return const _Status(
      'Vence hoje',
      Icons.notification_important_outlined,
      AppColors.danger,
      AppColors.dangerSoft,
    );
  }
  if (dias == 1) {
    return const _Status(
      'Vence amanhã',
      Icons.schedule_rounded,
      AppColors.primaryDark,
      AppColors.primarySoft,
    );
  }
  return _Status(
    'Vence ${Dates.due(boleto.dataVencimento)}',
    Icons.receipt_long_outlined,
    AppColors.mutedDark,
    AppColors.bg,
  );
}

Future<void> _showActions(BuildContext context, Boleto boleto) async {
  final state = context.read<AppController>();
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                boleto.empresa,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  Money.full(boleto.valor),
                  'vence ${Dates.full(boleto.dataVencimento)}',
                  if (boleto.cnpj.isNotEmpty) 'CNPJ ${formatCnpj(boleto.cnpj)}',
                ].join(' · '),
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.mutedDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (boleto.linhaDigitavel.isNotEmpty) ...[
                const SizedBox(height: 10),
                SelectableText(
                  formatBoletoCode(boleto.linhaDigitavel),
                  style: GoogleFonts.robotoMono(fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 12),
              if (boleto.linhaDigitavel.isNotEmpty)
                _SheetAction(
                  icon: Icons.copy_rounded,
                  label: 'Copiar código',
                  onTap: () => Navigator.pop(sheetContext, 'copiar'),
                ),
              _SheetAction(
                icon: boleto.statusPago
                    ? Icons.undo_rounded
                    : Icons.check_circle_outline_rounded,
                label: boleto.statusPago ? 'Voltar para em aberto' : 'Marcar como pago',
                onTap: () => Navigator.pop(sheetContext, 'pago'),
              ),
              _SheetAction(
                icon: Icons.edit_outlined,
                label: 'Editar',
                onTap: () => Navigator.pop(sheetContext, 'editar'),
              ),
              _SheetAction(
                icon: Icons.delete_outline_rounded,
                label: 'Excluir',
                color: AppColors.danger,
                onTap: () => Navigator.pop(sheetContext, 'excluir'),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (!context.mounted || action == null) return;

  try {
    switch (action) {
      case 'copiar':
        await Clipboard.setData(ClipboardData(text: boleto.linhaDigitavel));
        if (context.mounted) {
          showTapagoSnack(context, 'Código copiado. Cole no app do banco.');
        }
      case 'pago':
        await state.setBoletoPago(boleto, !boleto.statusPago);
        if (context.mounted && !boleto.statusPago) {
          showTapagoSnack(context, 'Pagô! Boleto marcado como pago.');
        }
      case 'editar':
        BoletosPage._openForm(context, boleto);
      case 'excluir':
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Excluir boleto?'),
            content: Text('${boleto.empresa} · ${Money.full(boleto.valor)}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        );
        if (ok == true) await state.deleteBoleto(boleto.id);
    }
  } catch (_) {
    if (context.mounted) {
      showTapagoSnack(context, 'Não deu para atualizar o boleto. Tente de novo.');
    }
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.text,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }
}
