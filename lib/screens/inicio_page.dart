import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../utils/constants.dart';
import 'auth_page.dart';

const _playUrl = 'https://play.google.com/store/apps/details?id=app.usepago';
const _siteUrl = 'https://usepago.web.app';

TextStyle _text(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color color = AppColors.text,
  double? height,
}) => GoogleFonts.plusJakartaSans(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

/// Tela de entrada do sistema na web (`/inicio`): apresenta o Pagô e leva para
/// entrar ou criar conta. Só aparece para quem ainda não está logado.
class InicioPage extends StatelessWidget {
  const InicioPage({super.key});

  void _open(BuildContext context, {required bool creating}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuthPage(startCreating: creating),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 860;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          AppConstants.appName,
                          style: _text(
                            28,
                            weight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _open(context, creating: false),
                          child: const Text('Entrar'),
                        ),
                      ],
                    ),
                    SizedBox(height: wide ? 72 : 40),
                    _hero(context, wide),
                    SizedBox(height: wide ? 72 : 44),
                    _features(wide),
                    const SizedBox(height: 44),
                    _plans(),
                    const SizedBox(height: 36),
                    Wrap(
                      spacing: 20,
                      children: [
                        TextButton(
                          onPressed: () => launchUrl(Uri.parse(_playUrl)),
                          child: const Text('Baixar na Google Play'),
                        ),
                        TextButton(
                          onPressed: () => launchUrl(Uri.parse(_siteUrl)),
                          child: const Text('Site do Pagô'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seu fiado organizado, agora também no computador.',
          style: _text(wide ? 44 : 30, weight: FontWeight.w800, height: 1.1),
        ),
        const SizedBox(height: 16),
        Text(
          'Veja quem deve, quanto e quando cobrar. Registre pagamentos e '
          'cobre pelo seu WhatsApp, no mesmo cadastro do aplicativo.',
          style: _text(18, color: AppColors.mutedDark, height: 1.45),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: () => _open(context, creating: true),
              style: FilledButton.styleFrom(
                minimumSize: const Size(220, 52),
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Criar conta grátis'),
            ),
            OutlinedButton(
              onPressed: () => _open(context, creating: false),
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, 52)),
              child: const Text('Já tenho conta'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _features(bool wide) {
    const items = [
      (Icons.today_rounded, 'Meu dia', 'Vencimentos, atrasos e quanto receber.'),
      (
        Icons.chat_rounded,
        'Cobrança no WhatsApp',
        'Mensagem pronta com o seu PIX, enviada por você.',
      ),
      (
        Icons.payments_rounded,
        'Pagamentos e parcelas',
        'Pague 1, 2, tudo ou outro valor, sem confusão.',
      ),
      (
        Icons.sync_rounded,
        'Mesma conta do app',
        'O que você anota no celular aparece aqui.',
      ),
    ];
    final cards = [
      for (final item in items)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryMuted),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.$1, color: AppColors.primary),
              const SizedBox(height: 10),
              Text(item.$2, style: _text(17, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                item.$3,
                style: _text(14.5, color: AppColors.mutedDark, height: 1.4),
              ),
            ],
          ),
        ),
    ];
    if (!wide) {
      return Column(
        children: [
          for (final card in cards)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(width: double.infinity, child: card),
            ),
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }

  Widget _plans() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Grátis para começar. Premium por '
            '${AppConstants.premiumPriceLabel}/mês.',
            style: _text(20, weight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'No Premium: anotar o que o cliente levou, relatório do mês em '
            'JPG e PDF e parcelamento a receber.',
            style: _text(15, color: AppColors.mutedDark, height: 1.4),
          ),
        ],
      ),
    );
  }
}
