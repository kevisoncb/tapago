import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';
import 'premium_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final user = state.user;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configurações',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Gerencie sua conta e preferências',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.mutedDark,
              ),
            ),
          ],
        ),
        toolbarHeight: 84,
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF0F3F8)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    initialsOf(user.nome),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nome,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        user.email,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.mutedDark,
                          fontSize: 12.5,
                        ),
                      ),
                      if (user.premiumAtivo) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.premiumGreenSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Plano Premium',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.premiumGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('FINANCEIRO'),
          const SizedBox(height: 10),
          GroupCard(
            children: [
              SettingsRow(
                icon: Icons.diamond_outlined,
                title: 'Minha Chave PIX',
                subtitle: user.chavePix.isEmpty
                    ? 'Toque para cadastrar'
                    : user.chavePix,
                onTap: () => _editPix(context),
              ),
              const Divider(height: 1, indent: 68),
              SettingsRow(
                icon: Icons.account_balance_outlined,
                title: 'Dados Bancários',
                subtitle: user.banco.isEmpty
                    ? 'Cadastre sua conta'
                    : '${user.banco} · Ag ${user.agencia} · Cc ${user.conta}',
                onTap: () => _editBank(context),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionLabel('PREFERÊNCIAS'),
          const SizedBox(height: 10),
          GroupCard(
            children: [
              SettingsRow(
                icon: Icons.notifications_outlined,
                title: 'Notificações Diárias',
                subtitle: 'Lembretes de cobrança',
                trailing: Switch.adaptive(
                  value: user.notificacoesDiarias,
                  onChanged: (value) async {
                    final error = await context
                        .read<AppController>()
                        .setDailyReminders(value);
                    if (error != null && context.mounted) {
                      showTapagoSnack(context, error);
                    }
                  },
                ),
              ),
              const Divider(height: 1, indent: 68),
              SettingsRow(
                icon: Icons.fingerprint_rounded,
                title: 'Acesso Biométrico',
                subtitle: 'Pede digital ou rosto ao abrir',
                trailing: Switch.adaptive(
                  value: user.acessoBiometrico,
                  onChanged: (value) async {
                    final error =
                        await context.read<AppController>().setBiometric(value);
                    if (error != null && context.mounted) {
                      showTapagoSnack(context, error);
                    }
                  },
                ),
              ),
              const Divider(height: 1, indent: 68),
              SettingsRow(
                icon: Icons.translate_rounded,
                title: 'Idioma do App',
                subtitle: 'Português (BR)',
                onTap: () => showTapagoSnack(
                  context,
                  'O TáPago está disponível em Português (BR).',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionLabel('ASSINATURA'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F8FF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TáPago Premium',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            user.premiumAtivo && user.premiumVenceEm != null
                                ? 'Vence em ${Dates.full(user.premiumVenceEm!)}'
                                : 'Desbloqueie clientes ilimitados',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.mutedDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PremiumPage()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: const BorderSide(color: Color(0xFFD7E6FF)),
                      backgroundColor: Colors.white.withValues(alpha: 0.7),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      user.premiumAtivo ? 'Gerenciar Assinatura' : 'Assinar Premium',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('SUPORTE'),
          const SizedBox(height: 10),
          GroupCard(
            children: [
              SettingsRow(
                icon: Icons.help_outline_rounded,
                title: 'Central de Ajuda',
                subtitle: 'Dúvidas e tutoriais',
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => launchUrl(Uri.parse(AppConstants.helpUrl)),
              ),
              const Divider(height: 1, indent: 68),
              SettingsRow(
                icon: Icons.verified_user_outlined,
                title: 'Privacidade e Segurança',
                subtitle: 'Política de privacidade',
                onTap: () => launchUrl(Uri.parse(AppConstants.privacyUrl)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Center(
            child: TextButton(
              onPressed: () => context.read<AppController>().signOut(),
              child: Text(
                'Sair da Conta',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              AppConstants.versionLabel,
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPix(BuildContext context) async {
    final state = context.read<AppController>();
    final controller = TextEditingController(text: state.user.chavePix);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Minha Chave PIX',
                hint: 'CPF, e-mail, telefone ou chave aleatória',
                icon: Icons.qr_code_2_rounded,
                controller: controller,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Salvar chave',
                onPressed: () async {
                  await state.saveUser(
                    state.user.copyWith(chavePix: controller.text.trim()),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editBank(BuildContext context) async {
    final state = context.read<AppController>();
    final banco = TextEditingController(text: state.user.banco);
    final agencia = TextEditingController(text: state.user.agencia);
    final conta = TextEditingController(text: state.user.conta);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Banco',
                hint: 'Nome do banco',
                icon: Icons.account_balance_outlined,
                controller: banco,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Agência',
                hint: '0001',
                icon: Icons.tag,
                controller: agencia,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Conta',
                hint: '12345-6',
                icon: Icons.credit_card_outlined,
                controller: conta,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Salvar dados',
                onPressed: () async {
                  await state.saveUser(
                    state.user.copyWith(
                      banco: banco.text.trim(),
                      agencia: agencia.text.trim(),
                      conta: conta.text.trim(),
                    ),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
