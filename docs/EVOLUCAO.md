# Pagô — plano de evolução do produto e valorização do negócio

> Plano vivo de evolução, preparado em 23/10/2026 e acompanhado na `develop`. As recomendações continuam sendo o backlog do produto; o estado implementado é registrado abaixo. Nada deste documento autoriza publicação automática em produção.

## Estado da implementação — 26/10/2026

Concluído no código da `develop`, aguardando validação completa em aparelhos antes de produção:

- P0: validação de assinatura sem concessão em erro, vínculo de titularidade, retentativas e proteção após exclusão da conta.
- P0: pagamentos idempotentes, quitação por registro financeiro, estorno auditável, parcelas atômicas e regras de propriedade.
- P0: recuperação de senha, falha de sessão explícita e cache sinalizado sem esconder erro de permissão.
- P1: painel Meu dia, sistema visual, fonte local, parcelamento a receber, extrato PDF/CSV e exportação de dados.
- P1: lembretes com abertura do contexto correto, limite de agenda e atualização ao retomar o aplicativo.
- P2 parcial: acompanhamento manual de contato e promessa de pagamento, separado do saldo financeiro.
- Base móvel: APK Android ARM64 compilado; projeto iOS ajustado para iOS 15.5 e dependências nativas, aguardando build no Xcode.

Incremento concluído: navegação inferior **Hoje / Clientes / Boletos / Mais**, preservando o botão de novo lançamento e os atalhos existentes durante a transição.

Incremento concluído: relatórios simples e úteis, separando claramente recebido, previsto, vencido e boletos de fornecedores, sem chamar recebíveis de saldo bancário ou lucro.

Incremento concluído: importação CSV assistida em lotes atômicos de até 12 lançamentos, com modelo, prévia, validação de erros e duplicatas antes de gravar.

Incremento concluído: primeiro uso com introdução curta e caminho direto para o primeiro lançamento, sem solicitar câmera, microfone, biometria ou notificações antecipadamente.

Próximo incremento recomendado: revisão de acessibilidade do fluxo principal, com foco no TalkBack/VoiceOver, ordem de foco, nomes de ações e uso com fonte ampliada e teclado aberto.

## 1. Minha avaliação do potencial

Vejo potencial no Pagô como ferramenta simples de organização de recebimentos e relacionamento com clientes para pequenos comerciantes. O problema é concreto: registrar vendas a prazo, saber o que falta receber, acompanhar pagamentos parciais e lembrar de cobrar. A proximidade com o WhatsApp combina com esse fluxo.

A oportunidade mais interessante é tornar o app útil toda semana e confiável o suficiente para substituir a caderneta. Um produto que concentra histórico de uso, reduz erros e economiza trabalho pode sustentar assinatura, indicação e futuras parcerias de distribuição.

Isso é uma tese de produto, não uma pesquisa de mercado concluída. Não foram levantados dados atuais de tamanho de mercado, concorrência ou disposição a pagar. A base de 1.000 assinantes e 25.000 gratuitos discutida na conversa é HIPOTÉTICA; não é tração comprovada do Pagô. Nenhuma avaliação financeira deve usar esses números como resultados reais.

### Onde o produto pode ganhar

- Simplicidade para o comerciante que considera um ERP complicado.
- Atendimento próximo, linguagem natural e presença em uma região ou segmento.
- Fluxo completo entre venda, vencimento, contato, pagamento e histórico.
- Confiança: recuperar acesso e registros, entender o saldo e corrigir erros.
- Distribuição por indicação e por parceiros que já atendem comerciantes.

### Onde pode perder

- Planilha, papel e WhatsApp têm baixo custo e hábitos estabelecidos.
- Outras cadernetas, sistemas de gestão e bancos podem incorporar funções semelhantes.
- Reconhecimento de voz e OCR, isoladamente, são recursos replicáveis.
- Uma divergência financeira ou perda de dados pode destruir confiança rapidamente.
- R$ 39,90 pode ser alto para um usuário ocasional e razoável para outro; é necessário medir.

**Posicionamento recomendado:** “Sua caderneta organizada. Seu dinheiro a receber, no seu controle.”

**Promessa de marca:** “Seu negócio merece receber.”

Não prometer pagamento garantido, fim da inadimplência, verificação bancária de comprovantes ou envio automático que o app não realiza.

## 2. O que já existe e eu preservaria

