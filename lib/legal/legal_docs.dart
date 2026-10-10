enum LegalDoc { termos, privacidade, lgpd }

class LegalSection {
  const LegalSection(this.title, this.body);

  final String title;
  final String body;
}

class LegalDocs {
  static const updatedAt = '6 de outubro de 2026';
  static const contact = 'kevison.brandes@outlook.com';

  static String titleOf(LegalDoc doc) {
    switch (doc) {
      case LegalDoc.termos:
        return 'Termos de Uso';
      case LegalDoc.privacidade:
        return 'Política de Privacidade';
      case LegalDoc.lgpd:
        return 'LGPD';
    }
  }

  static List<LegalSection> sectionsOf(LegalDoc doc) {
    switch (doc) {
      case LegalDoc.termos:
        return termos;
      case LegalDoc.privacidade:
        return privacidade;
      case LegalDoc.lgpd:
        return lgpd;
    }
  }

  static const termos = <LegalSection>[
    LegalSection(
      '1. Quem somos e o que estes termos regulam',
      'Estes Termos de Uso regulam o acesso e o uso do aplicativo e do site Pagô, caderneta digital para organizar fiado, venda a prazo e empréstimos entre o usuário e os clientes que ele cadastra.\n\n'
          'O Pagô não é instituição financeira, não é correspondente bancário, não concede crédito em nome próprio e não intermedia o pagamento entre você e o seu cliente, salvo no fluxo de assinatura Premium, quando indicado.\n\n'
          'Ao criar uma conta ou usar o serviço, você declara ter 18 anos ou mais, capacidade civil e concordar com estes Termos e com a Política de Privacidade. O aceite eletrônico vale como manifestação de vontade, nos termos do Marco Civil da Internet (Lei nº 12.965/2014) e da Medida Provisória nº 2.200-2/2001.',
    ),
    LegalSection(
      '2. Cadastro e conta',
      'Você se responsabiliza pela veracidade dos dados informados, pela guarda da senha e pelo uso da conta. Não compartilhe o acesso. Avise em kevison.brandes@outlook.com se suspeitar de uso indevido.\n\n'
          'Podemos recusar, suspender ou encerrar contas usadas em fraude, abuso, violação destes termos ou da lei. A exclusão da conta e dos dados da caderneta pode ser pedida pelo mesmo e-mail, observado o prazo e as retenções legais (por exemplo, comprovante da assinatura).',
    ),
    LegalSection(
      '3. O serviço',
      'O plano gratuito permite cadastrar clientes e lançamentos, abater valores na caderneta (inclusive juros, quando você usa essa função) e abrir mensagens de cobrança no WhatsApp da sua conta (wa.me). O Pagô não envia mensagem em nome próprio ao seu cliente: o disparo sai do seu aplicativo de mensagens.\n\n'
          'A caderneta da conta fica no banco de dados do serviço. Isso vale no plano gratuito e no Premium: não é um extra pago. Juros são opcionais e definidos por você. O registro de “somente juros” ou “valor total” é ferramenta interna da sua conta e não substitui contrato, recibo ou título que você eventualmente emita com o cliente.\n\n'
          'Recursos Premium (quando contratados) incluem cadastro por voz, leitura de recibos e mensagem de cobrança no seu texto. Funções anunciadas e ainda em implantação serão indicadas no app.',
    ),
    LegalSection(
      '4. Relação com os seus clientes',
      'Os clientes, valores e telefones que você cadastra são da sua operação. Você é o controlador desses dados e deve ter base legal para tratá-los (relação comercial, contrato, consentimento ou outra hipótese da LGPD).\n\n'
          'Cobranças devem respeitar o Código de Defesa do Consumidor (Lei nº 8.078/1990), em especial o art. 42: é vedado expor o consumidor a ridículo, constrangimento ou ameaça. É proibido usar o Pagô para assédio, fraude, ameaça, discriminação ou cobrança ilegal. Mensagens ofensivas ou fora da lei são de sua responsabilidade.',
    ),
    LegalSection(
      '5. Assinatura Premium',
      'O Premium, quando disponível, custa R\$ 39,90 por mês. Na Google Play a renovação segue até o cancelamento. No PIX via Asaas o pagamento confirma 30 dias de acesso, sem renovação automática.\n\n'
          'O cancelamento da loja vale para o ciclo seguinte: o período já pago permanece disponível até o vencimento. Reembolsos da loja seguem as regras da Google Play. Preços podem mudar com aviso prévio no app ou no site.',
    ),
    LegalSection(
      '6. Propriedade intelectual',
      'Marca, layout, código e conteúdos do Pagô pertencem aos seus titulares. Você não adquire licença para copiar, revender, descompilar ou explorar o serviço senão para o uso pessoal da conta. Os dados que você lança na caderneta continuam seus.',
    ),
    LegalSection(
      '7. Disponibilidade e limitação de responsabilidade',
      'O serviço é prestado “como disponível”. Podemos interromper, corrigir falhas e alterar funções. Não garantimos que lembretes, sincronização ou abertura do WhatsApp funcionem em todo aparelho ou operadora.\n\n'
          'Na medida permitida pela lei, o Pagô não responde por lucros cessantes, inadimplência do seu cliente, bloqueio de WhatsApp, indisponibilidade de terceiros (Google, WhatsApp, Asaas) nem por lançamentos que você cadastrar de forma incorreta. Isso não afasta direitos irrenunciáveis do CDC quando você for consumidor do app.',
    ),
    LegalSection(
      '8. Privacidade',
      'O tratamento de dados pessoais segue a Política de Privacidade e a Lei nº 13.709/2018 (LGPD). Ao aceitar estes Termos, você também aceita essa política.',
    ),
    LegalSection(
      '9. Alterações',
      'Podemos atualizar estes Termos. A data no topo indica a versão vigente. Uso continuado após a publicação no app ou em usepago.web.app vale como aceite da nova versão, salvo quando a lei exigir consentimento específico.',
    ),
    LegalSection(
      '10. Foro e contato',
      'Aplica-se a legislação brasileira. Fica eleito o foro do domicílio do usuário, quando consumidor, ou o foro da comarca da sede do prestador, quando a lei permitir.\n\n'
          'Dúvidas, pedidos de exclusão e encarregado de dados: kevison.brandes@outlook.com.',
    ),
  ];

