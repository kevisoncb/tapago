import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Cores só do painel web: fundo neutro e menu escuro, como um sistema de gestão.
class WebColors {
  static const canvas = Color(0xFFF3F5F9);
  static const border = Color(0xFFE2E7EF);
  static const headerBand = Color(0xFFF7F9FC);
  static const sidebar = Color(0xFF0F2350);
  static const sidebarText = Color(0xFFB9C6E3);
  static const sidebarMuted = Color(0xFF7F90B6);
  static const sidebarLine = Color(0xFF243A6E);
}

TextStyle webText(
  double size, {
  FontWeight weight = FontWeight.w600,
  Color color = AppColors.text,
}) => GoogleFonts.plusJakartaSans(
  fontSize: size,
  fontWeight: weight,
  color: color,
);

/// Moldura padrão das páginas do painel: título, ação opcional e conteúdo
/// rolável com largura máxima confortável.
class WebPage extends StatelessWidget {
  const WebPage({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    required this.child,
    this.maxWidth = 1280,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: webText(21, weight: FontWeight.w800),
                        ),
                        if (subtitle case final text?)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              text,
                              style: webText(
                                13.5,
                                weight: FontWeight.w500,
                                color: AppColors.mutedDark,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?action,
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Painel por cima da tela para cadastros e detalhes. As telas abertas a partir
/// dele ficam dentro do próprio painel, sem ocupar a janela inteira.
Future<void> openWebPanel(BuildContext context, Widget child) {
  return showDialog<void>(
    context: context,
    builder: (dialog) => Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 860),
        child: Navigator(
          observers: [_ClosePanelOnLastPop(dialog)],
          onGenerateInitialRoutes: (_, _) => [
            PageRouteBuilder<void>(
              settings: const RouteSettings(name: _panelBase),
              pageBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            MaterialPageRoute<void>(builder: (_) => child),
          ],
        ),
      ),
    ),
  );
}

const _panelBase = 'painel-base';

/// A primeira tela do painel tem por baixo uma rota vazia, para o botão de
/// voltar funcionar; ao chegar nela, quem fecha é o diálogo.
class _ClosePanelOnLastPop extends NavigatorObserver {
  _ClosePanelOnLastPop(this.dialog);

  final BuildContext dialog;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute?.settings.name != _panelBase) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dialog.mounted) Navigator.of(dialog).pop();
    });
  }
}

class WebPrimaryButton extends StatelessWidget {
  const WebPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: webText(13.5, weight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class WebSearchField extends StatelessWidget {
  const WebSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.maxWidth = 320,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: WebColors.border),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: webText(13.5, weight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: webText(
            13.5,
            weight: FontWeight.w500,
            color: AppColors.muted,
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          filled: true,
          fillColor: Colors.white,
          border: border,
          enabledBorder: border,
        ),
      ),
    );
  }
}

/// Grade que escolhe o número de colunas pela largura disponível.
class WebGrid extends StatelessWidget {
  const WebGrid({
    super.key,
    required this.children,
    this.minItemWidth = 200,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;

  static const _gap = 14.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final fit = ((box.maxWidth + _gap) / (minItemWidth + _gap)).floor();
        var cols = fit.clamp(1, maxColumns);
        // Evita um cartão sozinho na última linha (3 + 1 vira 2 + 2).
        if (cols > 2 && children.length % cols == 1) cols--;
        final width = (box.maxWidth - _gap * (cols - 1)) / cols;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class WebCard extends StatelessWidget {
  const WebCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: WebColors.border),
      ),
      // Linhas clicáveis e listas dentro do cartão precisam de um Material.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// Cartão com barra de título, usado em volta das tabelas.
class WebTablePanel extends StatelessWidget {
  const WebTablePanel({
    super.key,
    required this.title,
    this.trailing,
    required this.child,
    this.titleColor = AppColors.text,
    this.titleIcon,
  });

  final String title;
  final Color titleColor;
  final IconData? titleIcon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return WebCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            child: Row(
              children: [
                if (titleIcon != null) ...[
                  Icon(titleIcon, size: 18, color: titleColor),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: webText(
                      14.5,
                      weight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Faixa de títulos das colunas de uma tabela.
class WebTableHeader extends StatelessWidget {
  const WebTableHeader({super.key, required this.children});

  final List<Widget> children;

  static TextStyle get style =>
      webText(11.5, weight: FontWeight.w700, color: AppColors.mutedDark);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: const BoxDecoration(
        color: WebColors.headerBand,
        border: Border(
          top: BorderSide(color: WebColors.border),
          bottom: BorderSide(color: WebColors.border),
        ),
      ),
      child: Row(children: children),
    );
  }
}

/// Linha de tabela com altura uniforme e destaque ao passar o mouse.
class WebTableRow extends StatelessWidget {
  const WebTableRow({
    super.key,
    required this.children,
    this.onTap,
    this.accent,
  });

  final List<Widget> children;
  final VoidCallback? onTap;

  /// Faixa colorida à esquerda, para destacar a linha (ex.: em atraso).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: EdgeInsets.fromLTRB(accent == null ? 16 : 13, 4, 16, 4),
      decoration: BoxDecoration(
        color: accent?.withValues(alpha: 0.04),
        border: Border(
          bottom: const BorderSide(color: WebColors.canvas),
          left: accent == null
              ? BorderSide.none
              : BorderSide(color: accent!, width: 3),
        ),
      ),
      child: Row(children: children),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, hoverColor: WebColors.headerBand, child: row);
  }
}

/// Texto vazio de tabela ou lista.
class WebEmpty extends StatelessWidget {
  const WebEmpty(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Text(
        text,
        style: webText(
          13.5,
          weight: FontWeight.w500,
          color: AppColors.mutedDark,
        ),
      ),
    );
  }
}

/// Situação em destaque na tabela (em atraso, pago, a vencer).
class WebBadge extends StatelessWidget {
  const WebBadge(this.label, {super.key, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: webText(12, weight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}

class WebStat extends StatelessWidget {
  const WebStat({
    super.key,
    required this.label,
    required this.value,
    this.color = AppColors.text,
    this.icon,
    this.detail,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = WebCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: webText(12.5, color: AppColors.mutedDark),
                ),
              ),
              if (icon case final data?)
                Icon(data, size: 18, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: webText(21, weight: FontWeight.w800, color: color),
            ),
          ),
          if (detail case final text?)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: webText(
                  12.5,
                  weight: FontWeight.w500,
                  color: AppColors.mutedDark,
                ),
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: card,
    );
  }
}
