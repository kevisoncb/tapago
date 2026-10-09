import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../screens/add_debt_page.dart';
import '../screens/bills_page.dart';
import '../screens/caderneta_page.dart';
import '../screens/premium_page.dart';
import '../screens/settings_page.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

Future<void> showPagoMenu(BuildContext context) async {
  final state = context.read<AppController>();
  final user = state.user;
  final premium = user.premiumAtivo;
  final clientes = state.pendingDebts.length;
  final boletos = state.pendingBills.length;

  final Widget? destino = await showModalBottomSheet<Widget>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheet) {
      Widget item({
        required IconData icon,
        required String title,
        required String subtitle,
        required Widget page,
        bool locked = false,
      }) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          title: Text(
            title,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.mutedDark,
            ),
          ),
          trailing: Icon(
            locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
            color: AppColors.muted,
          ),
          onTap: () => Navigator.pop(sheet, locked ? const PremiumPage() : page),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    initialsOf(user.nome),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                title: Text(
                  user.nome,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  premium ? 'Plano Premium' : 'Plano grátis',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: premium ? AppColors.premiumGreen : AppColors.mutedDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Divider(height: 16),
              item(
                icon: Icons.menu_book_rounded,
                title: 'Caderneta',
                subtitle: 'Clientes e empresas com as pendências',
                page: const CadernetaPage(),
              ),
              item(
                icon: Icons.search_rounded,
                title: 'Buscar',
                subtitle: 'Pessoa, empresa ou telefone',
                page: const CadernetaPage(focusSearch: true),
              ),
              item(
                icon: Icons.receipt_long_rounded,
                title: 'Boletos a pagar',
                subtitle: !premium
                    ? 'Premium'
                    : boletos == 0
                        ? 'Nenhum em aberto'
                        : '$boletos em aberto',
                page: const BillsPage(),
                locked: !premium,
              ),
              item(
                icon: Icons.add_rounded,
                title: 'Novo lançamento',
                subtitle: clientes == 0
                    ? 'Fiado, venda a prazo ou empréstimo'
                    : '$clientes ${clientes == 1 ? 'pendência' : 'pendências'} de clientes',
                page: const AddDebtPage(),
              ),
              if (!premium)
                item(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Premium',
                  subtitle: 'Voz, recibos e boletos a pagar',
                  page: const PremiumPage(),
                ),
              const Divider(height: 16),
              item(
                icon: Icons.settings_outlined,
                title: 'Configurações',
                subtitle: 'Conta, PIX, notificações e ajuda',
                page: const SettingsPage(),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (destino == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => destino));
}
