import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/mmp_service.dart';
import '../services/plan_catalog.dart';
import '../services/store_ids.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/common.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(MmpService.instance.logPremiumPaywallView());
      context.read<AppController>().loadStorePrice();
    });
  }

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
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                    ),
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
                          'Mais agilidade para sua rotina',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'A caderneta essencial continua gratuita. O Premium adiciona atalhos e recursos para economizar tempo.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            color: AppColors.mutedDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const _PlanSection(
                          title: 'O que continua gratuito',
                          benefits: PlanCatalog.free,
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.success,
                        ),
                        const SizedBox(height: 22),
                        const _PlanSection(
                          title: 'O que o Premium acrescenta',
                          benefits: PlanCatalog.premium,
                          icon: Icons.auto_awesome_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            PlanCatalog.financialDisclaimer,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.mutedDark,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const _PriceCard(),
                        const SizedBox(height: 12),
                        const _RestoreButton(),
                        const SizedBox(height: 18),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            _FooterLink(
                              label: 'Termos de Uso',
                              onTap: () =>
                                  openLegalUrl(context, AppConstants.termsUrl),
                            ),
                            Text(
                              '·',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.mutedDark,
                              ),
                            ),
                            _FooterLink(
                              label: 'Política de Privacidade',
                              onTap: () => openLegalUrl(
                                context,
                                AppConstants.privacyUrl,
                              ),
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
}

Future<void> openLegalUrl(BuildContext context, String url) async {
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    showPagoSnack(context, 'Não foi possível abrir o link.');
  }
}

class _RestoreButton extends StatelessWidget {
  const _RestoreButton();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final busy = state.restoringPurchases;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: busy || state.billingBusy ? null : () => _restore(context),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.restore_rounded, size: 20),
        label: Text(
          busy ? 'Procurando sua assinatura...' : 'Restaurar Compras',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primaryMuted, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final state = context.read<AppController>();
    final message = await state.restorePremium();
    if (!context.mounted) return;
    if (message != null) {
      showPagoSnack(context, message);
      return;
    }
    if (state.user.premiumAtivo) {
      showPagoSnack(context, 'Assinatura restaurada. Premium ativo.');
      Navigator.of(context).pop();
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
                colors: [Color(0x66FFFFFF), Color(0xFFFFFFFF)],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
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
    this.iconColor = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;

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
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor),
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

class _PlanSection extends StatelessWidget {
  const _PlanSection({
    required this.title,
    required this.benefits,
    required this.icon,
    required this.color,
  });
  final String title;
  final List<PlanBenefit> benefits;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 14),
      for (final benefit in benefits)
        _Benefit(
          icon: icon,
          iconColor: color,
          title: benefit.title,
          subtitle: benefit.description,
        ),
    ],
  );
}

class _PriceCard extends StatelessWidget {
  const _PriceCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final store = state.store;
    final price = state.storePriceLabel ?? AppConstants.premiumPriceLabel;
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
          Text(
            'Pagô Premium · Assinatura mensal',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedDark,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
              children: [
                TextSpan(text: price, style: const TextStyle(fontSize: 34)),
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
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                store.cancelHint,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: state.billingBusy
                ? 'Aguardando a ${store.label}...'
                : 'Assinar Premium',
            onPressed: state.billingBusy || state.restoringPurchases
                ? null
                : () => _subscribe(context),
          ),
          if (state.billingMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              state.billingMessage!,
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
            premiumRenewalNotice(store, price),
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
