# Pagô — visão completa do produto e do sistema

Documento consolidado em 26 de outubro de 2026 a partir do código da branch `develop`. Ele descreve o produto como existe hoje, a lógica adotada, a arquitetura, o trabalho já concluído e o que ainda precisa ser feito antes de uma publicação segura. A prioridade é o aplicativo móvel para Android e iOS; o site e a demonstração web são materiais de apoio.

## O que é o Pagô

O Pagô é uma caderneta digital para pequenos comerciantes e profissionais que vendem fiado, a prazo ou emprestam dinheiro. O aplicativo organiza clientes, valores a receber, vencimentos, pagamentos informados pelo próprio usuário, juros, parcelas, histórico e contatos de cobrança. A proposta é substituir papel, memória e controles espalhados por uma rotina simples: registrar o que foi vendido, acompanhar quem deve, anotar pagamentos e saber quem precisa de atenção.

O Pagô não é banco, carteira digital, gateway de pagamentos nem sistema de confirmação de PIX. Ele não consulta contas bancárias, não movimenta dinheiro e não consegue garantir que uma transferência aconteceu. Quando o usuário registra uma baixa, ele está informando ao seu organizador que recebeu aquele valor. Essa distinção aparece nos textos e na lógica financeira para evitar uma promessa que o produto não cumpre.

A oferta gratuita preserva a caderneta essencial, a organização dos clientes, os extratos e a exportação. O Premium acrescenta conveniência: lançamento sugerido por voz, leitura assistida de imagem com conferência obrigatória, mensagem de cobrança personalizada, boletos de fornecedores e parcelamento a receber. O preço configurado no código é R$ 39,90 por mês, mas a tela de compra deve apresentar o preço devolvido pela Google Play ou App Store.

## Como o usuário utiliza o aplicativo

A navegação principal está dividida em Hoje, Clientes, Boletos e Mais. O painel Hoje resume a operação e mostra a agenda de cobrança. A área Clientes contém as cadernetas, seus lançamentos, pagamentos e extratos. Boletos organiza compromissos do próprio comerciante com fornecedores. Mais reúne acompanhamentos, relatórios, importação, exportação, assinatura, preferências e informações legais.

Uma conta nova recebe uma introdução curta e pode ir diretamente ao primeiro lançamento. O aplicativo não pede câmera, microfone, biometria ou notificações antes que esses recursos sejam escolhidos. Isso reduz atrito e deixa claro por que cada permissão é necessária.

Na caderneta, o comerciante registra um valor, uma descrição, a data e o vencimento. Pode criar uma única dívida ou dividi-la de duas a doze parcelas, vendo uma prévia antes de salvar. Depois informa pagamentos parciais ou totais. A baixa é preservada no histórico; se houver erro, o aplicativo cria uma correção auditável com motivo em vez de apagar silenciosamente o registro original.

O Meu dia prioriza promessas vencidas, contatos atrasados, compromissos de hoje, próximos sete dias e clientes vencidos sem contato. A área completa de acompanhamentos permite pesquisar nome ou WhatsApp, filtrar situações e registrar contato, anotação e promessa. Abrir o WhatsApp exige uma ação explícita do usuário. O Pagô não envia mensagens sozinho e um acompanhamento nunca altera o saldo financeiro.

A carteira pode ser filtrada por atraso, vencimento nos próximos sete dias, saldo em aberto, caderneta quitada e atraso sem contato. Os indicadores mostram vencidos sem contato, promessas que precisam de revisão, clientes já acompanhados e contatos realizados nos últimos sete dias. São indicadores de rotina, não de dinheiro efetivamente recebido.

Os relatórios separam recebido informado, previsto, vencido, idade dos atrasos e boletos de fornecedores. Eles não chamam recebíveis de saldo bancário ou lucro. O usuário também pode gerar extrato em PDF ou CSV, exportar os dados carregados e importar lançamentos por CSV com arquivo-modelo, prévia, validação e detecção de duplicatas.

## Tecnologia e organização do código

O aplicativo foi desenvolvido em Flutter, o que permite compartilhar a maior parte da interface e da lógica entre Android e iOS. A versão atual do projeto é `2.4.0+25`, com Dart 3.13 e Flutter 3.47 na validação local. O identificador do aplicativo é `app.usepago`.

O ponto de entrada está em `lib/main.dart`; `lib/app.dart` monta a aplicação, o tema, a sessão e a navegação. As telas ficam em `lib/screens`. Os componentes reutilizáveis ficam em `lib/widgets`, e cores, tipografia e estilos ficam em `lib/theme`. A fonte Plus Jakarta Sans é incluída no próprio aplicativo, evitando depender de download durante a execução.

`lib/state/app_controller.dart` coordena a sessão e as ações principais. Ele liga a interface aos repositórios, mantém o estado necessário às telas e dispara atualizações depois das operações. Os modelos de usuário, dívida, pagamento e boleto estão em `lib/models/models.dart`.

