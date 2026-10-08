import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../legal/legal_docs.dart';
import '../screens/legal_page.dart';
import '../services/session_gate.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../utils/input_masks.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _nome = TextEditingController();
  final _telefone = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirma = TextEditingController();
  var _creating = false;
  var _busy = false;
  var _obscure = true;
  var _accepted = false;
  String? _error;

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    _email.dispose();
    _senha.dispose();
    _confirma.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final gate = context.read<SessionGate>();
    final error = _creating
        ? await gate.register(
            nome: _nome.text,
            email: _email.text,
            password: _senha.text,
            passwordConfirm: _confirma.text,
            telefone: _telefone.text,
            acceptedTerms: _accepted,
          )
        : await gate.signIn(email: _email.text, password: _senha.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final firebase = context.watch<SessionGate>().firebaseReady;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            children: [
              Text(
                AppConstants.appName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              Text(
                AppConstants.slogan,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _creating
                    ? 'Crie sua conta para começar'
                    : 'Entre para ver seus débitos',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.mutedDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              if (_creating) ...[
                AppTextField(
                  label: 'Nome completo',
                  hint: 'Seu nome',
                  icon: Icons.person_outline_rounded,
                  controller: _nome,
                  textCapitalization: TextCapitalization.words,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  inputFormatters: [NameMaskFormatter()],
                  maxLength: 80,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'WhatsApp (opcional)',
                  hint: '(00) 00000-0000',
                  icon: Icons.phone_outlined,
                  controller: _telefone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [PhoneMaskFormatter()],
                ),
                const SizedBox(height: 14),
              ],
              AppTextField(
                label: 'E-mail',
                hint: 'voce@email.com',
                icon: Icons.mail_outline_rounded,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: [
                  _creating ? AutofillHints.email : AutofillHints.username,
                ],
                inputFormatters: [EmailMaskFormatter()],
                maxLength: 120,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Senha',
                hint: 'Mínimo de 6 caracteres',
                icon: Icons.lock_outline_rounded,
                controller: _senha,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction:
                    _creating ? TextInputAction.next : TextInputAction.done,
                autofillHints: [
                  _creating
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                inputFormatters: [
                  NoSpaceFormatter(),
                  LengthLimitingTextInputFormatter(64),
                ],
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              if (_creating) ...[
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Confirmar senha',
                  hint: 'Repita a senha',
                  icon: Icons.lock_outline_rounded,
                  controller: _confirma,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  inputFormatters: [
                    NoSpaceFormatter(),
                    LengthLimitingTextInputFormatter(64),
                  ],
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _TermsAccept(
                  accepted: _accepted,
                  onChanged: (value) => setState(() => _accepted = value),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              PrimaryButton(
                label: _busy
                    ? 'Aguarde...'
                    : _creating
                        ? 'Criar conta'
                        : 'Entrar',
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _creating = !_creating;
                          _error = null;
                          _accepted = false;
                        }),
                child: Text(
                  _creating ? 'Já tenho conta' : 'Criar uma conta',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                firebase
                    ? 'Sua conta fica no Firebase e os débitos sincronizam na nuvem.'
                    : 'Conta neste aparelho. Quando o Firebase do projeto estiver configurado, o login passa a valer na nuvem.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsAccept extends StatelessWidget {
  const _TermsAccept({
    required this.accepted,
    required this.onChanged,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.plusJakartaSans(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    );
    final link = style.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: accepted,
            onChanged: (value) => onChanged(value ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            children: [
              Text('Li e aceito os ', style: style),
              GestureDetector(
                onTap: () => LegalPage.open(context, LegalDoc.termos),
                child: Text('Termos de Uso', style: link),
              ),
              Text(' e a ', style: style),
              GestureDetector(
                onTap: () => LegalPage.open(context, LegalDoc.privacidade),
                child: Text('Política de Privacidade', style: link),
              ),
              Text(
                '. Autorizo o tratamento dos meus dados (LGPD) e confirmo que tenho 18 anos ou mais.',
                style: style,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
