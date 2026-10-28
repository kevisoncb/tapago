class PlanBenefit {
  const PlanBenefit(this.title, this.description, {this.group = ''});
  final String title;
  final String description;
  final String group;
}

class PlanCatalog {
  static const groupCobranca = 'Cobrança';
  static const groupCaixa = 'Controle do caixa';
  static const groupAgilidade = 'Agilidade';

  static const free = <PlanBenefit>[
    PlanBenefit(
      'Caderneta essencial',
      'Clientes e lançamentos sem limite, baixas parciais, juros e correções com histórico.',
    ),
    PlanBenefit(
      'Cobrança pelo WhatsApp',
      'Mensagem pronta (amigável ou formal) com a sua chave PIX e lembretes de vencimento.',
    ),
    PlanBenefit(
      'Organização do dia',
      'Meu dia, saldo em aberto, vencimentos, atrasos e relatórios.',
    ),
    PlanBenefit(
      'Seus dados acessíveis',
      'Busca, importação CSV, extratos e exportação dos registros.',
    ),
  ];

  static const premium = <PlanBenefit>[
    PlanBenefit(
      'Mensagem com o seu texto',
      'Escreva a sua mensagem de cobrança e um texto diferente para cada fase do atraso, de amigável a firme.',
      group: groupCobranca,
    ),
    PlanBenefit(
      'Resumo do caixa',
      'O que entra e o que sai em 7 e 30 dias e quem mais deve em atraso.',
      group: groupCaixa,
    ),
    PlanBenefit(
      'Parcelamento a receber',
      'Divida a venda em parcelas, cada uma com o seu vencimento.',
      group: groupCaixa,
    ),
    PlanBenefit(
      'Boletos a pagar',
      'Organize as contas de fornecedores, com parcelas e aviso de vencimento.',
      group: groupCaixa,
    ),
    PlanBenefit(
      'Cadastro por voz',
      'O app transforma o que foi ditado em uma sugestão de lançamento para sua conferência.',
      group: groupAgilidade,
    ),
    PlanBenefit(
      'Leitura de comprovante',
      'O app sugere o valor encontrado na imagem; você confere antes de fazer uma baixa manual.',
      group: groupAgilidade,
    ),
  ];

  static const premiumGroups = <String>[
    groupCobranca,
    groupCaixa,
    groupAgilidade,
  ];

  static List<PlanBenefit> premiumIn(String group) =>
      premium.where((item) => item.group == group).toList();

  static const financialDisclaimer =
      'O Pagô é um organizador. Não consulta banco, não confirma transferências e não movimenta dinheiro.';
}
