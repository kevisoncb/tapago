import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/session_gate.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  var _creating = false;
  var _busy = false;
  var _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          children: [
            Text(
              'TáPago',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _creating ? 'Crie sua conta para começar' : 'Entre para ver seus débitos',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.mutedDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            if (_creating) ...[
              AppTextField(
                label: 'Nome',
                hint: 'Seu nome',
                icon: Icons.person_outline_rounded,
                controller: _nome,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
            ],
            AppTextField(
              label: 'E-mail',
              hint: 'voce@email.com',
              icon: Icons.mail_outline_rounded,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Senha',
              hint: 'Mínimo de 6 caracteres',
              icon: Icons.lock_outline_rounded,
              controller: _senha,
              obscureText: _obscure,
              suffix: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
              ),
            ),
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
    );
  }
}
