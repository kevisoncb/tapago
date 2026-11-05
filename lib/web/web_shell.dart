import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import 'web_account.dart';
import 'web_bills.dart';
import 'web_clients.dart';
import 'web_help.dart';
import 'web_home.dart';
import 'web_premium.dart';
import 'web_reports.dart';
import 'web_sale.dart';

enum WebSection {
  inicio('Início', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  venda('Lançamento', Icons.post_add_outlined, Icons.post_add_rounded),
  clientes('Clientes', Icons.people_outline_rounded, Icons.people_rounded),
  boletos('Boletos', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  relatorios('Relatórios', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
  premium('Premium', Icons.workspace_premium_outlined, Icons.workspace_premium_rounded),
  conta('Minha conta', Icons.settings_outlined, Icons.settings_rounded),
  ajuda('Ajuda', Icons.help_outline_rounded, Icons.help_rounded);

  const WebSection(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Painel do sistema na web: menu lateral à esquerda e a área de trabalho à
/// direita. Usa os mesmos dados do aplicativo, sem a moldura de celular. Em
/// janelas menores o menu mostra só os ícones.
class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  static const _fullMenuWidth = 1100.0;

  var _section = WebSection.inicio;

  void _go(WebSection section) => setState(() => _section = section);

  Widget _content() {
    return switch (_section) {
      WebSection.inicio => WebHome(onGo: _go),
      WebSection.venda => WebSale(onDone: () => _go(WebSection.clientes)),
      WebSection.clientes => WebClients(onNewSale: () => _go(WebSection.venda)),
      WebSection.boletos => WebBills(onPremium: () => _go(WebSection.premium)),
      WebSection.relatorios => const WebReports(),
      WebSection.premium => const WebPremium(),
      WebSection.conta => const WebAccount(),
      WebSection.ajuda => WebHelp(onGo: _go),
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
            compact: MediaQuery.sizeOf(context).width < _fullMenuWidth,
            current: _section,
            onSelect: _go,
            storeName: state.user.nomeLoja.trim().isNotEmpty
                ? state.user.nomeLoja.trim()
                : state.user.nome,
            premium: state.user.premiumAtivo,
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
    required this.compact,
    required this.current,
    required this.onSelect,
    required this.storeName,
    required this.premium,
    required this.onSignOut,
  });

  final bool compact;
  final bool premium;
  final WebSection current;
  final ValueChanged<WebSection> onSelect;
  final String storeName;
  final VoidCallback onSignOut;

  Widget _item(WebSection section) => _SidebarItem(
    compact: compact,
    section: section,
    selected: section == current,
    onTap: () => onSelect(section),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 76 : 244,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 22, compact ? 10 : 14, 16),
      child: Column(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 0 : 10,
              0,
              compact ? 0 : 10,
              compact ? 22 : 0,
            ),
            child: Text(
              AppConstants.appName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: compact ? 18 : 28,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          if (!compact)
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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final section in WebSection.values)
                    if (section != WebSection.ajuda &&
                        (section != WebSection.premium || !premium))
                      _item(section),
                ],
              ),
            ),
          ),
          const Divider(height: 17, color: AppColors.primaryMuted),
          _item(WebSection.ajuda),
          if (compact)
            IconButton(
              tooltip: 'Sair da conta',
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded, size: 22),
              color: AppColors.mutedDark,
            )
          else
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
    required this.compact,
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final bool compact;
  final WebSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryDark : AppColors.mutedDark;
    final icon = Icon(
      selected ? section.selectedIcon : section.icon,
      size: 22,
      color: color,
    );
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
            child: compact
                ? Tooltip(message: section.label, child: icon)
                : Row(
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          section.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                            color: color,
                          ),
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
