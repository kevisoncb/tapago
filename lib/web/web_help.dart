import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/help_card.dart';
import 'web_shell.dart';
import 'web_widgets.dart';

class WebHelpStep {
  const WebHelpStep(this.title, this.text, this.section, this.action);

  final String title;
  final String text;
  final WebSection section;
  final String action;
}

class WebHelpTopic {
  const WebHelpTopic(this.title, this.icon, this.steps);

  final String title;
  final IconData icon;
  final List<String> steps;
}

const webHelpStart = <WebHelpStep>[
  WebHelpStep(
    'Preencha os dados da loja',
    'Coloque o nome da loja e a sua chave PIX. A chave vai junto na mensagem de cobrança.',
    WebSection.conta,
    'Abrir Minha conta',
  ),
  WebHelpStep(
    'Faça o primeiro lançamento',
    'Informe o cliente, o valor e o vencimento. O WhatsApp é opcional, mas é ele que permite cobrar.',
    WebSection.venda,
    'Abrir Lançamento',
  ),
  WebHelpStep(
    'Acompanhe o que vence',
    'O Início mostra o que está em atraso e o que vence em 7 dias. Clique no ícone de conversa para cobrar.',
    WebSection.inicio,
    'Abrir Início',
  ),
  WebHelpStep(
    'Registre o que entrou',
    'Em Clientes, abra o cliente e o lançamento, e use "Registrar pagamento". O saldo é atualizado na hora.',
    WebSection.clientes,
    'Abrir Clientes',
  ),
];

const webHelpTopics = <WebHelpTopic>[
  WebHelpTopic('Fazer um lançamento', Icons.post_add_outlined, [
    'No menu, clique em Lançamento.',
    'Digite o nome do cliente. Se ele já existir, escolha na lista para aproveitar o WhatsApp.',
    'Informe o valor e o vencimento. Os juros são opcionais.',
    'Clique em "Salvar lançamento".',
    'No Premium, dá para dividir em parcelas e anotar o que o cliente levou em "Foi produto?".',
  ]),
  WebHelpTopic('Cadastrar por voz (Premium)', Icons.mic_none_rounded, [
    'No app do celular, toque em "Novo lançamento" e em "Cadastro por voz".',
    'Fale de uma vez o nome, o valor em reais e o vencimento. Exemplo: "Maria, 200 reais, vence dia 20".',
    'Confira os campos e salve. O passo a passo completo está no "?" dessa mesma tela.',
  ]),
  WebHelpTopic('Registrar um pagamento', Icons.payments_outlined, [
    'Em Clientes, clique no cliente.',
    'Abra o lançamento e clique em "Registrar pagamento".',
    'Informe quanto entrou. Pode ser só uma parte: o restante continua em aberto.',
    'O Pagô não confirma transferências: o pagamento é o que você registra.',
  ]),
  WebHelpTopic('Corrigir um pagamento errado', Icons.undo_rounded, [
    'Em Clientes, abra o cliente e clique em "Extrato do cliente".',
    'No pagamento errado, clique em "Estornar registro" e informe o motivo.',
    'O registro continua no histórico como estornado, e o saldo volta.',
  ]),
  WebHelpTopic('Cobrar pelo WhatsApp', Icons.chat_outlined, [
    'No Início, clique no ícone de conversa ao lado do cliente. Ou abra o lançamento em Clientes.',
    'Escolha o tom da mensagem, amigável ou formal.',
    'O seu WhatsApp abre com o texto pronto. A mensagem só sai quando você enviar.',
    'No Premium, você escreve os seus textos em Minha conta.',
  ]),
  WebHelpTopic(
    'Ver o extrato e combinar um acordo',
    Icons.receipt_long_outlined,
    [
      'Em Clientes, clique no cliente.',
      '"Extrato do cliente" mostra tudo o que foi lançado e pago.',
      '"Acompanhar acordo" guarda o que foi combinado e quando retomar o contato.',
    ],
  ),
  WebHelpTopic('Controlar boletos (Premium)', Icons.receipt_outlined, [
    'Em Boletos, clique em "Novo boleto" e informe o fornecedor, o valor e o vencimento.',
    'Quando pagar, clique em "Marcar pago". Se errar, use "Desfazer".',
    'Os filtros mostram o que está em aberto, atrasado ou pago.',
  ]),
  WebHelpTopic('Entender os relatórios', Icons.bar_chart_outlined, [
    'Em Relatórios, clique no período, no alto da tela, para trocar as datas.',
    '"Recebido" soma os pagamentos registrados, sem os estornados.',
    '"Previsto" soma o que está em aberto e vence no período.',
    'Os valores não são saldo bancário nem lucro.',
  ]),
  WebHelpTopic('Assinar o Premium', Icons.workspace_premium_outlined, [
    'A assinatura é feita no aplicativo do celular, pela Google Play.',
    'Depois de assinar, entre aqui com a mesma conta: o Premium vale nos dois.',
    'Para cancelar, use a Play Store, em Pagamentos e assinaturas.',
  ]),
  WebHelpTopic('Usar no celular e no computador', Icons.devices_outlined, [
    'Entre com o mesmo e-mail e a mesma senha nos dois.',
    'Clientes, lançamentos e boletos são os mesmos.',
    'Em computador de outra pessoa, ao terminar, clique na sua inicial, no alto à direita, e em "Sair da conta".',
  ]),
  WebHelpTopic('Excluir a conta', Icons.person_off_outlined, [
    'Em Minha conta, vá até o fim da página e clique em "Excluir minha conta".',
    'Se tiver assinatura ativa, cancele também na Play Store.',
  ]),
];

/// Passo a passo do sistema: primeiros passos com atalhos para cada área e
/// respostas por assunto.
class WebHelp extends StatelessWidget {
  const WebHelp({super.key, required this.onGo});

  final ValueChanged<WebSection> onGo;

  @override
  Widget build(BuildContext context) {
    return WebPage(
      title: 'Ajuda',
      subtitle: 'Como usar o ${AppConstants.appName}, passo a passo.',
      maxWidth: 900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Primeiros passos',
            style: webText(15.5, weight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          WebCard(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              children: [
                for (var i = 0; i < webHelpStart.length; i++)
                  _StartRow(
                    number: i + 1,
                    step: webHelpStart[i],
                    divider: i > 0,
                    onGo: onGo,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Como fazer', style: webText(15.5, weight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final topic in webHelpTopics)
            HelpCard(
              title: topic.title,
              icon: topic.icon,
              child: HelpSteps(steps: topic.steps),
            ),
          const SizedBox(height: 18),
          WebCard(
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Ainda ficou com dúvida?',
                  style: webText(15.5, weight: FontWeight.w800),
                ),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(AppConstants.helpUrl)),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('Falar no WhatsApp'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StartRow extends StatelessWidget {
  const _StartRow({
    required this.number,
    required this.step,
    required this.divider,
    required this.onGo,
  });

  final int number;
  final WebHelpStep step;
  final bool divider;
  final ValueChanged<WebSection> onGo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: divider
            ? const Border(top: BorderSide(color: WebColors.border))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              '$number',
              style: webText(
                14,
                weight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: webText(15, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  step.text,
                  style: webText(
                    14,
                    weight: FontWeight.w500,
                    color: AppColors.mutedDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => onGo(step.section),
            child: Text(step.action),
          ),
        ],
      ),
    );
  }
}
