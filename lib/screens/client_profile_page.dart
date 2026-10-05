import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/debt_balance.dart';
import '../services/receipt_amount.dart';
import '../services/receipt_reader.dart';
import '../services/whatsapp_service.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'add_debt_page.dart';
import 'premium_page.dart';

class ClientProfilePage extends StatelessWidget {
  const ClientProfilePage({super.key, required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final current =
        state.debts.where((item) => item.id == debt.id).firstOrNull ?? debt;
    final history = state.paymentsFor(current.id);
    final balance = state.balanceFor(current);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Perfil do Cliente'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AddDebtPage(debt: current)),
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: () => _delete(context, current),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SizedBox(height: 8),
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                initialsOf(current.nome),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            current.nome,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, size: 16, color: AppColors.star),
              const SizedBox(width: 4),
              Text(
                'Score de Confiança: ${current.clientScore}/100',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final filled = index < current.scoreStars;
              return Icon(
                filled ? Icons.star_rounded : Icons.star_border_rounded,
                size: 16,
                color: filled ? const Color(0xFFF5B942) : AppColors.muted,
              );
            }),
          ),
          const SizedBox(height: 20),
          _ValueCard(debt: current, balance: balance),
          const SizedBox(height: 26),
          Text(
            'Ações Rápidas WhatsApp',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _WhatsAppAction(
                  icon: Icons.alarm_rounded,
                  label: 'Lembrete\nPreventivo',
                  onTap: () => _openWhatsApp(
                    context,
                    current,
                    WhatsAppAction.preventivo,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WhatsAppAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Cobrar Hoje',
                  onTap: () => _openWhatsApp(
                    context,
                    current,
                    WhatsAppAction.cobrarHoje,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WhatsAppAction(
                  icon: Icons.error_outline_rounded,
                  label: 'Cobrança de\nAtraso',
                  tint: const Color(0xFFFFF1F2),
                  iconColor: AppColors.danger,
                  onTap: () => _openWhatsApp(
                    context,
                    current,
                    WhatsAppAction.atraso,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _OcrButton(debt: current),
          if (!current.statusPago) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.read<AppController>().markPaid(current),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFFBBF7D0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Marcar como pago',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 26),
          Row(
            children: [
              Text(
                'Histórico de Pagamentos',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _PaymentHistoryPage(
                        nome: current.nome,
                        items: history,
                      ),
                    ),
                  );
                },
                child: Text(
                  'Ver Tudo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PaymentHistory(items: history.take(3).toList()),
          if (!state.user.premiumAtivo) ...[
            const SizedBox(height: 18),
            const _MiniPremiumBanner(),
          ],
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(
    BuildContext context,
    Debt current,
    WhatsAppAction action,
  ) async {
    final controller = context.read<AppController>();
    final pix = controller.user.chavePix;
    final ok = await WhatsAppService.open(
      action: action,
      debt: current,
      chavePix: pix,
      valorAberto: controller.balanceFor(current).saldo,
    );
    if (!context.mounted) return;
    if (!ok) {
      showTapagoSnack(context, 'Não foi possível abrir o WhatsApp.');
    }
  }

  Future<void> _delete(BuildContext context, Debt current) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir débito'),
        content: Text(
          'Excluir ${current.nome} e o histórico de pagamentos desta cobrança?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<AppController>().deleteDebt(current.id);
    if (context.mounted) Navigator.pop(context);
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({required this.debt, required this.balance});

  final Debt debt;
  final DebtBalance balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF2EE0C5), Color(0xFF2F6BFF)],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Valor Atualizado',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            Money.full(balance.saldo),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              balance.pago > 0
                  ? 'Juros de ${debt.taxaJuros.toStringAsFixed(0)}% sobre o restante · pago ${Money.full(balance.pago)}'
                  : 'Juros de ${debt.taxaJuros.toStringAsFixed(0)}% sobre o restante',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppAction extends StatelessWidget {
  const _WhatsAppAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint = AppColors.primarySoft,
    this.iconColor = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF0F3F8)),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OcrButton extends StatelessWidget {
  const _OcrButton({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => _pick(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: Color(0xFFE6EAF0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.document_scanner_outlined, size: 20),
          const SizedBox(width: 8),
          Text(
            'Anexar Comprovante (OCR)',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (file == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    String? text;
    try {
      text = await readReceiptText(file.path);
    } catch (_) {
      text = null;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (text == null || text.isEmpty) {
      showTapagoSnack(
        context,
        'Não consegui ler o comprovante. Tente uma foto mais nítida.',
      );
      return;
    }
    final amount = extractReceiptAmount(text);
    if (amount == null) {
      showTapagoSnack(context, 'Não encontrei um valor no comprovante.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valor encontrado'),
        content: Text(
          'Registrar pagamento de ${Money.full(amount)} neste débito?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final state = context.read<AppController>();
    await state.addPayment(
      Payment(
        id: state.newId(),
        debtId: debt.id,
        userId: state.user.id,
        valor: amount,
        data: DateTime.now(),
        descricao: 'Comprovante lido',
      ),
    );
    if (!context.mounted) return;
    showTapagoSnack(context, 'Pagamento de ${Money.full(amount)} registrado.');
  }
}

class _PaymentHistoryPage extends StatelessWidget {
  const _PaymentHistoryPage({required this.nome, required this.items});

  final String nome;
  final List<Payment> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(nome)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Histórico de Pagamentos',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _PaymentHistory(items: items),
        ],
      ),
    );
  }
}

class _PaymentHistory extends StatelessWidget {
  const _PaymentHistory({required this.items});

  final List<Payment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF0F3F8)),
        ),
        child: Text(
          'Nenhum pagamento registrado ainda.',
          style: GoogleFonts.plusJakartaSans(color: AppColors.mutedDark),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0F3F8)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.successSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].descricao,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          Dates.history(items[i].data),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.mutedDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Money.full(items[i].valor),
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (i != items.length - 1)
              const Divider(height: 1, color: Color(0xFFF3F5F8)),
          ],
        ],
      ),
    );
  }
}

class _MiniPremiumBanner extends StatelessWidget {
  const _MiniPremiumBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TáPago Premium',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Automatize essas cobranças com IA',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: AppColors.mutedDark,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PremiumPage()),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Assinar'),
          ),
        ],
      ),
    );
  }
}
