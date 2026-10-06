import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../legal/legal_docs.dart';
import '../services/client_match.dart';
import '../state/app_controller.dart';
import '../services/whatsapp_service.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/input_masks.dart';
import '../utils/masks.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';
import '../widgets/tapago_logo.dart';
import 'caderneta_page.dart';
import 'contact_history_page.dart';
import 'legal_page.dart';
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
                      if (user.isPremium) ...[
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
          const SectionLabel('CONTATOS'),
          const SizedBox(height: 4),
          const SectionLabel('CADERNETA'),
          const SizedBox(height: 6),
          Text(
            'Todas as pessoas, pagas ou não',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedDark,
            ),
          ),
          const SizedBox(height: 10),
          _ContactsCard(state: state),
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
                    : 'Copia e cola ativada',
                onTap: () => _editPix(context),
              ),
              const Divider(height: 1, indent: 68),
              SettingsRow(
                icon: Icons.account_balance_outlined,
                title: 'Dados Bancários',
                subtitle: user.banco.isEmpty
                    ? 'Cadastre sua conta'
                    : 'Copia e cola ativada',
                onTap: () => _editBank(context),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionLabel('COBRANÇA NO WHATSAPP'),
          const SizedBox(height: 10),
          GroupCard(
            children: [
              SettingsRow(
                icon: Icons.chat_rounded,
                iconBackground: AppColors.whatsappSoft,
                iconColor: AppColors.whatsapp,
                title: user.isPremium
                    ? 'Sua mensagem'
                    : 'Mensagem pronta',
                subtitle: user.isPremium && user.mensagemCobranca.trim().isNotEmpty
                    ? 'Premium: toque para editar'
                    : user.isPremium
                        ? 'Escreva o texto que vai no WhatsApp'
                        : 'O plano livre usa esta. Premium deixa mudar.',
                onTap: () => _editMensagem(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              WhatsAppService.preview(user.mensagemCobranca),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedDark,
              ),
            ),
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
                  onChanged: (value) {
                    context.read<AppController>().saveUser(
                          user.copyWith(notificacoesDiarias: value),
                        );
                  },
                ),
              ),
              const Divider(height: 1, indent: 68),
              SettingsRow(
                icon: Icons.fingerprint_rounded,
                title: 'Acesso Biométrico',
                subtitle: 'Copia e cola ativada',
                trailing: Switch.adaptive(
                  value: user.acessoBiometrico,
                  onChanged: (value) {
                    context.read<AppController>().saveUser(
                          user.copyWith(acessoBiometrico: value),
                        );
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
                            user.isPremium && user.premiumVenceEm != null
                                ? 'Vence em ${Dates.full(user.premiumVenceEm!)}'
                                : user.isPremium
                                    ? 'Assinatura ativa'
                                    : 'Voz e leitura de recibos',
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
                      user.isPremium ? 'Gerenciar Assinatura' : 'Assinar Premium',
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
                subtitle: 'Dúvidas sobre o app',
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => launchUrl(Uri.parse(AppConstants.helpUrl)),
              ),
              const Divider(height: 1, indent: 68),
              SettingsRow(
                icon: Icons.description_outlined,
                title: 'Termos de Uso',
                subtitle: 'Contrato da conta',
                onTap: () => LegalPage.open(context, LegalDoc.termos),
              ),
              const Divider(height: 1, indent: 68),
              SettingsRow(
                icon: Icons.verified_user_outlined,
                title: 'Política de Privacidade',
                subtitle: 'Como tratamos seus dados',
                onTap: () => LegalPage.open(context, LegalDoc.privacidade),
              ),
              const Divider(height: 1, indent: 68),
              SettingsRow(
                icon: Icons.gavel_outlined,
                title: 'LGPD',
                subtitle: 'Seus direitos como titular',
                onTap: () => LegalPage.open(context, LegalDoc.lgpd),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Center(
            child: TextButton(
              onPressed: () {
                showTapagoSnack(context, 'Sessão encerrada neste dispositivo.');
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text(
                'Sair da Conta',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const Center(child: TapagoMark(size: 44)),
          const SizedBox(height: 10),
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
    final controller = TextEditingController(
      text: formatPixKey(state.user.chavePix),
    );
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
                hint: 'CPF, e-mail, celular ou chave aleatória',
                icon: Icons.qr_code_2_rounded,
                controller: controller,
                keyboardType: TextInputType.text,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                inputFormatters: [PixMaskFormatter()],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Salvar chave',
                onPressed: () async {
                  final chave = formatPixKey(controller.text);
                  if (chave.isNotEmpty && !isValidPixKey(chave)) {
                    showTapagoSnack(
                      context,
                      'Chave PIX inválida. Use CPF/CNPJ válido, e-mail, celular ou chave aleatória.',
                    );
                    return;
                  }
                  await state.saveUser(
                    state.user.copyWith(chavePix: chave),
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
    final agencia = TextEditingController(text: formatAgency(state.user.agencia));
    final conta = TextEditingController(text: formatAccount(state.user.conta));
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
                textCapitalization: TextCapitalization.words,
                keyboardType: TextInputType.name,
                inputFormatters: [NameMaskFormatter()],
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Agência',
                hint: '0000-0',
                icon: Icons.tag,
                controller: agencia,
                keyboardType: TextInputType.number,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [AgencyMaskFormatter()],
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Conta',
                hint: '12345-6',
                icon: Icons.credit_card_outlined,
                controller: conta,
                keyboardType: TextInputType.number,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [AccountMaskFormatter()],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Salvar dados',
                onPressed: () async {
                  await state.saveUser(
                    state.user.copyWith(
                      banco: banco.text.trim(),
                      agencia: formatAgency(agencia.text),
                      conta: formatAccount(conta.text),
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

  Future<void> _editMensagem(BuildContext context) async {
    final state = context.read<AppController>();
    final user = state.user;
    if (!user.isPremium) {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mensagem pronta',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O plano livre envia este texto. No Premium você escreve o seu, com {nome}, {valor}, {vencimento} e {pix}.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.mutedDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    WhatsAppService.preview(''),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Quero escrever a minha',
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PremiumPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    final controller = TextEditingController(
      text: user.mensagemCobranca.trim().isEmpty
          ? WhatsAppService.defaultTemplate
          : user.mensagemCobranca,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sua mensagem de cobrança',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Use {primeiro}, {nome}, {valor}, {vencimento} e {pix}. Sai no seu WhatsApp.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.mutedDark,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 6,
                minLines: 4,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  hintText: 'Oi {primeiro}, a caderneta de {valor}...',
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Salvar mensagem',
                onPressed: () async {
                  await state.saveUser(
                    user.copyWith(mensagemCobranca: controller.text.trim()),
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContactsCard extends StatelessWidget {
  const _ContactsCard({required this.state});

  final AppController state;

  @override
  Widget build(BuildContext context) {
    final contacts = groupContacts(state.debts);

    if (contacts.isEmpty) {
      return GroupCard(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Text(
              'Nenhum contato ainda. Quando você lançar alguém, o nome fica aqui — mesmo depois de quitado.',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.mutedDark,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }

    return GroupCard(
      children: [
        SettingsRow(
          icon: Icons.search_rounded,
          title: 'Buscar na caderneta',
          subtitle: '${contacts.length} ${contacts.length == 1 ? 'pessoa' : 'pessoas'}',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CadernetaPage()),
            );
          },
        ),
        const Divider(height: 1, indent: 68),
        for (var i = 0; i < contacts.length; i++) ...[
          CadernetaContactTile(
            contact: contacts[i],
            saldo: contacts[i].saldoAbertoOf(state.saldoOf),
            padded: false,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ContactHistoryPage(
                    contactKey: contacts[i].key,
                  ),
                ),
              );
            },
          ),
          if (i != contacts.length - 1)
            const Divider(height: 1, indent: 68),
        ],
      ],
    );
  }
}