| Parte | Orientação |
| --- | --- |
| Marca Pagô e frase “E aí, pagô?” | Preservar, com uso mais consistente e humano |
| Azul `#2F6BFF` e símbolo de confirmação | Preservar como identificação principal |
| Cadastro de clientes e lançamentos grátis | Preservar a proposta atual; não retirar benefícios adquiridos sem estudo e comunicação |
| Pagamentos parciais e juros opcionais | Melhorar clareza, consistência e histórico |
| Mensagem pelo WhatsApp do usuário | Preservar a revisão e a decisão de envio |
| Boletos a pagar | Preservar a distinção entre pagar fornecedor e receber de cliente |
| Voz e OCR | Preservar como atalhos opcionais, sempre com conferência |
| Firebase, Flutter e repositórios separados | Evoluir sem uma reescrita geral |
| Compra/restauração e preço da loja | A `develop` já avançou nesses fluxos; testar e aperfeiçoar, sem descrevê-los como ausentes |
| Exclusão de conta e página pública | Preservar e completar o ciclo de exclusão/retenção |
| Preparação de App Store e AppsFlyer | Reconhecer o código existente; ativação e disponibilidade exigem validação própria |

## 3. Prioridades

P0: integridade financeira, autorização e recuperação. P1: experiência principal e retenção. P2: monetização e operação. P3: expansão condicionada a evidências.

| Prioridade | Trabalho | Valor esperado | Dependência para considerar concluído |
| --- | --- | --- | --- |
| P0 | Validar assinaturas sem conceder Premium em erro | Evitar concessão indevida e receita fictícia | Testes de compra inválida, falha transitória, renovação e restauração |
| P0 | Pagamento/quitação consistentes e idempotentes | Saldo confiável | Testes com repetição, falha e duas sessões |
| P0 | Parcelamento salvo atomicamente | Evitar parcelas incompletas e duplicadas | Teste de interrupção no salvamento |
| P0 | Recuperação de acesso, dados e exclusão | Continuidade e confiança | Troca de aparelho e restauração de backup testadas |
| P1 | Meu dia + navegação clara | Tornar o próximo passo evidente | Comerciantes concluindo tarefas sem orientação |
| P1 | Parcelamento a receber | Completar a venda a prazo | Grupo, parcelas e saldo coerentes |
| P1 | Extrato e estorno de lançamento | Resolver dúvidas e erros | Totais reconciliados e auditoria preservada |
| P1 | Sincronização e lembretes confiáveis | Uso em situações reais | Testes offline/online e abertura a frio |
| P2 | Cobrança acompanhada e acordos | Menos trabalho de acompanhamento | Contatos manuais sem duplicação nem automação indevida |
| P2 | Relatórios simples, planos e métricas | Demonstrar valor e sustentabilidade | Definições claras e dados reconciliados |
| P3 | Equipe, parceiros, APIs e PIX integrado | Expansão | Demanda comprovada e operação preparada |

## 4. Melhorar primeiro: confiabilidade

### 4.1 Assinaturas

- Remover a concessão de 30 dias após qualquer falha na consulta à Play. Na `develop`, esse caminho continua presente em `functions/index.js`.
- Exigir produto correto e vínculo consistente entre token e conta; não aceitar o primeiro produto alternativo da resposta.
- Em falha temporária, preservar apenas direitos previamente verificados conforme política definida; não inventar uma compra.
- Recuperar RTDN com retentativas, idempotência e reconciliação. O handler atual captura falha de consulta e retorna sucesso.
- Rever a conclusão da compra antes da validação e criar recuperação persistente das confirmações pendentes.
- Separar direitos de assinatura, cortesia e eventual parceiro, para uma origem não revogar outra incorretamente.
- A restauração da `develop` já espera resposta. Melhorar erro, atraso e timeout; silêncio da loja não prova ausência de assinatura.
- Mostrar preço/condições da oferta efetivamente comprada; manter transparência sobre renovação e cancelamento.
- Validar Google Play e App Store separadamente; preparação no código não significa publicação ou aprovação.

### 4.2 Lançamentos e pagamentos

