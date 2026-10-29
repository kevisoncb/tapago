import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import 'web_account.dart';
import 'web_bills.dart';
import 'web_clients.dart';
import 'web_home.dart';
import 'web_premium.dart';
import 'web_reports.dart';
import 'web_sale.dart';

enum WebSection {
  inicio('Início', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  venda('Venda', Icons.add_shopping_cart_outlined, Icons.add_shopping_cart_rounded),
  clientes('Clientes', Icons.people_outline_rounded, Icons.people_rounded),
  boletos('Boletos', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  relatorios('Relatórios', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
  premium('Premium', Icons.workspace_premium_outlined, Icons.workspace_premium_rounded),
  conta('Minha conta', Icons.settings_outlined, Icons.settings_rounded);

  const WebSection(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Painel do sistema na web: menu lateral à esquerda e a área de trabalho à
/// direita. Usa os mesmos dados do aplicativo, sem a moldura de celular.
class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  var _section = WebSection.inicio;

  void _go(WebSection section) => setState(() => _section = section);

  Widget _content() {
    return switch (_section) {
      WebSection.inicio => WebHome(onGo: _go),
      WebSection.venda => WebSale(onDone: () => _go(WebSection.clientes)),
      WebSection.clientes => WebClients(onNewSale: () => _go(WebSection.venda)),
      WebSection.boletos => const WebBills(),
      WebSection.relatorios => const WebReports(),
      WebSection.premium => const WebPremium(),
      WebSection.conta => const WebAccount(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          _Sidebar(
            current: _section,
            onSelect: _go,
            storeName: state.user.nomeLoja.trim().isNotEmpty
                ? state.user.nomeLoja.trim()
                : state.user.nome,
            onSignOut: () => state.signOut(),
          ),
          const VerticalDivider(width: 1, color: AppColors.primaryMuted),
          Expanded(
            child: state.loading && state.debts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _content(),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.current,
    required this.onSelect,
    required this.storeName,
    required this.onSignOut,
  });

  final WebSection current;
  final ValueChanged<WebSection> onSelect;
  final String storeName;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 244,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              AppConstants.appName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 22),
            child: Text(
              storeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedDark,
              ),
            ),
          ),
          for (final section in WebSection.values)
            _SidebarItem(
              section: section,
              selected: section == current,
              onTap: () => onSelect(section),
            ),
          const Spacer(),
          TextButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Sair da conta'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.mutedDark,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final WebSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryDark : AppColors.mutedDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(selected ? section.selectedIcon : section.icon,
                    size: 22, color: color),
                const SizedBox(width: 12),
                Text(
                  section.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
