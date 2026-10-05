import 'package:flutter/foundation.dart';
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
import '../utils/masks.dart';
import '../widgets/amount_keypad.dart';
import '../widgets/common.dart';
import '../widgets/whatsapp_mark.dart';
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
    final saldo = state.saldoOf(current);

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
          if (current.telefone.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              formatPhoneBr(current.telefone),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedDark,
              ),
            ),
          ],
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
          _ValueCard(debt: current, saldo: saldo, balance: state.balanceOf(current)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: current.statusPago || saldo <= 0
                  ? null
                  : () => _abater(context, current, saldo),
              icon: const Icon(Icons.remove_circle_outline_rounded),
              label: const Text('Abater valor'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: const Color(0xFFE8EEF6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _OcrButton(
            debt: current,
            isPremium: state.user.isPremium,
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const WhatsAppMark(size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enviar no WhatsApp',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Toca num botão. Abre o seu WhatsApp com a mensagem.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.mutedDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _WhatsAppAction(
                  label: 'Lembrete',
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
                  label: 'Cobrar hoje',
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
                  label: 'Atraso',
                  onTap: () => _openWhatsApp(
                    context,
                    current,
                    WhatsAppAction.atraso,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Text(
                'Histórico da caderneta',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                'Ver Tudo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PaymentHistory(items: history),
          if (!state.user.isPremium) ...[
            const SizedBox(height: 18),
            const _MiniPremiumBanner(),
          ],
        ],
      ),
    );
  }

  Future<void> _abater(BuildContext context, Debt current, double saldo) async {
    final state = context.read<AppController>();
    final balance = state.balanceOf(current);
    if (balance.saldo <= 0.009) return;

    var kind = AbateKind.parcial;
    if (current.taxaJuros > 0) {
      final chosen = await showAbateKindSheet(
        context: context,
        jurosEmAberto: balance.jurosRestantes,
        saldo: balance.saldo,
      );
      if (chosen == null || !context.mounted) return;
      kind = chosen;
    }

    final somenteJuros = kind == AbateKind.juros;
    final valor = kind == AbateKind.total
        ? balance.saldo
        : await showAmountKeypad(
            context: context,
            title: somenteJuros
                ? 'Quanto entrou de juros do mês?'
                : 'Quanto entrou agora?',
            confirmLabel: 'Abater',
            max: somenteJuros ? balance.jurosRestantes : balance.saldo,
            maxLabel: somenteJuros
                ? 'Juros do mês ${Money.full(balance.jurosRestantes)}'
                : 'Saldo ${Money.full(balance.saldo)}',
          );
    if (valor == null || !context.mounted) return;
    final error = await context.read<AppController>().abate(
          debt: current,
          valor: valor,
          somenteJuros: somenteJuros,
        );
    if (!context.mounted) return;
    final next = context.read<AppController>().balanceOf(current);
    showTapagoSnack(
      context,
      error ?? _abateSnack(kind: kind, valor: valor, next: next),
    );
  }

  String _abateSnack({
    required AbateKind kind,
    required double valor,
    required DebtBalance next,
  }) {
    if (next.quitado) {
      return kind == AbateKind.juros
          ? 'Quitada com o juros do mês.'
          : 'Quitada no valor total.';
    }
    if (kind == AbateKind.juros) {
      return '${Money.full(valor)} de juros do mês. Principal ${Money.full(next.principalRestante)}.';
    }
    if (kind == AbateKind.parcial) {
      return '${Money.full(valor)} na parte do valor. Saldo ${Money.full(next.saldo)}.';
    }
    return '${Money.full(valor)} no valor total. Saldo ${Money.full(next.saldo)}.';
  }

  Future<void> _openWhatsApp(
    BuildContext context,
    Debt current,
    WhatsAppAction action,
  ) async {
    final state = context.read<AppController>();
    final custom = state.user.mensagemCobranca.trim();
    final useCustom = state.user.isPremium && custom.isNotEmpty;

    var tone = WhatsAppTone.amigavel;
    if (!useCustom) {
      final chosen = await showModalBottomSheet<WhatsAppTone>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Como quer soar?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'A mensagem sai no seu WhatsApp. Escolha o tom.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.mutedDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFEEF2F7)),
                    ),
                    title: Text(
                      'Amigável',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: const Text(
                      'Oi, passando só para atualizar a caderneta...',
                    ),
                    onTap: () =>
                        Navigator.pop(sheetContext, WhatsAppTone.amigavel),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFEEF2F7)),
                    ),
                    title: Text(
                      'Formal',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: const Text(
                      'Olá, o saldo da caderneta vence hoje...',
                    ),
                    onTap: () =>
                        Navigator.pop(sheetContext, WhatsAppTone.formal),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (chosen == null || !context.mounted) return;
      tone = chosen;
    }

    final ok = await WhatsAppService.open(
      action: action,
      tone: tone,
      debt: current,
      saldo: state.saldoOf(current),
      chavePix: state.user.chavePix,
      customTemplate: custom,
      isPremium: state.user.isPremium,
    );
    if (!context.mounted) return;
    if (!ok) {
      showTapagoSnack(context, 'Não foi possível abrir o WhatsApp.');
    }
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({
    required this.debt,
    required this.saldo,
    required this.balance,
  });

  final Debt debt;
  final double saldo;
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
            'Saldo da caderneta',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            Money.full(saldo),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          if (debt.taxaJuros > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.trending_up_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    balance.jurosRestantes > 0.009
                        ? 'Juros em aberto ${Money.full(balance.jurosRestantes)} · ${debt.taxaJuros.toStringAsFixed(0)}%'
                        : 'Juros de ${debt.taxaJuros.toStringAsFixed(0)}% aplicados',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WhatsAppAction extends StatelessWidget {
  const _WhatsAppAction({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

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
            border: Border.all(color: const Color(0xFFE6F6EA)),
          ),
          child: Column(
            children: [
              const WhatsAppMark(size: 48),
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
  const _OcrButton({required this.debt, required this.isPremium});

  final Debt debt;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        if (!isPremium) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PremiumPage()),
          );
          return;
        }
        _pick(context);
      },
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
            isPremium ? 'Anexar comprovante' : 'Anexar comprovante · Premium',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    if (kIsWeb) {
      showTapagoSnack(
        context,
        'A leitura do comprovante funciona no celular. Abra o TáPago no Android.',
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comprovante',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'O app lê o valor na foto e pergunta se abate.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.mutedDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Tirar foto'),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_outlined),
                  title: const Text('Escolher da galeria'),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null || !context.mounted) return;

    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2000,
    );
    if (file == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? text;
    try {
      if (file.path.isNotEmpty) {
        text = await readReceiptText(file.path);
      }
      text ??= await readReceiptBytes(await file.readAsBytes());
    } catch (error) {
      debugPrint('OCR: $error');
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();

    final lido = text == null ? null : extractReceiptAmount(text);
    if (lido == null || lido <= 0) {
      showTapagoSnack(
        context,
        'Não achei o valor nesse comprovante. Tente outra foto, mais nítida.',
      );
      return;
    }

    final state = context.read<AppController>();
    final current =
        state.debts.where((item) => item.id == debt.id).firstOrNull ?? debt;
    final balance = state.balanceOf(current);
    if (balance.saldo <= 0.009) {
      showTapagoSnack(context, 'Essa caderneta já está quitada.');
      return;
    }

    var kind = AbateKind.parcial;
    if (current.taxaJuros > 0) {
      final chosen = await showAbateKindSheet(
        context: context,
        jurosEmAberto: balance.jurosRestantes,
        saldo: balance.saldo,
      );
      if (chosen == null || !context.mounted) return;
      kind = chosen;
    }

    final somenteJuros = kind == AbateKind.juros;
    final teto = somenteJuros ? balance.jurosRestantes : balance.saldo;
    if (teto <= 0.009) {
      showTapagoSnack(
        context,
        'Não há valor em aberto para esse tipo de abate.',
      );
      return;
    }

    final sugerido =
        kind == AbateKind.total ? balance.saldo : (lido > teto ? teto : lido);
    final valor = await showAmountKeypad(
      context: context,
      title: 'Valor lido no comprovante',
      confirmLabel: 'Abater',
      max: teto,
      maxLabel: somenteJuros
          ? 'Juros do mês ${Money.full(teto)}'
          : 'Saldo ${Money.full(teto)}',
      initial: sugerido,
    );
    if (valor == null || !context.mounted) return;

    final error = await state.abate(
      debt: current,
      valor: valor,
      somenteJuros: somenteJuros,
    );
    if (!context.mounted) return;
    showTapagoSnack(
      context,
      error ??
          (somenteJuros
              ? 'Comprovante: ${Money.full(valor)} de juros do mês.'
              : kind == AbateKind.total
                  ? 'Comprovante: valor total abatido.'
                  : 'Comprovante: ${Money.full(valor)} na parte do valor.'),
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
          'Nenhum abatimento ainda. Use Abater valor quando o cliente deixar alguma quantia. Com juros, o app pergunta se foi o total, uma parte ou só o juro do mês.',
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
                          paymentKindLabel(items[i].descricao),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          [
                            if (paymentKindHint(items[i].descricao).isNotEmpty)
                              paymentKindHint(items[i].descricao),
                            Dates.history(items[i].data),
                          ].join(' · '),
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
                  'Voz e leitura de recibos, quando a mão cansar',
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