- Definir uma fonte de verdade para o saldo; não depender de um indicador de quitação divergente do histórico.
- Usar valores em centavos inteiros nas operações e armazenamento novos, com migração compatível dos dados existentes.
- Tornar quitação e pagamento consistentes com transação ou modelo equivalente.
- Usar ID estável por operação e idempotência para impedir duplicação por toque, retry e duas sessões.
- Bloquear o botão durante salvamento, mantendo feedback de andamento, erro e possibilidade de tentar de novo.
- Validar no servidor propriedade, vínculo do pagamento ao lançamento, valor e regras de negócio. Validação de interface não é garantia de integridade.
- Distinguir data efetiva do pagamento e data de registro; explicar correções retroativas e recalcular na ordem correta.
- Substituir exclusão financeira silenciosa por estorno rastreável. A exclusão de dados pessoais segue seu próprio fluxo.

### 4.3 Sincronização e acesso

- Exibir última sincronização e estados: atualizado, sem conexão, enviando e falha ao sincronizar.
- Não apresentar falha de permissão como cache válido nem falha de carregamento como ausência de clientes.
- Atualizar débitos/pagamentos entre aparelhos com streams ou invalidação explícita.
- Não criar conta local silenciosamente quando Firebase falha; explicar o modo de operação e oferecer nova tentativa.
- Recuperação de senha simples, sem marketing por e-mail. Respeitar a preferência atual de não criar campanhas por e-mail; recuperação transacional é uma necessidade distinta e pode usar o fluxo de autenticação.
- Avaliar verificação de contato e recuperação sem expor se um terceiro tem conta.
- Definir offline por etapas: primeiro leitura de cache sinalizada; escrita offline só com fila, idempotência, reconciliação e conflitos desenhados. Não prometer offline-first apenas por usar Firestore.

### 4.4 Segurança e privacidade

- Tratar biometria como bloqueio de interface, não como criptografia automática do armazenamento.
- Reduzir cache sensível, definir limpeza no logout e avaliar criptografia com chave do Keystore.
- Validar permissões entre duas contas e coleções administrativas em testes de regras.
- Proteger painel com segundo fator e menor privilégio; verificar o estado real nos consoles.
- Definir retenção por coleção e impedir eventos de assinatura de recriarem um perfil excluído.
- Conferir configurações e testar recuperação de backup; não anunciar prazos que não estejam implementados.
- Nunca enviar nomes, telefones, chaves PIX ou detalhes da caderneta para analytics e logs de diagnóstico por conveniência.
- Limitar abuso de endpoints públicos e avaliar App Check como camada adicional, sem substituir autorização.

## 5. O que acrescentar ao produto

### 5.1 Parcelamento a receber — primeira nova função recomendada

Exemplo: venda de R$ 600 em 3 vezes de R$ 200, cada parcela com seu vencimento, pagamentos e situação.

- Entrada opcional e prazos personalizados.
- Agrupamento da venda original e indicação “2 de 3”.
- Pagamento parcial por parcela; regras explícitas para antecipação e distribuição de pagamento.
- Soma das parcelas igual ao total em centavos.
- Cobrança com número da parcela e saldo correspondente.
- Alteração do acordo preservando o histórico anterior; não reescrever silenciosamente o que já foi pago.

**Critério de aceite:** parcelas e pagamentos mantêm a soma correta após edição, estorno, repetição e uso em dois aparelhos.

### 5.2 Extrato do cliente e recibo do registro

- Histórico cronológico de vendas, parcelas, pagamentos, estornos e saldo.
- Filtro de período e opção de compartilhar PDF ou exportar CSV.
- Identificação do comerciante e indicação de quando o documento foi gerado.
- Esclarecer “pagamento registrado pelo comerciante”; não simular comprovação bancária.
- Compartilhamento sob ação do usuário; conferir destinatário e evitar expor outros clientes.
- Links públicos de extrato, se futuros, exigem autorização, revogação e proteção contra adivinhação; começar por arquivo compartilhado.

### 5.3 Meu dia

Tela inicial orientada a ação, com quatro blocos:

1. Hoje: vencimentos e compromissos do dia.
2. Em atraso: o que precisa de acompanhamento.
3. Próximos sete dias: recebíveis e boletos separados.
4. Últimas atividades: registros recentes e correções.

Cada linha leva ao contexto certo. Mostrar “A receber” ou “Previsto para entrar”, nunca “Disponível” para recebíveis ainda não pagos. A previsão não equivale a saldo bancário ou caixa garantido.

### 5.4 Acompanhamento de cobrança e acordos

