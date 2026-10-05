import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../utils/formatters.dart';

enum WhatsAppAction { preventivo, cobrarHoje, atraso }

class WhatsAppService {
  static String messageFor({
    required WhatsAppAction action,
    required Debt debt,
    required String chavePix,
    required double valorAberto,
  }) {
    final valor = Money.full(valorAberto);
    final vencimento = Dates.full(debt.dataVencimento);

    switch (action) {
      case WhatsAppAction.preventivo:
        return 'Olá ${debt.nome}, passando para lembrar que seu débito de $valor vence em $vencimento. Qualquer dúvida, estou à disposição!';
      case WhatsAppAction.cobrarHoje:
        return 'Olá ${debt.nome}, tudo bem? Seu débito de $valor vence hoje. Pode me confirmar o pagamento?';
      case WhatsAppAction.atraso:
        final pix = chavePix.isEmpty ? '' : ' Chave PIX: $chavePix.';
        return 'Olá ${debt.nome}, identificamos que o débito de $valor está em atraso (venceu em $vencimento). Por favor, regularize o quanto antes.$pix';
    }
  }

  static Future<bool> open({
    required WhatsAppAction action,
    required Debt debt,
    required String chavePix,
    required double valorAberto,
  }) async {
    final phone = digitsOnly(debt.telefone);
    final withCountry = phone.startsWith('55') ? phone : '55$phone';
    final text = Uri.encodeComponent(
      messageFor(
        action: action,
        debt: debt,
        chavePix: chavePix,
        valorAberto: valorAberto,
      ),
    );
    final uri = Uri.parse('https://wa.me/$withCountry?text=$text');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
