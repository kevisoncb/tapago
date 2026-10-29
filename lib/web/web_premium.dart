import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/plan_catalog.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'web_widgets.dart';

const _playUrl = 'https://play.google.com/store/apps/details?id=app.usepago';

/// Plano grátis e Premium lado a lado. A assinatura é feita pela loja do
/// celular (Google Play); aqui o painel mostra o que cada plano inclui e o
/// estado atual da conta.
class WebPremium extends StatelessWidget {
  const WebPremium({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppController>().user;
    final active = user.premiumAtivo;
    return WebPage(
      title: 'Premium',
      subtitle: 'A caderneta continua grátis. O Premium acrescenta as ferramentas de quem vende a prazo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebCard(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Icon(
                  active ? Icons.verified_rounded : Icons.workspace_premium_outlined,
                  color: active ? AppColors.success : AppColors.primary,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active ? 'Seu Premium está ativo.' : 'Você está no plano grátis.',
                        style: webText(18, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        active
                            ? (user.premiumVenceEm == null
                                ? 'Assinatura em dia.'
                                : 'Válido até ${Dates.full(user.premiumVenceEm!)}.')
                            : 'Premium por ${AppConstants.premiumPriceLabel}/mês. A assinatura é feita pelo aplicativo no celular.',
                        style: webText(14, weight: FontWeight.w500, color: AppColors.mutedDark),
                      ),
                    ],
                  ),
                ),
                if (!active)
                  FilledButton.icon(
                    onPressed: () => launchUrl(Uri.parse(_playUrl)),
                    icon: const Icon(Icons.shop_rounded, size: 18),
                    label: const Text('Assinar no app'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(0, 48),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 820;
              final free = _PlanCard(
                title: 'Grátis',
                price: 'R\$ 0',
                accent: AppColors.success,
                benefits: PlanCatalog.free,
              );
              final premium = _PlanCard(
                title: 'Premium',
                price: '${AppConstants.premiumPriceLabel}/mês',
                accent: AppColors.primary,
                benefits: PlanCatalog.premium,
                highlight: true,
              );
              if (!wide) {
                return Column(children: [free, const SizedBox(height: 16), premium]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: free),
                  const SizedBox(width: 16),
                  Expanded(child: premium),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            PlanCatalog.financialDisclaimer,
            style: webText(13, weight: FontWeight.w500, color: AppColors.mutedDark),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.accent,
    required this.benefits,
    this.highlight = false,
  });

  final String title;
  final String price;
  final Color accent;
  final List<PlanBenefit> benefits;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? AppColors.primary : AppColors.primaryMuted,
          width: highlight ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: webText(22, weight: FontWeight.w800, color: accent)),
          const SizedBox(height: 2),
          Text(price, style: webText(15, color: AppColors.mutedDark)),
          const SizedBox(height: 18),
          for (final item in benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_rounded, color: accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: webText(15, weight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: webText(13.5, weight: FontWeight.w500, color: AppColors.mutedDark),
                        ),
                      ],
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
