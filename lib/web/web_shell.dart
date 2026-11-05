import 'package:flutter/material.dart';
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
import 'web_widgets.dart';

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

const _menuGroups = <(String, List<WebSection>)>[
  ('Operação', [
    WebSection.inicio,
    WebSection.venda,
    WebSection.clientes,
    WebSection.boletos,
  ]),
  ('Gestão', [WebSection.relatorios]),
  ('Conta', [WebSection.premium, WebSection.conta]),
];

/// Painel do sistema na web: menu lateral, barra superior com busca e ações, e a
/// área de trabalho. Usa os mesmos dados do aplicativo, sem a moldura de
/// celular. Em janelas menores o menu mostra só os ícones.
class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  static const _fullMenuWidth = 1100.0;

  final _search = TextEditingController();
  var _section = WebSection.inicio;
  var _clientQuery = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _go(WebSection section) => setState(() {
    _section = section;
    _clientQuery = '';
    _search.clear();
  });

  void _findClient(String query) => setState(() {
    _section = WebSection.clientes;
    _clientQuery = query.trim();
  });

  Widget _content() {
    return switch (_section) {
      WebSection.inicio => WebHome(onGo: _go),
      WebSection.venda => WebSale(onDone: () => _go(WebSection.clientes)),
      WebSection.clientes => WebClients(
        key: ValueKey(_clientQuery),
        initialQuery: _clientQuery,
      ),
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
    final store = state.user.nomeLoja.trim();
    return Scaffold(
      backgroundColor: WebColors.canvas,
      body: Row(
        children: [
          _Sidebar(
            compact: MediaQuery.sizeOf(context).width < _fullMenuWidth,
            current: _section,
            onSelect: _go,
            premium: state.user.premiumAtivo,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  search: _search,
                  onSearch: _findClient,
                  onNew: () => _go(WebSection.venda),
                  onSelect: _go,
                  name: store.isNotEmpty ? store : state.user.nome,
                  email: state.user.email,
                  premium: state.user.premiumAtivo,
                  onSignOut: () => state.signOut(),
                ),
                Expanded(
                  child: state.loading && state.debts.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _content(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.search,
    required this.onSearch,
    required this.onNew,
    required this.onSelect,
    required this.name,
    required this.email,
    required this.premium,
    required this.onSignOut,
  });

  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final VoidCallback onNew;
  final ValueChanged<WebSection> onSelect;
  final String name;
  final String email;
  final bool premium;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: WebColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: WebSearchField(
                controller: search,
                hint: 'Buscar cliente e apertar Enter',
                onSubmitted: onSearch,
                maxWidth: 360,
              ),
            ),
          ),
          const SizedBox(width: 16),
          WebPrimaryButton(
            label: 'Novo lançamento',
            icon: Icons.add_rounded,
            onPressed: onNew,
          ),
          const SizedBox(width: 12),
          PopupMenuButton<VoidCallback>(
            tooltip: 'Conta',
            position: PopupMenuPosition.under,
            onSelected: (action) => action(),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: webText(13.5, weight: FontWeight.w800)),
                    Text(
                      email,
                      style: webText(12, weight: FontWeight.w500, color: AppColors.mutedDark),
                    ),
                    const SizedBox(height: 4),
                    WebBadge(
                      premium ? 'Premium' : 'Plano grátis',
                      color: premium ? AppColors.success : AppColors.mutedDark,
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: () => onSelect(WebSection.conta),
                child: const Text(WebAccountLabels.account),
              ),
              PopupMenuItem(
                value: () => onSelect(WebSection.ajuda),
                child: const Text(WebAccountLabels.help),
              ),
              PopupMenuItem(
                value: onSignOut,
                child: const Text(WebAccountLabels.signOut),
              ),
            ],
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                initial,
                style: webText(14, weight: FontWeight.w800, color: AppColors.primaryDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Textos do menu da conta, na barra superior.
class WebAccountLabels {
  static const account = 'Minha conta';
  static const help = 'Ajuda';
  static const signOut = 'Sair da conta';
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.compact,
    required this.current,
    required this.onSelect,
    required this.premium,
  });

  final bool compact;
  final bool premium;
  final WebSection current;
  final ValueChanged<WebSection> onSelect;

  Widget _item(WebSection section) => _SidebarItem(
    compact: compact,
    section: section,
    selected: section == current,
    onTap: () => onSelect(section),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 68 : 228,
      color: WebColors.sidebar,
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: Column(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 60,
            child: Align(
              alignment: compact ? Alignment.center : Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: compact ? 0 : 8),
                child: Text(
                  AppConstants.appName,
                  style: webText(
                    compact ? 17 : 22,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  for (final (title, sections) in _menuGroups) ...[
                    if (compact)
                      const SizedBox(height: 10)
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                        child: Text(
                          title.toUpperCase(),
                          style: webText(
                            11,
                            weight: FontWeight.w700,
                            color: WebColors.sidebarMuted,
                          ),
                        ),
                      ),
                    for (final section in sections)
                      if (section != WebSection.premium || !premium)
                        _item(section),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 17, color: WebColors.sidebarLine),
          _item(WebSection.ajuda),
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
    final color = selected ? Colors.white : WebColors.sidebarText;
    final icon = Icon(
      selected ? section.selectedIcon : section.icon,
      size: 20,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white10,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          style: webText(
                            13.5,
                            weight: selected ? FontWeight.w700 : FontWeight.w600,
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