A pasta `lib/services` concentra as regras específicas: cálculo de saldo, ledger de pagamentos, parcelas, relatórios, extratos, importação CSV, acompanhamento, lembretes, voz, reconhecimento de texto, biometria, compras, exportação e métricas. Essa separação impede que as regras financeiras fiquem misturadas aos botões e layouts.

O Firebase fornece autenticação, Firestore, Cloud Functions e Crashlytics. As coleções principais são `Users`, `Debts`, `Payments`, `Bills` e `CollectionFollowUps`. Cada registro financeiro pertence ao usuário autenticado. As regras do Firestore verificam propriedade, vínculos e campos protegidos. O backend em `functions` trata validação de assinatura Google e Apple, exclusão de conta, administração e atribuição de receita.

O aplicativo também possui um repositório local, usado pela demonstração e pelos modos previstos no código. Os dados financeiros locais ficam separados por conta. O cache remoto só substitui uma leitura quando há falha de rede e sinaliza que os dados exibidos foram salvos anteriormente; ele não deve esconder falhas de permissão nem ser apresentado como uma solução offline completa.

## Lógica financeira e proteção dos dados

O saldo é derivado dos lançamentos e do ledger de pagamentos. Operações novas usam transações ou lotes atômicos quando vários documentos precisam mudar juntos. O parcelamento cria o conjunto de parcelas como uma única operação lógica. A importação CSV limita o lote a doze lançamentos para manter a gravação controlada.

Cada pagamento recebe uma identidade estável para reduzir duplicações por toque repetido ou nova tentativa. A quitação depende dos registros financeiros, e uma correção mantém o pagamento original e acrescenta o estorno correspondente. Isso dá rastreabilidade e torna mais fácil explicar como o saldo foi obtido.

Há uma revisão de ledger que fortalece a compatibilidade das escritas novas. A publicação dessa mudança exige uma sequência coordenada entre aplicativos, regras e backend, pois clientes antigos podem tentar gravar documentos que as regras novas recusam. O procedimento está documentado em `docs/financial-data-rollout.md`.

As validações do aplicativo melhoram a experiência, mas a segurança real depende das regras e do backend. O sistema atual controla propriedade e coerência estrutural, porém não deve ser tratado como um ledger bancário certificado. Credenciais, chaves das lojas e assinatura de produção não ficam no Git.

## Autenticação, assinatura e privacidade

Em produção, uma falha do Firebase não cria uma conta local silenciosamente. A recuperação de senha evita revelar se determinado e-mail está cadastrado. A exclusão de conta mantém uma trava para impedir recriação indevida enquanto houver registros sujeitos à política definida.

As compras nativas são iniciadas somente em Android ou iOS. Uma compra não concede Premium apenas porque houve erro ao consultar a loja: a validação precisa ser bem-sucedida, o produto deve ser o esperado e a titularidade deve corresponder à conta. Renovação, restauração e reembolso consideram origem e período. Concessões administrativas válidas são mantidas separadas para que um evento da loja não as revogue por engano.

As métricas implementadas medem criação de caderneta, origem manual ou CSV, baixa manual e correção de baixa somente depois que a operação foi persistida. Não enviam nome, telefone, valor, vencimento, chave PIX nem conteúdo da caderneta. Sem configuração do AppsFlyer, essa instrumentação permanece inativa.

Os lembretes de acompanhamento estão desligados por padrão. A permissão é pedida quando o usuário ativa o recurso. A notificação abre a agenda do aplicativo; ela não envia WhatsApp e não registra pagamento. O agendamento respeita uma janela de quatorze dias e um limite conjunto de sessenta notificações.

## O que já foi feito na evolução

O trabalho na `develop` fortaleceu os pontos mais sensíveis do produto. A validação de assinatura deixou de conceder acesso em caso de erro e passou a verificar titularidade. O fluxo financeiro ganhou idempotência, transações, parcelamento atômico, correção auditável e regras de propriedade. A autenticação passou a expor falhas corretamente, e o cache deixou de esconder erros de autorização.

A experiência principal recebeu o painel Meu dia, navegação inferior, sistema visual consistente, fonte local, primeiro uso orientado, acessibilidade melhorada, relatórios, extratos PDF/CSV, exportação e importação CSV assistida. Campos ganharam rótulos, ações de ícone foram nomeadas e os valores principais foram agrupados para TalkBack e VoiceOver.

A rotina de cobrança recebeu agenda priorizada, histórico de contato, promessas, busca, filtros, indicadores e lembretes opcionais. A carteira recebeu filtros avançados e ordenação por urgência. A tela de planos foi reescrita para explicar com clareza o que continua gratuito e qual conveniência o Premium oferece.

A base móvel Android foi compilada em ARM64, com pacote, assinatura de teste e compatibilidade de alinhamento de 16 KB verificados. O projeto iOS foi ajustado para iOS 15.5 por causa das dependências de reconhecimento de texto, recebeu configuração CocoaPods e tratamento de notificações em primeiro plano. O site institucional possui uma configuração dedicada que publica a pasta correta com HTML, CSS, JavaScript e imagens.

## Qualidade já verificada

