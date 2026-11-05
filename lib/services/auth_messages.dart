import '../utils/masks.dart';

String authErrorMessage(String code) {
  switch (code) {
    case 'email-already-in-use':
      return 'Já existe uma conta com esse e-mail.';
    case 'invalid-email':
      return 'E-mail inválido.';
    case 'weak-password':
      return 'Senha fraca. $passwordRulesText';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'E-mail ou senha incorretos.';
    case 'network-request-failed':
      return 'Sem conexão para entrar.';
    case 'too-many-requests':
      return 'Muitas tentativas. Espere um pouco e tente de novo.';
    default:
      return 'Não foi possível entrar.';
  }
}

class PasswordRule {
  const PasswordRule(this.label, this.test);

  final String label;
  final bool Function(String password) test;
}

/// Exigências da senha ao criar a conta, mostradas como lista no cadastro.
final passwordRules = <PasswordRule>[
  PasswordRule('8 caracteres ou mais', (p) => p.length >= 8),
  PasswordRule(
    'Uma letra maiúscula',
    (p) => RegExp(r'\p{Lu}', unicode: true).hasMatch(p),
  ),
  PasswordRule(
    'Uma letra minúscula',
    (p) => RegExp(r'\p{Ll}', unicode: true).hasMatch(p),
  ),
  PasswordRule('Um número', (p) => RegExp(r'\d').hasMatch(p)),
  PasswordRule(
    'Um caractere especial, como ! @ # \$ %',
    (p) => RegExp(r'[^\p{L}\p{N}\s]', unicode: true).hasMatch(p),
  ),
];

const passwordRulesText =
    'Use 8 caracteres ou mais, com letra maiúscula, letra minúscula, número e caractere especial.';

bool isStrongPassword(String password) =>
    passwordRules.every((rule) => rule.test(password));

String? validateAccount({
  required String nome,
  required String email,
  required String password,
  required bool creating,
  String? passwordConfirm,
  String? telefone,
  bool acceptedTerms = false,
}) {
  if (creating && nome.trim().length < 2) return 'Informe seu nome.';
  if (!isValidEmail(email)) return 'E-mail inválido.';
  if (password.contains(RegExp(r'\s'))) return 'A senha não pode ter espaços.';
  if (password.isEmpty) return 'Informe a senha.';
  // Contas antigas podem ter senha de 6 caracteres: a regra forte vale só no cadastro.
  if (creating && !isStrongPassword(password)) {
    return 'A senha ainda não atende a todos os itens. $passwordRulesText';
  }
  if (creating && passwordConfirm != null && passwordConfirm != password) {
    return 'As senhas não coincidem.';
  }
  if (creating) {
    final phone = telefone == null
        ? ''
        : telefone.replaceAll(RegExp(r'\D'), '');
    if (phone.isNotEmpty && !isValidPhoneBr(phone)) {
      return 'Informe um WhatsApp válido.';
    }
    if (!acceptedTerms) {
      return 'Aceite os Termos de Uso e a Política de Privacidade para criar a conta.';
    }
  }
  return null;
}