  static const privacidade = <LegalSection>[
    LegalSection(
      '1. Controlador e contato',
      'O Pagô é o controlador dos dados da sua conta (cadastro, assinatura, uso do app). Dos dados dos clientes que você informa (nome, telefone, valores), você é o controlador e o Pagô atua como operador, nos termos da LGPD.\n\n'
          'Encarregado / canal LGPD: kevison.brandes@outlook.com. Pedidos de titular serão respondidos no prazo legal.',
    ),
    LegalSection(
      '2. Dados que tratamos',
      'Conta: nome, e-mail, senha (armazenada de forma protegida), telefone se informado, data e hora do aceite dos termos, chave PIX, dados bancários opcionais, preferências (notificações, biometria), status da assinatura.\n\n'
          'Caderneta: nome e telefone dos seus clientes, valores, juros, vencimentos, abatimentos e histórico.\n\n'
          'Boletos a pagar (Premium): fornecedor, valor, vencimento, parcelas e código do boleto, se você colar.\n\n'
          'Premium, quando usado: imagem de comprovante (OCR) e áudio para cadastro por voz.\n\n'
          'Site: dados técnicos usuais de acesso (IP, navegador) para segurança e estatística agregada. Não vendemos a sua lista de clientes.',
    ),
    LegalSection(
      '3. Bases legais e finalidades (art. 7º da LGPD)',
      'Execução de contrato: criar a conta, manter a caderneta, processar a assinatura e abrir o WhatsApp a seu pedido.\n\n'
          'Cumprimento de obrigação legal: registros fiscais e de pagamento da assinatura, quando exigidos.\n\n'
          'Legítimo interesse: segurança da conta, prevenção a fraude e melhoria do produto, com o teste de equilíbrio e o direito de oposição.\n\n'
          'Consentimento: aceite destes documentos no cadastro; recursos opcionais (voz, OCR, notificações no aparelho) quando a plataforma exigir permissão.',
    ),
    LegalSection(
      '4. Compartilhamento',
      'Firebase/Google (autenticação e banco), Google Play (assinatura no Android), Asaas (PIX da assinatura, quando usado) e o aplicativo de WhatsApp no seu aparelho, só para abrir a conversa que você disparar.\n\n'
          'Não vendemos dados. Autoridade pública só mediante ordem legal.',
    ),
    LegalSection(
      '5. Transferência internacional',
      'Provedores como o Google podem processar dados fora do Brasil. Nesses casos buscamos as salvaguardas da LGPD (cláusulas contratuais e mecanismos do fornecedor).',
    ),
    LegalSection(
      '6. Retenção e exclusão',
      'Mantemos os dados enquanto a conta existir e pelo prazo necessário a obrigações legais (por exemplo, comprovante de pagamento). Você pode pedir correção ou exclusão em kevison.brandes@outlook.com. Backups podem levar um período técnico para sumir por completo.',
    ),
    LegalSection(
      '7. Direitos do titular (art. 18)',
      'Confirmação do tratamento, acesso, correção, anonimização, portabilidade, informação sobre compartilhamentos, revogação do consentimento e oposição, quando couber. Também cabe reclamação à ANPD.',
    ),
    LegalSection(
      '8. Segurança e crianças',
      'Usamos autenticação, regras de acesso e SSL. Nenhum sistema é infalível. O Pagô não se destina a menores de 18 anos.',
    ),
    LegalSection(
      '9. Alterações',
      'Esta política pode mudar. A data no topo indica a versão vigente. Alteração relevante será avisada no app ou no site.',
    ),
  ];

  static const lgpd = <LegalSection>[
    LegalSection(
      'Papéis',
      'Na sua conta, o Pagô é controlador. Nos dados dos clientes da caderneta, você é controlador e o Pagô é operador: só trata o que for preciso para prestar o serviço que você contratou.',
    ),
    LegalSection(
      'Base legal',
      'Contrato da conta e da assinatura; obrigação legal de registros de pagamento; legítimo interesse em segurança; consentimento no cadastro e em recursos que pedem permissão do aparelho.',
    ),
    LegalSection(
      'Clientes que você cadastra',
      'Informe só dados que você tem legitimidade para tratar. O Pagô não cobra o seu cliente em nome próprio: a mensagem sai do seu WhatsApp. Cobrança vexatória é proibida pelo CDC.',
    ),
    LegalSection(
      'Direitos e prazos',
      'Acesso, correção, exclusão, portabilidade e revogação pelo e-mail kevison.brandes@outlook.com. Responderemos no prazo da LGPD, salvo retenção legal. Autoridade nacional: ANPD.',
    ),
  ];
}