Na última validação registrada, 81 testes Flutter passaram, cobrindo regressões, navegação, parcelas, centavos, duplicação de pagamento, quitação, correção, isolamento de contas, relatórios, acompanhamentos, lembretes, filtros, indicadores e catálogo de planos. A análise estática do Flutter terminou sem problemas.

O backend possui 23 testes aprovados, incluindo assinatura, titularidade, falhas de loja, eventos atrasados, exclusão e atribuição. As regras do Firestore têm nove testes aprovados. O site e a demonstração foram compilados localmente, e os arquivos do site responderam com HTTP 200 no servidor local.

Esses testes comprovam comportamento do código em ambiente controlado. Eles não comprovam a configuração real das lojas, a entrega de notificações em aparelhos, a concorrência com dados reais nem a implantação em produção.

## O que falta fazer

A próxima fase é estabilização e preparação de publicação. O passo mais importante é validar o aplicativo em aparelhos Android reais e, em um Mac com Xcode, em iPhones reais ou simuladores. É preciso percorrer cadastro, recuperação de senha, criação de cliente, lançamentos, parcelas, baixa, correção, importação, exportação, compartilhamento, câmera/OCR, voz, biometria, WhatsApp, permissões, notificações, texto ampliado, TalkBack e VoiceOver.

As compras precisam ser testadas nos ambientes sandbox da Google Play e da App Store, incluindo compra nova, cancelamento, renovação, restauração, troca de conta, reembolso, falha de rede e demora na resposta. Também é necessário confirmar produtos, preços, webhooks, RTDN e notificações da Apple nos consoles reais.

Antes de enviar uma nova versão, deve-se executar a migração financeira documentada, publicar backend e regras na ordem planejada e testar atualização de um usuário antigo. O artefato Android atual usa certificado de teste e não deve ser enviado à Play. É necessário aumentar versão e número do build quando a entrega estiver fechada, gerar um AAB com a chave de produção, guardar os símbolos e validar a instalação por uma faixa de testes da loja.

No iOS ainda falta executar o build nativo completo, resolver qualquer problema de pods ou assinatura, configurar certificados, perfis, capacidades e privacidade no App Store Connect e submeter uma versão ao TestFlight. A preparação existente no código não equivale a uma versão iOS pronta para publicação.

Também falta definir e revisar formalmente a política de retenção depois da exclusão da conta, os textos de privacidade, os custos e a retenção do agendamento de atribuição, o atendimento a incidentes e a rotina de backup e recuperação. Uma exportação manual é útil ao usuário, mas não substitui uma estratégia operacional de restauração.

O site corrigido ainda precisa ser publicado no Firebase Hosting autenticado para que a versão pública deixe de usar a configuração antiga. Essa publicação é independente do aplicativo e tem prioridade menor.

Depois do lançamento, o desenvolvimento deve ser guiado por dados reais: conclusão do primeiro lançamento, retorno semanal, cadernetas ativas, uso dos acompanhamentos, retenção, conversão e cancelamento. Preço, limites e novos recursos não devem ser decididos com base na hipótese de 1.000 pagantes e 25.000 gratuitos, pois esses números foram apenas um cenário discutido e não uma métrica verificada.

## Evolução futura recomendada

O maior valor do Pagô está na confiança e na frequência de uso. Primeiro deve provar que o comerciante consegue registrar, encontrar, cobrar e corrigir sem perder dados. Depois, os melhores avanços são melhorar sincronização e recuperação, tornar a agenda mais útil, medir retenção, facilitar indicação e oferecer suporte rápido.

Recursos como equipe, parceiros, APIs, conciliação ou PIX integrado pertencem a uma etapa posterior. Eles exigem demanda comprovada, operação, segurança, contratos e responsabilidades regulatórias muito maiores. Se um banco ou instituição quiser incorporar o processo, a melhor forma de negociar é preservar a propriedade intelectual, documentar a arquitetura e oferecer licenciamento, parceria ou aquisição com escopo e responsabilidades claros. O Pagô atual pode funcionar como produto de organização; uma integração bancária seria um produto adicional, não apenas mais uma tela.

Esteticamente, o aplicativo deve continuar usando azul como cor principal, verde-lima como acento de marca e cores próprias para confirmação, atenção e atraso. Valores precisam de boa hierarquia, contraste e alinhamento. As animações devem ser discretas, áreas de toque devem ter pelo menos 48 dp e os componentes devem respeitar aumento de texto e redução de movimento. A interface deve transmitir clareza e segurança, sem transformar uma ferramenta financeira em um painel carregado.

## Situação atual do projeto

A branch de evolução é `develop`; `main` representa produção. As mudanças descritas estão commitadas localmente na `develop`. Nenhum merge em `main`, deploy de backend, regras, site, atualização na Google Play ou publicação na App Store foi executado por este trabalho.

O produto já possui uma base técnica considerável e uma experiência muito mais completa do que uma caderneta simples. A fase de acrescentar funções principais foi concluída. O risco agora está menos na ausência de telas e mais na validação de produção: aparelhos, lojas, permissões, dados antigos, regras implantadas, assinatura oficial, privacidade e operação. Resolver esses pontos é o que transforma o código atual em uma versão publicável e confiável.
