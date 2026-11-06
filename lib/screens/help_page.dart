import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../widgets/help_card.dart';

class HelpTopic {
  const HelpTopic(this.title, this.icon, this.steps);

  final String title;
  final IconData icon;
  final List<String> steps;
}

const voiceHelpSteps = <String>[
  'Em "Novo lançamento", toque em "Cadastro por voz". É uma função do Premium.',
  'Se o celular pedir, permita o uso do microfone.',
  'Fale de uma vez o nome, o valor em reais e o vencimento.',
  'Depois de 3 segundos em silêncio, o app para de ouvir e preenche os campos.',
  'Confira tudo e toque em "Salvar na caderneta". O app nunca salva sozinho.',
];

/// Frases que o leitor de voz entende; um teste garante cada uma delas.
const voiceHelpExamples = <String>[
  'Maria, 200 reais, vence dia 20',
  'João, 1.500 reais, vence amanhã',
  'Ana, 80 reais, vence em 7 dias',
  'Carlos, 300 reais, juros de 5%, vence 20 de dezembro',
  'Pedro, telefone 11 98765 4321, 50 reais, vence hoje',
];

const helpTopics = <HelpTopic>[
  HelpTopic('Fazer um lançamento', Icons.post_add_outlined, [
    'Em "Hoje", toque em "Novo lançamento".',
    'Informe o nome do cliente, o valor e o vencimento. O WhatsApp é opcional, mas é ele que permite cobrar.',
    'Toque em "Salvar na caderneta".',
    'No Premium, dá para dividir em parcelas e anotar os produtos que o cliente levou.',
  ]),
  HelpTopic('Registrar um pagamento', Icons.payments_outlined, [
    'Em "Clientes", toque no cliente e depois no lançamento.',
    'Toque em "Registrar pagamento" e informe quanto entrou.',
    'Pode ser só uma parte: o restante continua em aberto.',
    'O Pagô não confirma transferências: o pagamento é o que você registra.',
  ]),
  HelpTopic('Corrigir um pagamento errado', Icons.undo_rounded, [
    'Em "Clientes", toque no cliente e em "Extrato do cliente".',
    'No pagamento errado, toque em "Estornar registro" e informe o motivo.',
    'O registro continua no histórico como estornado, e o saldo volta.',
  ]),
  HelpTopic('Cobrar pelo WhatsApp', Icons.chat_outlined, [
    'Em "Clientes", toque no cliente e depois no lançamento.',
    'Escolha "Lembrete", "Cobrar hoje" ou "Atraso".',
    'O seu WhatsApp abre com o texto pronto. A mensagem só sai quando você enviar.',
    'No Premium, você escreve os seus textos em "Mais".',
  ]),
  HelpTopic('Ver o extrato e combinar um acordo', Icons.receipt_long_outlined, [
    'Em "Clientes", toque no cliente.',
    '"Extrato do cliente" mostra tudo o que foi lançado e pago, e permite compartilhar em PDF.',
    '"Acompanhar acordo" guarda o que foi combinado e quando retomar o contato.',
  ]),
  HelpTopic('Controlar boletos (Premium)', Icons.receipt_outlined, [
    'Em "Boletos", toque em "Novo boleto" e informe o fornecedor, o valor e o vencimento.',
    'Toque em um boleto para ver as opções dele.',
    'O app avisa antes de vencer, se as notificações estiverem ligadas.',
  ]),
  HelpTopic('Ver os relatórios', Icons.bar_chart_outlined, [
    'Em "Mais", toque em "Relatórios".',
    '"Recebido" soma os pagamentos registrados, sem os estornados.',
    'Os valores não são saldo bancário nem lucro.',
  ]),
  HelpTopic('Usar no celular e no computador', Icons.devices_outlined, [
    'No computador, abra sistema-pago.web.app.',
    'Entre com o mesmo e-mail e a mesma senha do app.',
    'Clientes, lançamentos e boletos são os mesmos nos dois.',
  ]),
  HelpTopic('Excluir a conta', Icons.person_off_outlined, [
    'Em "Mais", vá até o fim da tela e toque em "Excluir minha conta".',
    'Se tiver assinatura ativa, cancele também na loja do celular.',
  ]),
];

/// Passo a passo do cadastro por voz, aberto pelo "?" do próprio cadastro.
Future<void> showVoiceHelp(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Como cadastrar por voz', style: _title),
              const SizedBox(height: 14),
              const VoiceHelpContent(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheet),
                  child: const Text('Entendi'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

TextStyle get _title =>
    GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800);

TextStyle get _body => GoogleFonts.plusJakartaSans(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: AppColors.mutedDark,
);

/// Passos e exemplos de frases, usados na ajuda e no "?" do cadastro.
class VoiceHelpContent extends StatelessWidget {
  const VoiceHelpContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HelpSteps(steps: voiceHelpSteps),
        Text(
          'Exemplos do que falar',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        for (final example in voiceHelpExamples)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '“$example”',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'Diga "reais" depois do valor. Parcelas e produtos você escolhe na tela, depois de falar.',
          style: _body,
        ),
      ],
    );
  }
}

/// Como usar cada função do app, por assunto.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final first = helpTopics.first;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        title: const Text('Como usar o Pagô'),
        backgroundColor: const Color(0xFFF4F7FF),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'Toque num assunto para ver o passo a passo.',
              style: _body,
            ),
          ),
          HelpCard(
            title: first.title,
            icon: first.icon,
            child: HelpSteps(steps: first.steps),
          ),
          const HelpCard(
            title: 'Cadastrar por voz (Premium)',
            icon: Icons.mic_none_rounded,
            child: VoiceHelpContent(),
          ),
          for (final topic in helpTopics.skip(1))
            HelpCard(
              title: topic.title,
              icon: topic.icon,
              child: HelpSteps(steps: topic.steps),
            ),
        ],
      ),
    );
  }
}
