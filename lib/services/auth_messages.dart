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
}) {
  if (creating && nome.trim().length < 2) return 'Informe seu nome.';
  final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
  if (!emailOk) return 'E-mail inválido.';
  if (password.length < 6) return 'A senha precisa ter pelo menos 6 caracteres.';
  return null;
}
