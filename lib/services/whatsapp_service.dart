import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../utils/formatters.dart';

enum WhatsAppAction { preventivo, cobrarHoje, atraso }

enum WhatsAppTone { amigavel, formal }

/// A partir de quantos dias de atraso a mensagem passa a ser a "firme".
const firmOverdueDays = 16;

int daysOverdue(DateTime due, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  final vencimento = DateTime(due.year, due.month, due.day);
  final diff = start.difference(vencimento).inDays;
  return diff < 0 ? 0 : diff;
}

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

  static const defaultAtrasoTemplate =
      'Oi {primeiro}, a caderneta de {valor} venceu em {vencimento} e está com {dias} de atraso. Consegue acertar hoje?{pix}';

  static const defaultAtrasoForteTemplate =
      'Olá {nome}, o saldo de {valor} está com {dias} de atraso (venceu em {vencimento}). Preciso da regularização com urgência; se não houver retorno, vou precisar tomar outras providências.{pix}';

  static String diasLabel(int dias) => dias == 1 ? '1 dia' : '$dias dias';

  static String fillTemplate({
    required String template,
    required Debt debt,
    required double saldo,
    required String chavePix,
    DateTime? now,
  }) {
    final pix = chavePix.trim().isEmpty ? '' : ' PIX: ${chavePix.trim()}';
    // Sem {parcela} no texto do lojista, a parcela vai junto do valor.
    final valor = debt.parcelado && !template.contains('{parcela}')
        ? '${Money.full(saldo)} (${debt.parcelaLabel})'
        : Money.full(saldo);
    return template
        .replaceAll('{parcela}', debt.parcelado ? debt.parcelaLabel : '')
        .replaceAll('{nome}', debt.nome)
        .replaceAll('{primeiro}', firstNameOf(debt.nome))
        .replaceAll('{valor}', valor)
        .replaceAll('{vencimento}', Dates.full(debt.dataVencimento))
        .replaceAll(
          '{dias}',
          diasLabel(daysOverdue(debt.dataVencimento, now: now)),
        )
        .replaceAll('{pix}', pix)
        .trim();
  }

  static String preview(
    String customTemplate, {
    String chavePix = '',
    String fallback = defaultTemplate,
  }) {
    final raw = customTemplate.trim().isEmpty ? fallback : customTemplate;
    final pix = chavePix.trim().isEmpty ? 'sua-chave' : chavePix.trim();
    return raw
        .replaceAll('{nome}', 'Carlos Oliveira')
        .replaceAll('{primeiro}', 'Carlos')
        .replaceAll('{valor}', 'R\$ 450,00')
        .replaceAll('{vencimento}', '20/09/2026')
        .replaceAll('{dias}', '8 dias')
        .replaceAll('{parcela}', 'parcela 1 de 3')
        .replaceAll('{pix}', ' PIX: $pix')
        .trim();
  }

  static String messageFor({
    required WhatsAppAction action,
    required WhatsAppTone tone,
    required Debt debt,
    required double saldo,
    required String chavePix,
    String customTemplate = '',
    String atrasoTemplate = '',
    String atrasoForteTemplate = '',
    bool isPremium = false,
    DateTime? now,
  }) {
    if (isPremium) {
      var chosen = customTemplate;
      if (action == WhatsAppAction.atraso) {
        final forte =
            daysOverdue(debt.dataVencimento, now: now) >= firmOverdueDays;
        final stage = forte ? atrasoForteTemplate : atrasoTemplate;
        if (stage.trim().isNotEmpty) {
          chosen = stage;
        } else if (forte && atrasoTemplate.trim().isNotEmpty) {
          chosen = atrasoTemplate;
        }
      }
      if (chosen.trim().isNotEmpty) {
        return fillTemplate(
          template: chosen,
          debt: debt,
          saldo: saldo,
          chavePix: chavePix,
          now: now,
        );
      }
    }

    final valor = debt.parcelado
        ? '${Money.full(saldo)} (${debt.parcelaLabel})'
        : Money.full(saldo);
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
    String atrasoTemplate = '',
    String atrasoForteTemplate = '',
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
        atrasoTemplate: atrasoTemplate,
        atrasoForteTemplate: atrasoForteTemplate,
        isPremium: isPremium,
      ),
    );
    final uri = Uri.parse('https://wa.me/$withCountry?text=$text');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
