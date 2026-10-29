import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

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
    this.maxWidth = 1080,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
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
                        Text(title, style: webText(28, weight: FontWeight.w800)),
                        if (subtitle case final text?)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              text,
                              style: webText(
                                14.5,
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
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
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
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryMuted),
      ),
      child: child,
    );
  }
}

class WebStat extends StatelessWidget {
  const WebStat({
    super.key,
    required this.label,
    required this.value,
    this.color = AppColors.text,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: webText(13, color: AppColors.mutedDark),
          ),
          const SizedBox(height: 6),
          Text(value, style: webText(24, weight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
