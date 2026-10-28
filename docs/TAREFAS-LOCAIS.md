# Tarefas para sessão local (Claude Desktop, no PC do dono)

Cole cada bloco como primeira mensagem de uma sessão **local** (pasta do projeto clonada, branch `develop`). Em sessão local o Claude alcança o seu emulador Android, o seu login do Firebase e as variáveis de produção que não estão no Git.

## 1. Testar o app no emulador e corrigir problemas

Contexto: projeto Pagô (Flutter + Firebase), repositório kevisoncb/tapago, branch `develop` (NÃO mexer na `main`, que é produção). Converse em português. Leia primeiro SISTEMA.md, README.md e docs/STATUS-PRODUTO.md.

Objetivo: rodar o app no emulador Android deste PC, testar os fluxos e corrigir o que estiver quebrado ou feio, direto na `develop`, com commits pequenos.

1. Garanta Flutter 3.47.7 / Dart 3.13.5. Rode `flutter pub get --enforce-lockfile`, `flutter analyze` e `flutter test` (devem passar: análise limpa e cerca de 100 testes).
2. Abra um emulador Android (de preferência Android 13+ com Google Play) e rode `flutter run -d <emulador>`.
3. Use SOMENTE uma conta de teste. O app fala com o Firebase de PRODUÇÃO (projeto tapago-ae948). Nada de clientes reais. Ao final, apague a conta de teste pelo app (Mais > Excluir minha conta).
4. Percorra e tire capturas com `adb exec-out screencap -p`: abertura animada; cadastro e login; tela Hoje ("Meu dia"); novo lançamento (campos mostram exemplo, não o rótulo repetido); lançamento parcelado (Premium, vencimento no mesmo dia dos meses seguintes); pagamento parcial, quitação e correção com motivo; cobrança pelo WhatsApp; extrato PDF/CSV; relatórios; acompanhamentos; boleto atrasado deve dizer "Venceu em"; diálogo "Receber o resumo das 9h?" depois do primeiro lançamento; texto ampliado e modo escuro.
5. Limitações esperadas: compra do Premium só funciona com a Play real; o push das 9h depende das Functions registerDevice/sendDailyReminders, que ainda NÃO estão publicadas (os lembretes locais continuam valendo); as regras novas do Firestore (ledger de pagamentos) ainda NÃO foram publicadas, então gravar pagamento/estorno pode ser recusado. Se isso ocorrer, anote a mensagem exata e NÃO publique regras sem pedir autorização.
6. Para cada problema: reproduza, corrija, rode analyze e testes, commite e envie para a `develop`. Registre o que ficou pendente.

Pronto quando: fluxos principais funcionam no emulador, analyze e testes passam e as capturas e uma lista curta de achados foram entregues.

## 2. Publicar Functions, índices e rotas novas

Contexto: projeto Pagô, repositório kevisoncb/tapago, branch `develop`, projeto Firebase `tapago-ae948`, região das Functions `southamerica-east1`. Converse em português. A sessão roda NO PC do dono, com o Firebase CLI logado na conta dele. Leia SISTEMA.md e functions/README.md.

Objetivo: publicar com segurança as Functions e configurações novas, pedindo confirmação do dono antes de cada deploy.

Publicar somente:
- Functions: adminApi, adminDailyDigest, registerDevice, sendDailyReminders, registerAcquisition.
- Índices: `firebase deploy --only firestore:indexes`.
- Hosting do projeto principal (firebase.json) para as rotas /api/devices/register e /api/acquisition/register.

NÃO publicar sem decisão explícita do dono: confirmPlayPurchase, deleteMyAccount, confirmApplePurchase, appleNotifications, createPremiumPix, premiumPixStatus, asaasWebhook, playNotifications, retryMmpRevenue e as regras do Firestore (dependem da sequência de docs/financial-data-rollout.md). O backend da Apple não foi configurado.

Cuidados críticos:
1. As Functions de produção usam variáveis que NÃO estão no Git: ADMIN_EMAILS, ASAAS_API_KEY, ASAAS_WEBHOOK_TOKEN, ASAAS_BASE_URL, RESEND_API_KEY, ALERT_EMAIL, ALERT_FROM. Um deploy sem elas as remove e trava o painel admin (403 para todos) e os e-mails. Confira que existem em functions/.env (ignorado pelo Git) ou functions/.env.tapago-ae948 ANTES de publicar. Nunca imprima nem comite valores de segredos.
2. Defina ADMIN_REQUIRE_2FA="false" (o painel exigiria autenticador se fosse "true"; o dono ainda não tem autenticador).
3. Rode `npm ci` e `npm test` em functions/ (devem passar 32 testes) antes de publicar.
4. Publique com `firebase deploy --only functions:adminApi,functions:adminDailyDigest,functions:registerDevice,functions:sendDailyReminders,functions:registerAcquisition --project tapago-ae948`, depois índices e Hosting.
5. Depois: `firebase functions:list`; chame adminApi sem login (deve dar 401); confira nos logs o agendamento das 9h (America/Sao_Paulo); abra https://pago-admin.web.app e confira Receita, Análise e Marketing.
6. Se quebrar o painel, reverta publicando a versão anterior e avise o dono.

Lembrar o dono: apagar as chaves de conta de serviço antigas (deploy-site-claude e claude-dev) em Google Cloud > IAM > Contas de serviço, pois foram coladas em conversa.

Pronto quando: funções publicadas e listadas, painel funcionando, índices criados e rotas respondendo, sem alterar funções de compra nem regras.
