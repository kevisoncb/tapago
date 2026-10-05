String authErrorMessage(String code) {
  switch (code) {
    case 'email-already-in-use':
      return 'Já existe uma conta com esse e-mail.';
    case 'invalid-email':
      return 'E-mail inválido.';
    case 'weak-password':
      return 'A senha precisa ter pelo menos 6 caracteres.';
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
  final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
  if (!emailOk) return 'E-mail inválido.';
  if (password.contains(RegExp(r'\s'))) return 'A senha não pode ter espaços.';
  if (password.length < 6) return 'A senha precisa ter pelo menos 6 caracteres.';
  if (creating && passwordConfirm != null && passwordConfirm != password) {
    return 'As senhas não coincidem.';
  }
  if (creating) {
    final phone = telefone == null ? '' : telefone.replaceAll(RegExp(r'\D'), '');
    if (phone.isNotEmpty && phone.length != 10 && phone.length != 11) {
      return 'Informe um WhatsApp válido.';
    }
    if (!acceptedTerms) {
      return 'Aceite os Termos de Uso e a Política de Privacidade para criar a conta.';
    }
  }
  return null;
}