- “Contatado hoje”, anotações e próximo contato sugerido pelo usuário.
- Promessa de pagamento com data e valor, separada do vencimento original e sem marcar como recebido.
- Modelos de mensagem amigáveis, curtos e editáveis.
- Compartilhar extrato junto à cobrança quando o usuário escolher.
- Não marcar mensagem como entregue apenas porque o WhatsApp foi aberto; sem integração oficial, o app não sabe disso.
- Evitar linguagem intimidatória, lista pública de devedores ou pressão automatizada.

### 5.5 Exportação e importação assistida

- Exportação dos dados do próprio usuário como capacidade de confiança e portabilidade.
- Importação CSV opcional, com modelo, prévia, validação de erros e duplicatas, seguida de confirmação.
- Não começar pedindo todos os contatos do celular. Preferir cadastro manual e seleção específica se houver necessidade comprovada.
- Exportação é complementar ao backup e não substitui recuperação do serviço.

### 5.6 Relatórios pequenos e úteis

- Recebido no período, previsto e vencido, com definições visíveis.
- Pagamentos parciais e idade dos atrasos por faixa.
- Recebimentos e pagamentos a fornecedores em visões separadas.
- Comparação de períodos usando dados efetivos, com contexto de mudanças e filtros.
- Não chamar de lucro a diferença entre recebimentos e boletos: faltam estoque, despesas, tributos e outros custos.
- Permitir valores exatos em detalhes; abreviações como “1,2 mil” só em visão resumida.

### 5.7 Equipe — somente com demanda comprovada

- Dono, gerente e atendente com permissões mínimas.
- Convites individuais; jamais senha compartilhada como solução de equipe.
- Registro de quem lançou, recebeu, estornou e exportou.
- Conceito explícito de estabelecimento/organização separado da identidade de login.
- Desligamento de membro sem perder os dados do negócio.

Essa etapa muda o modelo de autorização e exige migração; não é apenas acrescentar um campo na tela.

## 6. Estética: como eu redesenharia o app

### 6.1 Direção visual

**Personalidade:** próxima, organizada, segura e com energia. O app deve servir quem trabalha com pressa e usa aparelhos de diferentes tamanhos e capacidades.

- Azul principal `#2F6BFF`, fundos claros e texto escuro.
- Verde-lima `#DFFF7C` como acento de marca em detalhes e divulgação, com texto escuro; não como cor única de status.
- Verde próprio para confirmação, âmbar para atenção e vermelho para atraso/erro, sempre com texto e ícone.
- Cartões de destaque moderados; listas financeiras com alinhamento e densidade úteis.
- Evitar excesso de gradientes, vidro, sombras pesadas e animações em números financeiros.
- Usar uma família tipográfica legível, poucos pesos e algarismos tabulares para valores. Preferir fonte embutida para não depender de download em runtime.

### 6.2 Sistema de componentes

Referência inicial, a ajustar em testes:

| Elemento | Diretriz |
| --- | --- |
| Espaçamento | Escala de 4/8/12/16/24/32 dp |
| Margens | 16–24 dp, conforme largura |
| Texto principal | Cerca de 16 sp, respeitando escala do sistema |
| Valores de destaque | Cerca de 28–36 sp, sem cortar valores longos |
| Áreas de toque | Pelo menos 48 × 48 dp para ações Android |
| Cantos | Escala consistente, aproximadamente 12–20 dp |
| Ícones | Mesma família e espessura; rótulo em ações importantes |
| Contraste | Meta WCAG AA: 4,5:1 em texto comum e 3:1 onde aplicável |
| Movimento | Feedback curto e discreto; respeitar movimento reduzido |

Criar componentes para campo monetário, pessoa, parcela, pagamento, alerta, estado vazio, confirmação, ação primária e estado de sincronização. Documentar uso e estados, não só cores.

### 6.3 Navegação

Testar uma barra inferior com **Hoje / Clientes / Boletos / Mais**, mantendo “+ Novo lançamento” como ação clara. A busca deve ser fácil de encontrar.

O logo e o avatar podem manter atalhos, mas as funções principais não deveriam depender de descobrir que a marca abre um menu. Validar a nova organização antes de substituir hábitos existentes.

### 6.4 Mudanças por tela

