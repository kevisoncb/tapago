import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/pago_logo.dart';
import 'auth_page.dart';

/// Entrada do sistema na web (`/inicio`): painel azul com a marca (30%) e, ao
/// lado, entrar ou criar conta (70%). Em tela estreita fica só o formulário.
class InicioPage extends StatelessWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 820;
    if (!wide) return const AuthPage();
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          Expanded(flex: 3, child: _BrandPanel()),
          Expanded(
            flex: 7,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
                child: const AuthPage(showBrand: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = GoogleFonts.plusJakartaSans;
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const PagoMark(size: 64),
          ),
          const SizedBox(height: 20),
          Text(
            AppConstants.appName,
            style: text(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppConstants.tagline,
            style: text(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.lime,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Seu fiado organizado: quem deve, quanto e quando cobrar.',
            style: text(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
