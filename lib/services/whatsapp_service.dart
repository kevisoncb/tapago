import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../utils/formatters.dart';

enum WhatsAppAction { preventivo, cobrarHoje, atraso }

enum WhatsAppTone { amigavel, formal }

WhatsAppAction whatsAppActionForDue(DateTime due, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  final vencimento = DateTime(due.year, due.month, due.day);
  if (vencimento.isBefore(start)) return WhatsAppAction.atraso;
  if (vencimento == start) return WhatsAppAction.cobrarHoje;
  return WhatsAppAction.preventivo;
}

class WhatsAppService {
  static const defaultTemplate =
      'Oi {primeiro}, tudo bem? A caderneta de {valor} vence em {vencimento}. Quando puder, me confirma o pagamento?{pix}';

  static String fillTemplate({
    required String template,
    required Debt debt,
    required double saldo,
    required String chavePix,
  }) {
    final pix = chavePix.trim().isEmpty ? '' : ' PIX: ${chavePix.trim()}';
    return template
        .replaceAll('{nome}', debt.nome)
        .replaceAll('{primeiro}', firstNameOf(debt.nome))
        .replaceAll('{valor}', Money.full(saldo))
        .replaceAll('{vencimento}', Dates.full(debt.dataVencimento))
        .replaceAll('{pix}', pix)
        .trim();
  }

  static String preview(String customTemplate) {
    final raw = customTemplate.trim().isEmpty ? defaultTemplate : customTemplate;
    return raw
        .replaceAll('{nome}', 'Carlos Oliveira')
        .replaceAll('{primeiro}', 'Carlos')
        .replaceAll('{valor}', 'R\$ 450,00')
        .replaceAll('{vencimento}', '20/09/2026')
        .replaceAll('{pix}', ' PIX: sua-chave')
        .trim();
  }

  static String messageFor({
    required WhatsAppAction action,
    required WhatsAppTone tone,
    required Debt debt,
    required double saldo,
    required String chavePix,
    String customTemplate = '',
    bool isPremium = false,
  }) {
    if (isPremium && customTemplate.trim().isNotEmpty) {
      return fillTemplate(
        template: customTemplate,
        debt: debt,
        saldo: saldo,
        chavePix: chavePix,
      );
    }

    final valor = Money.full(saldo);
    final vencimento = Dates.full(debt.dataVencimento);
    final first = firstNameOf(debt.nome);
    final pix = chavePix.isEmpty ? '' : ' Chave PIX: $chavePix.';

    if (tone == WhatsAppTone.amigavel) {
      switch (action) {
        case WhatsAppAction.preventivo:
          return 'Oi $first, passando só para atualizar o valor da nossa caderneta. Ficou $valor, vence em $vencimento. Qualquer coisa me chama!$pix';
        case WhatsAppAction.cobrarHoje:
          return 'Oi $first, tudo bem? A caderneta de $valor vence hoje. Quando puder, me confirma o pagamento?$pix';
        case WhatsAppAction.atraso:
          return 'Oi $first, a caderneta de $valor venceu em $vencimento. Quando der, combinamos o acerto.$pix';
      }
    }

    switch (action) {
      case WhatsAppAction.preventivo:
        return 'Olá ${debt.nome}, o saldo da caderneta é $valor, com vencimento em $vencimento.$pix';
      case WhatsAppAction.cobrarHoje:
        return 'Olá ${debt.nome}, o saldo de $valor vence hoje. Pode confirmar o pagamento?$pix';
      case WhatsAppAction.atraso:
        return 'Olá ${debt.nome}, o saldo de $valor está em atraso (venceu em $vencimento). Pedimos a regularização.$pix';
    }
  }

  static Future<bool> open({
    required WhatsAppAction action,
    required WhatsAppTone tone,
    required Debt debt,
    required double saldo,
    required String chavePix,
    String customTemplate = '',
    bool isPremium = false,
  }) async {
    final phone = digitsOnly(debt.telefone);
    final withCountry = phone.startsWith('55') ? phone : '55$phone';
    final text = Uri.encodeComponent(
      messageFor(
        action: action,
        tone: tone,
        debt: debt,
        saldo: saldo,
        chavePix: chavePix,
        customTemplate: customTemplate,
        isPremium: isPremium,
      ),
    );
    final uri = Uri.parse('https://wa.me/$withCountry?text=$text');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
