# Pagô — contexto atual

Retrato do código em desenvolvimento em 26/10/2026. Prioridade do dono: melhorar e validar o aplicativo Android e iOS; demo web é apoio secundário. Conversar em português. Implementar funcionalidades somente em `develop`; `main` representa produção. Reescrever este documento ao modificar o sistema, sem acumular histórico.

## Git e publicação

Branch de trabalho: `develop`, baseada em `2c987d5e7161123b511d99971a903440033d77ce`. As alterações desta entrega estão no workspace. Nenhum deploy, merge em `main` ou atualização na Google Play foi executado. Configurações e situações do Console descritas anteriormente precisam de confirmação no serviço; não são verificadas por testes locais.

## Produto

Marca Pagô, pacote `app.usepago`, projeto Firebase `tapago-ae948`. Caderneta para fiado, vendas a prazo e empréstimos; baixas manuais e juros, clientes, cobrança pelo WhatsApp por ação do usuário. A caderneta essencial, organização, extratos e exportação permanecem gratuitos. Premium acrescenta voz, leitura assistida de imagem, mensagem própria, boletos a pagar e parcelamento a receber. Preço no código: R$ 39,90/mês; preço exibido na compra deve vir da loja. O app não consulta banco, não confirma transferências e não movimenta dinheiro.

Navegação principal inferior com Hoje, Clientes, Boletos e Mais. Conta nova sem lançamentos recebe uma introdução curta e pode abrir diretamente o primeiro lançamento; a conclusão fica isolada por conta neste aparelho. O guia não solicita permissões antecipadamente. Dashboard Meu dia com filtros, totais e histórico recente. A agenda do painel prioriza promessas vencidas ou próximas, contatos atrasados e clientes vencidos sem contato; abre WhatsApp por ação do usuário e não altera saldo. A área completa de acompanhamentos, acessível pelo painel e por Mais, busca nome/WhatsApp, filtra situações e apresenta contagens de vencidos sem contato, promessas a revisar, acompanhados e contatos em sete dias. A carteira filtra contatos por atraso, próximos sete dias, saldo em aberto, quitados e vencidos sem contato. Relatórios por período separam recebido informado, previsto, vencido, idade dos atrasos e boletos de fornecedores, sem apresentar lucro ou saldo bancário. Métricas mínimas medem criação de caderneta, origem manual/CSV, baixa manual e correção de baixa somente após persistência. Baixas são declarações no organizador, sem confirmação bancária; nenhum evento contém dados pessoais ou valores da caderneta e tudo permanece inativo sem configuração do AppsFlyer. Bootstrap web carrega CanvasKit local ao build, sem CDN externo; botões usam a fonte local do tema. Parcelamento a receber (Premium) de 2 a 12 vezes: o primeiro vencimento vem do calendário e as demais parcelas vencem no mesmo dia dos meses seguintes, com prévia. A importação CSV de lançamentos foi retirada do menu e não faz parte da entrega; os arquivos `debt_csv_import*` ficam sem uso. Extrato PDF/CSV e exportação JSON/CSV dos registros carregados. Correção de baixa exige motivo e mantém registro original. Acompanhamento privado registra contato, anotação e promessa, sem movimentar dinheiro. Score ilustrativo foi removido das telas alteradas.

## Mapa

- `lib/screens`: autenticação, dashboard, clientes, lançamentos, boletos, extrato, exportação, acompanhamento e configurações.
- `lib/state/app_controller.dart`: coordenação da sessão, operações financeiras, sincronização e assinaturas.
- `lib/services`: repositórios Firestore/local/cache; ledger; parcelas; PDF/CSV; billing; lembretes; voz/OCR; sessão.
- `lib/models/models.dart`: usuário, dívida, pagamento e boleto, com campos aditivos de parcelamento e estorno.
- `assets/fonts`: fontes Plus Jakarta Sans incluídas com licença e proveniência.
- `functions`: Play, Apple, administração, exclusão, rotas legadas Asaas e atribuição de receita.
- `site`: site institucional completo. `firebase.site.json` publica HTML, CSS, JavaScript e imagens no Hosting `usepago`; a configuração padrão continua reservada aos redirecionamentos e APIs em `hosting-redirect`.
- `test`, `functions/test`, `tool/rules`: testes Flutter, servidor e regras.