| Tela | O que mudaria |
| --- | --- |
| Entrada | Benefício em uma frase, login, cadastro, recuperação e demonstração com dados fictícios |
| Primeiro uso | Um lançamento guiado; adiar permissões até a função ser usada |
| Hoje | Separar receber/pagar; destacar ações pendentes e atualização dos dados |
| Clientes | Busca, saldo e situação; nome e telefone como identificadores claros; homônimos possíveis |
| Caderneta do cliente | Saldo, próximo vencimento, linha do tempo; ações “Registrar pagamento”, “Preparar cobrança” e “Ver extrato” |
| Novo lançamento | Nome, valor e vencimento primeiro; juros e parcelamento progressivos; salvar protegido contra repetição |
| Pagamento | Saldo atual, valor recebido, data, prévia do novo saldo e confirmação |
| Boletos | Vencido/hoje/próximos/pagos, fornecedor e parcela; código com rótulo de validação correto |
| Premium | Benefícios concretos, preço da loja, estado atual, restauração e cancelamento fáceis |
| Configurações | Conta e segurança, preferências, exportação, assinatura e ajuda; ações destrutivas separadas |

Exemplo de resumo de cliente:

```text
Carlos Oliveira                         Buscar / opções
R$ 450,00 a receber
R$ 150,00 vencidos · R$ 300,00 a vencer

[Registrar pagamento]  [Preparar cobrança]

Histórico                         Ver extrato
Hoje       Pagamento registrado              + R$ 50,00
12/out     Venda — parcela 1 de 3               R$ 200,00
```

Os valores são ilustrativos; o design deve esclarecer o significado e a soma de cada subtotal.

### 6.5 Estados que precisam parecer bem resolvidos

- Sem clientes: “Sua caderneta começa com uma venda” e botão de cadastro.
- Sem atraso: confirmação discreta, sem incentivar cobrança desnecessária.
- Erro: motivo compreensível, dados preservados e ação de recuperação.
- Salvando: impedir repetição e anunciar progresso para leitor de tela.
- Offline: explicar o que pode ser visto e o que ainda não foi confirmado.
- Expiração do Premium: preservar acesso ao histórico e facilitar exportação, restauração ou renovação.
- Notificação: não mostrar nome e dívida na tela bloqueada por padrão sem avaliar privacidade e permitir ajuste.

### 6.6 Acessibilidade

- Testar TalkBack, fonte ampliada, ordem de foco, teclado e orientação suportada.
- Não depender só de vermelho/verde, gesto oculto ou ícone sem nome.
- Garantir leitura correta de valores e datas; evitar anúncios repetidos de contadores animados.
- Manter saldo, botão e confirmação utilizáveis com teclado aberto e telas pequenas.
- Tema escuro pode vir depois, com contraste testado; não é prioridade sobre legibilidade do tema atual.

## 7. Site, demonstração e presença na loja

- Manter a identidade do app; mockups ilustrativos devem ser identificados e não prometer uma interface já publicada.
- Abertura com benefício, imagem legível e uma ação principal: experimentar ou conhecer o app, conforme disponibilidade real.
- Demonstração curta: cadastrar venda, registrar pagamento e preparar mensagem. Sem cadastro ou dados pessoais para experimentar.
- Demo permanente em ambiente isolado, com reset e sem usar uma conta real compartilhada entre visitantes.
- Explicar grátis/Premium; usar preço coerente com a loja e condições claras.
- Substituir frases que sugerem baixa automática por “Você confere e confirma o pagamento”.
- Mostrar depoimentos e resultados apenas com autorização e evidência; não inventar comerciantes ou números.
- Screenshots reais da versão lançada, úteis na tela pequena; descrição da loja orientada a tarefas.
- Documentos e suporte fáceis de encontrar; conferir domínio e contatos atuais antes de publicar.
- A proposta visual local já criada é um conceito. Ela não foi publicada por falta de autenticação no Firebase e não substitui validação com usuários.

## 8. O que remover, simplificar ou adiar

