class PlanBenefit {
  const PlanBenefit(this.title, this.description);
  final String title;
  final String description;
}

class PlanCatalog {
  static const free = <PlanBenefit>[
    PlanBenefit(
      'Caderneta essencial',
      'Clientes e lançamentos únicos, baixas manuais e correções com histórico.',
    ),
    PlanBenefit(
      'Organização da cobrança',
      'Meu dia, relatórios, acompanhamentos e abertura manual do WhatsApp.',
    ),
    PlanBenefit(
      'Seus dados acessíveis',
      'Busca, importação CSV, extratos e exportação dos registros.',
    ),
  ];

  static const premium = <PlanBenefit>[
    PlanBenefit(
      'Cadastro por voz',
      'O app transforma o que foi ditado em uma sugestão de lançamento para sua conferência.',
    ),
    PlanBenefit(
      'Leitura de comprovante',
      'O app sugere o valor encontrado na imagem; você confere antes de fazer uma baixa manual.',
    ),
    PlanBenefit(
      'Mensagem personalizada',
      'Use seu próprio texto e um para cada fase do atraso, de amigável a firme.',
    ),
    PlanBenefit(
      'Resumo do caixa',
      'O que entra e o que sai em 7 e 30 dias e quem mais deve em atraso.',
    ),
    PlanBenefit(
      'Parcelamento e boletos de fornecedores',
      'Crie parcelas a receber e organize contas que você precisa pagar.',
    ),
  ];

  static const financialDisclaimer =
      'O Pagô é um organizador. Não consulta banco, não confirma transferências e não movimenta dinheiro.';
}
