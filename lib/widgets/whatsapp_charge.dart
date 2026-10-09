import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/whatsapp_service.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import 'common.dart';

Future<void> chargeOnWhatsApp({
  required BuildContext context,
  required Debt debt,
  WhatsAppAction? action,
}) async {
  final state = context.read<AppController>();
  final custom = state.user.mensagemCobranca.trim();
  final useCustom = state.user.isPremium && custom.isNotEmpty;
  final chosenAction = action ?? whatsAppActionForDue(debt.dataVencimento);

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
                  onTap: () => Navigator.pop(sheetContext, WhatsAppTone.formal),
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
    action: chosenAction,
    tone: tone,
    debt: debt,
    saldo: state.saldoOf(debt),
    chavePix: state.user.chavePix,
    customTemplate: custom,
    isPremium: state.user.isPremium,
  );
  if (!context.mounted) return;
  if (!ok) {
    showPagoSnack(context, 'Não foi possível abrir o WhatsApp.');
  }
}