| Item | Decisão recomendada |
| --- | --- |
| Score de Confiança estático | Ocultar; só voltar com definição correta, explicação e análise do impacto |
| Premium sem validação | Remover imediatamente do fluxo de produção |
| Cadastro local silencioso em falha Firebase | Substituir por estado explícito e recuperável |
| Texto interno de produto/erro | Trocar por orientação humana; diagnóstico fica em logs apropriados |
| Números e banners em excesso | Reduzir; preservar hierarquia e valores exatos acessíveis |
| Benefícios descritos como “IA” sem explicar | Explicar o que a função preenche/lê e o que o usuário confirma |
| PIX antigo para assinatura | Inventariar clientes e uso; desativar rotas obsoletas com plano, sem apagar às cegas |
| Dados bancários sem uso claro | Tornar opcionais e minimizar coleta; não sugerir conta conectada inexistente |
| “Juros do mês” sem cálculo mensal correspondente | Corrigir rótulo e regra antes de ampliar recursos de juros |
| Limitar o grátis já prometido como ilimitado | Não fazer abruptamente; testar valor adicional do Premium |
| Bot de WhatsApp | Não implementar agora; o contexto do projeto também orienta adiar |
| Carteira própria e movimentação de dinheiro | Adiar até haver parceiro, demanda e operação apropriada |
| Crédito e score para terceiros | Adiar; exigem finalidade, governança e avaliação regulatória específica |
| ERP completo, estoque e fiscal | Evitar nesta fase; medir demanda e preferir integrações quando necessário |
| Mais rastreamento para “ter métricas” | Coletar apenas o necessário, com configuração e transparência adequadas |

## 9. Planos e monetização

Não alteraria o preço de R$ 39,90 só por opinião. Mediria uso e disposição a pagar em segmentos diferentes, mantendo preço e oferta compatíveis com cada loja.

### Proposta de estrutura a validar

- **Grátis:** caderneta essencial, histórico legível, pagamentos corretos, segurança, recuperação e exportação básica. Confiabilidade não deve depender de assinatura.
- **Premium:** atalhos que economizam tempo, como voz/OCR, mensagens próprias, boletos e, após validar, parcelamento avançado e relatórios.
- **Equipe, futuramente:** usuários individuais, permissões e auditoria por estabelecimento, se houver demanda suficiente para um plano próprio.

Definir com usuários se parcelamento básico deve ser grátis para aumentar ativação ou Premium para capturar valor. Não presumir a resposta. Evitar fragmentar planos cedo.

Plano anual pode melhorar previsibilidade, mas exige evidência de retenção, condições claras e testes nas lojas. Desconto grande não compensa produto abandonado. Avaliação gratuita e cortesias não devem ser contadas como assinaturas pagas.

## 10. Validação de mercado e crescimento

### Primeiro público

Escolher um segmento e uma região para aprender: por exemplo, comércio de bairro ou prestadores que vendem a prazo. São hipóteses; não afirmar que todos têm a mesma rotina. Investigar também frequência de uso, necessidade de internet e quem registra pagamentos.

### Pesquisa prática

1. Observar 10–15 comerciantes executando tarefas reais, sem coletar dados pessoais de seus clientes no material de pesquisa.
2. Perguntar como controlam hoje, onde erram, o que já tentaram e por que abandonaram.
3. Testar um protótipo com tarefas: lançar, receber parcialmente, localizar saldo e corrigir erro.
4. Acompanhar um piloto consentido por algumas semanas e comparar comportamentos.
5. Manter apenas as hipóteses que mostram uso recorrente e valor percebido.

Essas quantidades são sugestões de descoberta qualitativa, não amostra estatística de mercado.

### Distribuição

- Indicação simples e rastreável, com regras contra abuso e sem solicitar agenda inteira.
- Parcerias com contadores, associações e fornecedores, começando por piloto e proposta clara.
- Conteúdo mostrando rotinas reais do produto, sem prometer recuperação garantida de dívida.
- Atendimento de entrada concentrado em ajudar no primeiro lançamento.
- Tráfego pago só depois de saber ativação, retenção e margem por canal; AppsFlyer é instrumentação, não garantia de crescimento.

## 11. Métricas que tornam o negócio mais valioso

| Métrica | Definição útil |
| --- | --- |
| Ativação | Conta nova que conclui o primeiro lançamento e uma segunda ação de valor; janela deve ser definida e medida |
| Uso relevante semanal | Comerciante que lança, registra pagamento ou acompanha vencimentos; abertura sozinha não basta |
| Retenção por coorte | Percentual das contas de uma semana/mês que retorna a uma ação relevante em períodos posteriores |
| MRR pago | Receita recorrente normalizada de assinaturas reais, separada de testes, cortesias, inadimplência e reembolsos |
| Cancelamento | Perda de assinantes e perda de receita, com denominador e período explícitos |
| Margem de contribuição | Receita líquida menos custos variáveis atribuíveis; separar custos fixos e trabalho do fundador |
| CAC e retorno | Custo para adquirir pagante e tempo para recuperar esse custo pela margem, por canal |
| Confiabilidade | Falhas por operação, divergências de saldo, tempo de resolução e sessões sem travamento |
| Suporte | Chamados por comerciantes ativos, motivo, tempo e resolução |
| Força regional | Estabelecimentos ativos por cidade/segmento e concentração de receita |

