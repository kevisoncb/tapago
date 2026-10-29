import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../legal/legal_docs.dart';
import '../screens/legal_page.dart';
import '../services/whatsapp_service.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../utils/input_masks.dart';
import '../utils/masks.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';
import 'web_widgets.dart';

/// Dados da loja, mensagens de cobrança, limpeza automática e documentos.
class WebAccount extends StatefulWidget {
  const WebAccount({super.key});

  @override
  State<WebAccount> createState() => _WebAccountState();
}

class _WebAccountState extends State<WebAccount> {
  final _loja = TextEditingController();
  final _pix = TextEditingController();
  final _normal = TextEditingController();
  final _atraso = TextEditingController();
  final _atrasoForte = TextEditingController();
  var _loaded = false;
  var _savingProfile = false;
  var _savingMessages = false;

  @override
  void dispose() {
    _loja.dispose();
    _pix.dispose();
    _normal.dispose();
    _atraso.dispose();
    _atrasoForte.dispose();
    super.dispose();
  }

  void _fill(AppController state) {
    if (_loaded || state.user.id.isEmpty) return;
    _loaded = true;
    final user = state.user;
    _loja.text = user.nomeLoja;
    _pix.text = formatPixKey(user.chavePix);
    _normal.text = user.mensagemCobranca.trim().isEmpty
        ? WhatsAppService.defaultTemplate
        : user.mensagemCobranca;
    _atraso.text = user.mensagemAtraso.trim().isEmpty
        ? WhatsAppService.defaultAtrasoTemplate
        : user.mensagemAtraso;
    _atrasoForte.text = user.mensagemAtrasoForte.trim().isEmpty
        ? WhatsAppService.defaultAtrasoForteTemplate
        : user.mensagemAtrasoForte;
  }

  Future<void> _saveProfile(AppController state) async {
    final chave = formatPixKey(_pix.text);
    if (chave.isNotEmpty && !isValidPixKey(chave)) {
      showPagoSnack(
        context,
        'Chave PIX inválida. Use CPF/CNPJ válido, e-mail, celular ou chave aleatória.',
      );
      return;
    }
    setState(() => _savingProfile = true);
    try {
      await state.saveUser(
        state.user.copyWith(nomeLoja: _loja.text.trim(), chavePix: chave),
      );
      if (mounted) showPagoSnack(context, 'Dados salvos.');
    } catch (_) {
      if (mounted) showPagoSnack(context, 'Não foi possível salvar agora.');
    }
    if (mounted) setState(() => _savingProfile = false);
  }

  Future<void> _saveMessages(AppController state) async {
    setState(() => _savingMessages = true);
    try {
      await state.saveUser(
        state.user.copyWith(
          mensagemCobranca: _normal.text.trim(),
          mensagemAtraso: _atraso.text.trim(),
          mensagemAtrasoForte: _atrasoForte.text.trim(),
        ),
      );
      if (mounted) showPagoSnack(context, 'Mensagens salvas.');
    } catch (_) {
      if (mounted) showPagoSnack(context, 'Não foi possível salvar agora.');
    }
    if (mounted) setState(() => _savingMessages = false);
  }

  Future<void> _toggleCleanup(AppController state, bool value) async {
    if (value) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Ligar a limpeza automática?'),
          content: const Text(
            'Quando todos os lançamentos de um cliente estiverem quitados, a caderneta dele será APAGADA 7 dias depois do último pagamento, junto com o histórico e os itens. Não dá para desfazer.\n\n'
            'Você vê a contagem regressiva no contato e pode exportar o extrato ou tocar em "Manter" antes do prazo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Ligar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await state.saveUser(state.user.copyWith(limpezaAuto: value));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    _fill(state);
    final user = state.user;
    final premium = user.premiumAtivo;
    return WebPage(
      title: 'Minha conta',
      subtitle: user.email,
      maxWidth: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dados da loja', style: webText(18, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'O nome aparece nos relatórios; a chave PIX vai junto na cobrança.',
                  style: webText(13.5, weight: FontWeight.w500, color: AppColors.mutedDark),
                ),
                const SizedBox(height: 18),
                AppTextField(
                  label: 'Nome da loja',
                  hint: 'Ex.: Bar do Zé',
                  icon: Icons.storefront_outlined,
                  controller: _loja,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(80)],
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Minha chave PIX',
                  hint: 'CPF, e-mail, celular ou chave aleatória',
                  icon: Icons.qr_code_2_rounded,
                  controller: _pix,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [PixMaskFormatter()],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _savingProfile ? null : () => _saveProfile(state),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(160, 48),
                    ),
                    child: Text(_savingProfile ? 'Salvando…' : 'Salvar dados'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          WebCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mensagens de cobrança',
                  style: webText(18, weight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  premium
                      ? 'Use {primeiro}, {nome}, {valor}, {vencimento}, {dias} e {pix}. Saem no seu WhatsApp.'
                      : 'O plano grátis usa a mensagem pronta abaixo. No Premium você escreve a sua.',
                  style: webText(13.5, weight: FontWeight.w500, color: AppColors.mutedDark),
                ),
                const SizedBox(height: 18),
                if (premium) ...[
                  _MessageField(label: 'Cobrança', controller: _normal),
                  const SizedBox(height: 14),
                  _MessageField(label: 'Atraso', controller: _atraso),
                  const SizedBox(height: 14),
                  _MessageField(label: 'Atraso longo', controller: _atrasoForte),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _savingMessages ? null : () => _saveMessages(state),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(160, 48),
                      ),
                      child: Text(_savingMessages ? 'Salvando…' : 'Salvar mensagens'),
                    ),
                  ),
                ] else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      WhatsAppService.preview('', chavePix: user.chavePix),
                      style: webText(14, weight: FontWeight.w500, color: AppColors.mutedDark),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          WebCard(
            padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: user.limpezaAuto,
              onChanged: (value) => _toggleCleanup(state, value),
              title: Text(
                'Limpeza automática de cadernetas quitadas',
                style: webText(15.5, weight: FontWeight.w800),
              ),
              subtitle: Text(
                'Apaga a caderneta 7 dias depois de quitada. Você vê a contagem e pode manter.',
                style: webText(13.5, weight: FontWeight.w500, color: AppColors.mutedDark),
              ),
            ),
          ),
          const SizedBox(height: 20),
          WebCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ajuda e documentos', style: webText(18, weight: FontWeight.w800)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(AppConstants.helpUrl)),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('Ajuda no WhatsApp'),
                    ),
                    OutlinedButton(
                      onPressed: () => LegalPage.open(context, LegalDoc.termos),
                      child: const Text('Termos de Uso'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          LegalPage.open(context, LegalDoc.privacidade),
                      child: const Text('Privacidade'),
                    ),
                    OutlinedButton(
                      onPressed: () => LegalPage.open(context, LegalDoc.lgpd),
                      child: const Text('LGPD'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse('${AppConstants.siteOrigin}/excluir-conta'),
                  ),
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  child: const Text('Excluir minha conta'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageField extends StatelessWidget {
  const _MessageField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 4,
      maxLength: 600,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
