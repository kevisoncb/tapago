import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/common.dart';

class PremiumPage extends StatelessWidget {
  const PremiumPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.white,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: const Text('Premium'),
                ),
                const SliverToBoxAdapter(child: _Hero()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      children: [
                        Text(
                          'Desbloqueie o Poder Total',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Apenas ${AppConstants.premiumPriceLabel}/mês para voz, recibos, cobrança no seu texto e boletos a pagar',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            color: AppColors.mutedDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const _Benefit(
                          icon: Icons.mic_none_rounded,
                          title: 'Cadastro por voz',
                          subtitle:
                              'Segura o microfone e dita nome, valor e vencimento. A IA monta o lançamento.',
                        ),
                        const _Benefit(
                          icon: Icons.document_scanner_outlined,
                          title: 'Leitura de recibos',
                          subtitle:
                              'Na caderneta do cliente, anexe o comprovante. A IA lê o valor e abate o saldo.',
                        ),
                        const _Benefit(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Cobrança no seu texto',
                          subtitle:
                              'A mensagem do WhatsApp sai com as suas palavras, não um texto genérico.',
                        ),
                        const _Benefit(
                          icon: Icons.receipt_long_rounded,
                          title: 'Boletos a pagar',
                          subtitle:
                              'Boleto do fornecedor à vista ou em 15/30/45, 30/60/90. Código para copiar e aviso antes de vencer.',
                        ),
                        const SizedBox(height: 8),
                        const _PriceCard(),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _FooterLink(
                              label: 'Termos de Uso',
                              onTap: () => _open(context, AppConstants.termsUrl),
                            ),
                            _FooterLink(
                              label: 'Privacidade',
                              onTap: () =>
                                  _open(context, AppConstants.privacyUrl),
                            ),
                            _FooterLink(
                              label: 'Restaurar',
                              onTap: () async {
                                final message = await context
                                    .read<AppController>()
                                    .restorePremium();
                                if (!context.mounted) return;
                                if (message != null) {
                                  showPagoSnack(context, message);
                                  return;
                                }
                                if (context.read<AppController>().user.premiumAtivo) {
                                  showPagoSnack(context, 'Assinatura restaurada.');
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showPagoSnack(context, 'Não foi possível abrir o link.');
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/water_splash.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF9ED8FF), Color(0xFFEAF4FF), Colors.white],
                ),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66FFFFFF),
                  Color(0xFFFFFFFF),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'PREMIUM',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.mutedDark,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD7E6FF), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
              children: [
                TextSpan(
                  text: AppConstants.premiumPriceLabel,
                  style: const TextStyle(fontSize: 34),
                ),
                TextSpan(
                  text: '/mês',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Text(
                'Cancele quando quiser na Google Play',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: context.watch<AppController>().billingBusy
                ? 'Aguardando a Google Play...'
                : 'Assinar Premium',
            onPressed: context.watch<AppController>().billingBusy
                ? null
                : () => _subscribe(context),
          ),
          if (context.watch<AppController>().billingMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              context.watch<AppController>().billingMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Assinatura mensal pela Google Play, com o pagamento que já está na sua conta Google. Renova sozinha até você cancelar.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: AppColors.mutedDark,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _subscribe(BuildContext context) async {
    final message = await context.read<AppController>().subscribePremium();
    if (!context.mounted) return;
    if (message != null) {
      showPagoSnack(context, message);
      return;
    }
    final state = context.read<AppController>();
    if (state.user.premiumAtivo) {
      showPagoSnack(context, 'Premium ativado.');
      Navigator.of(context).pop();
    }
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600,
          color: AppColors.mutedDark,
        ),
      ),
    );
  }
}