“Valor registrado na caderneta” não é volume financeiro processado pelo Pagô. “Pagamento registrado” não prova pagamento bancário. Não usar esses números como TPV de uma operação de pagamentos.

Antes de modelar LTV, esperar histórico suficiente. Receita anualizada não equivale a receita contratada ou futura garantida. Não há meta universal de conversão ou retenção válida para o app sem observação da base.

O painel existente tem funil e retenção; conferir como são calculados. Usar somente o último acesso não reconstrói com precisão a presença em cada janela histórica. Se necessário, registrar eventos mínimos de atividade e agregados por período.

## 12. Preparar para parceria bancária sem virar banco agora

O valor potencial para um banco é distribuição, uso recorrente e um fluxo comprovado junto a comerciantes. Não é simplesmente armazenar uma lista de devedores.

### Evolução possível, por etapas

1. Organizador independente com saldo confiável e usuários recorrentes.
2. Parceria de distribuição/licença sem movimentar dinheiro pelo Pagô.
3. Integração de cobrança PIX com parceiro habilitado e contrato adequado.
4. Conciliação por evento bancário verificado, com identificadores únicos, idempotência, tratamento de duplicação e exceções.
5. Outros serviços somente após avaliação de demanda, finalidade de dados, responsabilidade e regras aplicáveis.

Gerar uma mensagem com chave PIX e ler imagem de comprovante não é conciliação. Não baixar dívida com base apenas em OCR ou screenshot.

### Preparação técnica comercialmente útil

- Documentar modelo de domínio e APIs com contratos versionados.
- Separar identidade, estabelecimento e direitos de acesso antes de licença multiempresa.
- Exportação/migração documentadas, integrações desacopladas e isolamento de dados.
- Auditoria de mudanças financeiras, política de incidentes, backup e recuperação testados.
- SDKs de atribuição com consentimento/declarações adequados e identidade limpa na troca de conta.
- Fila de saída para eventos S2S importantes: no código atual, uma falha de envio pode ser absorvida depois de o evento já ter sido gravado.
- Monitorar desempenho e custo antes de redesenhar a infraestrutura. Não adotar microsserviços por expectativa de venda.

Não preparar carteira ou crédito sem esclarecer quem guarda recursos, processa pagamentos, responde a incidentes e trata os dados. Uma integração ou venda não autoriza automaticamente transferência de dados pessoais nem alteração de finalidade.

## 13. Engenharia, testes e operação

### Base de testes

- Regras Firebase: conta A não acessa dados de B; usuário não altera Premium nem coleções administrativas.
- Financeiro: repetição, concorrência, centavos, estorno, pagamento retroativo e falha entre etapas.
- Parcelas: soma, vencimentos, interrupção, edição e vínculo com o grupo.
- Assinaturas: compra inválida, produto errado, conta errada, pendência, renovação, cancelamento, reembolso e expiração.
- Exclusão: dados previstos removidos/anonimizados e eventos posteriores sem recriar o perfil.
- Notificações: aberto, segundo plano, encerrado, reinício, fuso e permissão negada. Hoje há horizonte de agenda de 14 dias e lacunas de abertura.
- OCR: arquivo, bytes, imagem ilegível e cancelamento. A limpeza do arquivo temporário deve aguardar o reconhecimento.
- Interface: telas pequenas, fonte ampliada, acessibilidade, navegação de volta e recuperação de erro.

### Publicação e observabilidade