## Dados e integridade

Coleções principais: Users, Debts, Payments, Bills e CollectionFollowUps. Dados do dono; acompanhamento tem contato imutável e limites de campos. Pagamentos são preservados; correção por estorno. Operações novas usam transação com revisão do ledger e limite de 400 pagamentos por caderneta. Parcelas usam lote atômico.

A marcação de revisão muda a compatibilidade de escrita de clientes antigos. Ler `docs/financial-data-rollout.md` antes de publicar. Aritmética financeira é validada no cliente; as regras impõem propriedade, vínculo e coordenação, não equivalem a um ledger bancário no servidor.

Modo local armazena finanças no envelope `pago_<uid>_finance_v1`, lendo chaves legadas quando necessário. Cache só substitui leitura em falha de rede e sinaliza dados salvos. Não há promessa de offline-first ou restauração automática de exportações.

## Autenticação e assinaturas

Produção não abre conta local silenciosamente se Firebase falhar. Demo `PAGO_DEMO=true` usa dados fictícios locais. Recuperação de senha não revela existência de conta.

Compras nativas só inicializam em Android/iOS, sem interferir na abertura web. Compra só é concluída após validação. Backend recusa falha de verificação Google, vincula titularidade e preserva concessões administrativas válidas. Renovação/reembolso consideram origem e período. DeletedAccounts impede recriação após exclusão; registros financeiros retidos precisam de política de retenção. MmpOutbox recebe atribuição configurada e retry agendado, com entrega pelo menos uma vez. Ver `functions/README.md`.

Lembretes: resumo único todo dia às 9h (Brasília, fixo para todos), enviado pelo servidor (`sendDailyReminders`, FCM). O texto leva só contagens de cobranças (hoje, amanhã, atraso), boletos (Premium) e contatos combinados; nunca nome, valor ou PIX. O aparelho se registra em `Devices` por `registerDevice` (`/api/devices/register`) depois que o usuário permite notificações (oferta após o primeiro lançamento e chave em Configurações); só quando o servidor confirma o registro o app deixa de agendar avisos locais, evitando duplicidade. Sem confirmação, valem os avisos locais abaixo. Envio idempotente por usuário e dia (`RemindersSent`), tokens inválidos são apagados. Android validado em teste; iOS exige chave APNs no Firebase e capacidade Push no Xcode (pendente). Avisos locais: abrem a tela do app, sem envio automático de WhatsApp. Datas de acompanhamento são opcionais, desligadas por padrão e pedem permissão somente quando ativadas; o aviso abre a agenda. Limite conjunto de 60 notificações e janela de 14 dias, atualizados ao retomar o app. Validação em aparelho ainda necessária.

## Estado da entrega e pendências

Consultar `docs/VALIDACAO.md` para resultados e limitações. Toolchain Flutter 3.47.7/Dart 3.13.5; Functions Node 22; emulador Java 21. Versão do app mantida em 2.4.0+25 até preparar o próximo envio. APK release ARM64 compilado em 26/10 com assinatura local de teste; pacote, assinatura e alinhamento 16 KB verificados. Envio do mapa Crashlytics bloqueado pela rede foi excluído apenas da execução local. Há 81 testes Flutter, 23 de backend e 9 de regras aprovados; análise estática sem problemas.

iOS: alvo mínimo ajustado para 15.5 (ML Kit), Podfile e includes CocoaPods adicionados, delegate de notificações em primeiro plano configurado. Build nativo iOS depende de macOS/Xcode e ainda não foi executado. Ver `docs/VALIDACAO-MOBILE.md`.

Antes de lançamento: validar em aparelhos, lojas em ambiente de teste, atualização coordenada de usuários, regras e backend; revisar retenção e custos do agendamento MMP. Credenciais de loja e chaves de assinatura ficam fora do Git. Nenhuma alteração em contas de revisor/testador.

O plano em `docs/EVOLUCAO.md` é recomendação de produto. Carteira, integração bancária/PIX, bot WhatsApp, pesquisa, novos preços, experimentos de crescimento e venda do negócio não foram implementados. A base de 1.000 pagantes e 25.000 gratuitos é hipótese da conversa, não métrica verificada.