- CI em `develop`, revisão e promoção controlada para `main`.
- Separar desenvolvimento/testes de produção; não usar conta real compartilhada para validar isolamento.
- Bloquear build de publicação se faltar assinatura correta; não usar fallback debug como release distribuível.
- Verificar target SDK, binários nativos e requisitos atuais das lojas no artefato final.
- Monitorar falhas e latência de validação, transações, sincronização e webhooks, além de crashes.
- Atualizar dependências com testes; não usar correções forçadas de versão principal automaticamente.
- Testar com dados sintéticos em 100, 1.000 e 10.000 registros por comerciante para orientar paginação e agregados.
- Definir orçamento e alertas de custo. Estabelecer objetivos de disponibilidade e recuperação conforme a operação puder sustentá-los.

## 14. Roteiro por etapas, sem calendário inventado

### Etapa A — tornar confiável

Assinaturas, transações, bloqueio de duplicação, exclusão, recuperação de acesso, estados de erro e sincronização.

**Saída:** duas sessões conseguem trabalhar com falhas e retentativas sem duplicar pagamentos nem divergir saldo. Compras inválidas não concedem benefício. Dados e acesso podem ser recuperados pelos caminhos documentados.

### Etapa B — tornar fácil e completo no essencial

Novo sistema visual, Meu dia, navegação, parcelamento a receber, estorno e extrato. Entregar em incrementos e testar o fluxo antes de redesenhar todas as telas.

**Saída:** comerciantes do piloto concluem as tarefas principais com clareza; falhas observadas viram melhorias antes de expandir.

### Etapa C — provar valor e sustentar operação

Métricas confiáveis, preço/oferta, relatórios úteis, acompanhamento de cobrança, exportação/importação e canais de aquisição medidos.

**Saída:** retenção, receita e custos podem ser explicados e reconciliados; crescimento não depende só de promoção nem do atendimento pessoal constante do fundador.

### Etapa D — expandir com evidência

Equipe, parceiros regionais, API/licença e integrações financeiras seletivas.

**Saída:** demanda comercial, suporte, autorização de dados e responsabilidades estabelecidos antes de ampliar risco operacional.

O prazo depende de equipe, orçamento, código efetivamente publicado e testes em aparelho. Não estimar conclusão só pelo número de telas.

## 15. O que levaria a uma futura proposta de aquisição

- Direitos sobre código, marca e materiais organizados; inventário de licenças de terceiros.
- Contratos, titularidade das contas e processo possível de transferência documentados.
- Histórico financeiro conciliado e despesas operacionais, inclusive substituição do trabalho do dono.
- Coortes de uso, assinantes reais, canais de aquisição e concentração por segmento/região.
- Mapa técnico, integrações, custos e pendências conhecidas com plano de correção.
- Equipe/processo que permita continuar a operação sem depender exclusivamente de uma pessoa.
- Regras de privacidade e compartilhamento compatíveis com a operação proposta.
- Separação entre valor do negócio existente, exclusividade, trabalho de integração e suporte pós-venda.

Uma base fiel e uma operação transferível ajudam a negociação. Nenhum conjunto de funções garante aquisição ou múltiplo de venda.

## 16. Próximas dez decisões concretas

1. Definir qual comerciante/região será o primeiro foco e observar sua rotina.
2. Corrigir validação de assinatura e integridade financeira antes de ampliar cobrança.
3. Resolver recuperação de acesso e dar clareza à sincronização.
4. Especificar parcelamento a receber e histórico de estornos.
5. Prototipar Meu dia e caderneta do cliente com comerciantes.
6. Aplicar componentes visuais e acessibilidade ao fluxo principal.
7. Entregar extrato/exportação com totais verificáveis.
8. Corrigir abertura e renovação dos lembretes.
9. Medir retenção e valor percebido antes de reformular preços ou ampliar tráfego pago.
10. Só depois selecionar uma expansão: equipe, parceiros ou PIX integrado, conforme evidência.

**Recomendação final:** tornar o Pagô o lugar em que o comerciante confia para saber o que falta receber e o que precisa fazer hoje. Essa utilidade recorrente, com receita saudável e operação confiável, é o caminho mais defensável para aumentar o valor do produto.

## 17. Limites deste documento

- Revisão de código e contexto do repositório, não auditoria integral de produção.
- Situação real das lojas, usuários, receitas e configurações dos consoles não confirmada.
- Flutter e fluxos Android/iOS não executados nesta sessão; problemas estáticos não devem ser apresentados como reproduções em aparelho.
- Mudanças de mercado, preço, aparência, privacidade e arquitetura propostas exigem validação apropriada.
- Este arquivo foi criado fora do checkout para não misturar recomendações com implementação na branch de produção.
