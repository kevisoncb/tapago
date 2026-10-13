# Pagô — Contexto do sistema

Arquivo vivo. Reescrito a cada alteração. Marca: **Pagô** — frase **“E aí, pagô?”**. Site: **usepago.app**. Antes se chamava TáPago.

## Como a IA deve usar (obrigatório)

1. Ler este arquivo.
2. Código no Git × o que vive só no Console.
3. Implementar **só na `develop`**. Não commitar feature na `main`.
4. Apagar e reescrever este arquivo.
5. Produção entre PCs: `origin/main`. Desenvolvimento entre PCs: `origin/develop`.
6. Conversar com o dono em português.

## Git

- `main` — produção (Pagô, pacote `app.usepago`). Recebe a `develop` por fast-forward quando o dono testa.
- Demo do app no navegador (para ver no iPhone): https://usepago--app-demo-xn9oi95x.web.app (canal `app-demo` do site `usepago`, vence 9/nov) — `flutter build web --release --dart-define=PAGO_DEMO=true` e `firebase hosting:channel:deploy app-demo --expires 30d` com config temporária `{"hosting":{"site":"usepago","public":"build/web","headers":[{"source":"**","headers":[{"key":"Cache-Control","value":"no-cache"}]}],"rewrites":[{"source":"**","destination":"/index.html"}]}}` via `--config` (arquivo apagado depois). Com `PAGO_DEMO` (só nessa build): abre logado no João com Premium e dados de exemplo (`SeedData`), dados só no navegador. App normal não usa essa flag.
- `develop` — desenvolvimento, toda em Pagô + boletos a pagar. Site de teste é o próprio https://usepago.web.app (canais antigos `develop` e `app-demo` do site `tapago-ae948` foram apagados em 10/out).
- Só merge `develop` → `main` quando estiver pronto para produção.
- `dev` e `producao` (criadas num PC em 8/out) estão **abandonadas**: o mesmo trabalho (Pagô, boletos, parcelas) foi feito melhor na `develop`. Não usar.
- Segredos Asaas só em `.env` e `functions/.env` (gitignored).

## Marca, pacote e domínio

- Nome visível: Pagô (app, ícone, web, site, termos, privacidade, LGPD, ajuda). Frase “E aí, pagô?” no login do app e no site.
- Código todo renomeado: pacote Dart `pago_app`, classes `PagoApp`, `PagoMark`, `PagoWordmark`, `showPagoSnack`; arquivos `assets/brand/pago-*` e `site/assets/pago-*`; Functions `pago-functions`; chaves locais `pago_*`; produto Play `pago_premium_monthly`; define `PAGO_API_BASE`.
- Pacote nativo: **`app.usepago`** (Android applicationId/namespace e `MainActivity` em `kotlin/app/usepago`, bundle iOS/macOS, Linux).
- Única sobra de “tapago”: o ID do projeto Firebase `tapago-ae948` (não pode ser renomeado). A API (`apiBase`) e o webhook continuam em `tapago-ae948.web.app/api/...`, que nunca muda; o resto desse endereço só redireciona (301) para `usepago.web.app`.
- Links do app (termos, privacidade, LGPD) apontam para `https://usepago.web.app` (`AppConstants.siteOrigin`), que já está no ar. Trocar para `https://usepago.app` quando comprar e conectar o domínio.
- E-mail de contato (LGPD, exclusão, CTAs do site): `kevison.brandes@outlook.com` (pessoal do dono, vale para a Play). Trocar por `ola@usepago.app` quando o domínio e o e-mail existirem.
- Domínios livres em 9/out: `usepago.app` (escolhido), `usepago.com.br`, `eaipago.app`, `eaipago.com.br`, `pagoapp.app`, `meupago.app`. Já registrados: `pago.app`, `pago.com`, `pago.com.br`, `pagou.app`, `pagou.com.br`.

## O que o app faz agora

Caderneta digital de fiado, venda a prazo e empréstimo. Grátis ilimitado. WhatsApp sai do celular do usuário (wa.me), não de bot. Premium: voz, OCR, mensagem própria e **boletos a pagar**. R$ 39,90/mês.

Boletos a pagar (Premium, só na `develop`): o que o lojista deve ao fornecedor. À vista (vencimento + código opcional) ou parcelado (valor total + data da compra + prazos 15/30/45, 30/45/60, 30/60/90 ou personalizado; divide em centavos, sobra na última). Lista com "Parcela 1 de 3", atrasado em vermelho, copiar código, colar código depois, marcar/desmarcar pago, excluir. Lembrete às 9h: 3 dias antes, véspera, no dia e todo dia em atraso (canal Android "Boletos a pagar", `billReminderKind`). Entrada no dashboard ("Boletos a pagar", cadeado se não Premium): vermelho mostra só o valor vencido, cinza o total em aberto. Tela de boletos: card "Vencido" vermelho separado, "Vence esta semana" (sem atrasados) e "Total em aberto"; aceita filtro por fornecedor. Sem Premium: vê a lista, não cria nem edita.

Painel (dashboard): "Saldo aberto" (tudo que falta receber), "Recebe esta semana" (vence nos próximos 7 dias, sem atrasados) e "Vencido a receber" (card vermelho só com o atrasado; azul "Nada vencido a receber" quando zero). Getters `aReceberNaSemana` e `aReceberVencido` no `AppController`.

Navegação: "Pagô!" (wordmark com exclamação e setinha) e o avatar com iniciais abrem o menu (`lib/widgets/pago_menu.dart`): Caderneta, Buscar, Boletos a pagar, Novo lançamento, Premium (se grátis), Configurações. Caderneta tem abas **Clientes** (quem te deve) e **Boletos** (empresas/fornecedores com aberto e vencido; toque abre os boletos daquela empresa). Configurações é só do app (conta, PIX, banco, mensagem, preferências, assinatura, ajuda); não lista mais contatos. Descrições mostram o real: chave PIX cadastrada, nome do banco, biometria ligada/desligada (bloqueio em `lib/widgets/biometric_lock.dart`; `MainActivity` é `FlutterFragmentActivity`, exigido pelo `local_auth`; celular sem digital/rosto/senha de tela não fica bloqueado); a prévia da mensagem usa a chave PIX do usuário. Ajuda: no site (`/ajuda` + menu) e no app (Configurações → Ajuda) o botão abre o WhatsApp de suporte, sem número na tela.

Conta: "Sair da Conta" desloga de verdade (`AppController.signOut` cancela os lembretes e chama `SessionGate.signOut`). **"Excluir minha conta"** (vermelho, no fim das Configurações; exigência da Play): pede a senha, reautentica no Firebase, chama `POST /api/account/delete` (Function `deleteMyAccount`, exige login feito há menos de 5 min) que reaproveita a exclusão do painel (apaga Debts, Payments, Bills, PremiumCharges, AdminNotes, AdminContacts, Users, Presence e o login; registra "excluiu a própria conta pelo app" no `AdminLog`), limpa as chaves `pago_{uid}_*` do aparelho e sai. Assinante vê aviso para cancelar na Play. Página pública https://usepago.web.app/excluir-conta (`site/excluir-conta.html`), citada na privacidade, ajuda e termos.

Relatório de travamentos: Firebase Crashlytics (`lib/services/crash_reporter.dart`, ligado no `FirebaseBootstrap`, só Android/iOS em release; grava o uid). Plugin Gradle `com.google.firebase.crashlytics` 3.0.6. Citado na privacidade.

Ícone: check branco com pontinho sobre azul `#2F6BFF` (desenho do `assets/brand/pago-icon.jpg`). Ícone adaptativo do Android com o símbolo dentro da zona segura (sem quadrado dentro do círculo); `assets/brand/pago-icon.png` 1024. Gerados por script `sharp` (fora do repo).

iPhone (preparação, sem conta Apple ainda; será conta **Individual**, sem D-U-N-S/CNPJ): plano em 3 fases, cada uma só com autorização do dono. **Fase 3 feita (13/out, na develop, em revisão, ainda não publicada)**: `functions/apple.js` com a biblioteca oficial `@apple/app-store-server-library` 3.1.0 e as raízes públicas da Apple em `functions/certs/` (G3, G2, Apple Inc. Root; conferidas pela impressão digital). `confirmApplePurchase` (`POST /api/apple/confirm`, exige login): com credenciais busca a transação na App Store Server API (`getTransactionInfo`, Produção e depois Sandbox); sem credenciais ou com a Apple fora do ar confere o JWS que o app mandou; verifica assinatura/cadeia/bundle/ambiente (`SignedDataVerifier`, OCSP ligado), produto `pago_premium_monthly_ios`, dono (`appAccountToken` = UUID v5 do uid, recalculado no servidor por `accountTokenFor`; teste Dart garante o mesmo valor do Node) e se está ativa (402 se não). `appleNotifications` (`POST /api/apple/notifications`, sem login; autenticidade só pelo JWS `signedPayload`): SUBSCRIBED, DID_RENEW, EXPIRED, GRACE_PERIOD_EXPIRED, REFUND, REVOKE, DID_FAIL_TO_RENEW, DID_CHANGE_RENEWAL_STATUS; ignora notificação mais velha que a gravada (fora de ordem); desligar o Premium só mexe no usuário se o Premium atual for desta assinatura (`premium_transaction_id = apple_<originalTransactionId>`, painel mostra "App Store"). Eventos vão para `PlayEvents` com `loja: "app_store"` (Sandbox = teste, fora da receita) e alertas por e-mail iguais aos da Play. Erro interno responde 500 para a Apple reenviar. Variáveis em `functions/.env` (process.env, não quebram o deploy se faltarem): `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` (.p8 em PEM com `\n` ou base64), `APPLE_APP_ID` (sem ele só aceita Sandbox), `APPLE_BUNDLE_ID` (padrão `app.usepago`). Rewrites novas em `firebase.json`. **Fase 2 feita**: compra por loja em `lib/services/store_ids.dart` (`StoreKind` googlePlay/appStore; produto Android `pago_premium_monthly`, iOS `pago_premium_monthly_ios` = `AppConstants.premiumProductIdIos`, tem que ser igual ao criado no App Store Connect); `billing_purchase_io.dart` decide a loja por `Platform.isIOS` e no iPhone manda `appAccountToken` = UUID v5 do uid (`appAccountTokenFor`; StoreKit 2 só aceita UUID; o servidor recalcula para saber a conta). `in_app_purchase_storekit` 0.4.13 declarado; StoreKit 2 é o padrão e o pacote se registra sozinho (`enableStoreKit2` está obsoleto). `BillingService.restorePurchases()` espera a resposta da loja (12 s sem resposta = "Nenhuma assinatura ativa encontrada") e `priceLabel()` traz o preço da loja. `AppController.restorePremium()`, `restoringPurchases`, `storePriceLabel`, `store`; compra no iPhone vai para `AsaasClient.confirmApplePurchase` (`POST /api/apple/confirm`, Fase 3). Tela Premium: "Pagô Premium · Assinatura mensal", preço da loja, aviso de renovação automática (`premiumRenewalNotice`, diretriz 3.1.2), botão grande "Restaurar Compras", links "Termos de Uso · Política de Privacidade". Excluir conta mostra onde cancelar conforme a loja. Termos e privacidade (app e site) citam Google Play e App Store. **Fase 1 feita**: `ios/Runner/Info.plist` com `NSFaceIDUsageDescription`, `NSUserTrackingUsageDescription` (ATT) e texto da câmera sem jargão; `lib/services/tracking_service.dart` (`TrackingService.instance.requestIfNeeded()`, pacote `app_tracking_transparency`), chamado depois do login no `SessionGate`, mas **desligado** por `AppConstants.trackingEnabled` (`--dart-define=PAGO_ATT=true`): só ligar quando houver SDK de anúncio/atribuição e a ficha da App Store e a privacidade declararem rastreamento, senão a Apple reprova. iOS não compila neste PC (Windows); precisa de Mac na nuvem (Codemagic/GitHub Actions).

## Painel do administrador

- Endereço: https://pago-admin.web.app (site Hosting separado `pago-admin`; não vai no app). Conta admin: `pago@administrador.com` (senha só com o dono; trocar pelo botão "Trocar senha" do painel).
- Conta de teste do painel: `teste@administrador.com` (também admin; senha com o dono). Para tirar: remover de `ADMIN_EMAILS`, publicar `functions:adminApi` e apagar o login no Authentication.
- Quem é admin: `ADMIN_EMAILS` em `functions/.env` (gitignored, separado por vírgula). A conta já foi criada para ninguém pegar o e-mail antes.
- Abas: **Visão geral**, **Pessoas**, **Registro**. Avisos no topo quando o segundo fator está desligado ou o e-mail não está configurado.
- Visão geral: cards (online agora, ativos 24h/7d/30d, cadastros, Premium pagantes × cortesia, receita do mês da Play com líquido, ou estimada se ainda não houver cobrança; Premium vencendo em 7 dias). **Precisa de atenção** com três abas: Premium sumido (Premium ativo sem abrir há 7+ dias), Prontos para Premium (grátis com 10+ lançamentos e acesso em 7 dias, ou Premium vencido há até 30 dias; botão "Dar 7 dias") e Travou no começo (conta de 1 a 30 dias sem lançamento); "Chamar no WhatsApp" com mensagem pronta assinada "Kevison, do Pagô!" (sem telefone vira e-mail) e "Já chamei" (salvo no servidor em `AdminContacts`, tira da fila por 7 dias, vale em qualquer aparelho). **Receita da Google Play** (este mês × passado: bruto, líquido sem 15%, novas, renovações, cancelamentos, pagamentos recusados; compras de teste fora). **Mês a mês** (cadastros no mesmo período; Premium, pagantes, ativos e usuários contra a foto de 30 dias atrás em `AdminStats`, gravada a cada abertura do painel e todo dia às 8h; comparação aparece a partir de 9/nov). **Funil** cumulativo (conta → 1º lançamento → 5 lançamentos → abriu em 7 dias → assinou), todos ou cadastros de 30 dias. **Retenção** por semana de cadastro (8 semanas: lançaram, voltaram após 7 e 30 dias, pelo último acesso). Gráfico de cadastros 14 dias e **Últimos acontecimentos** (cadastros + eventos da Play).
- Pessoas: lista com filtros e busca; clicar no nome abre a **ficha**: dados, WhatsApp, cadastro/último acesso, lançamentos (em aberto), pagamentos, boletos, lançamentos por mês (6 meses), o que configurou (PIX, banco, mensagem, lembretes, biometria), Premium (dar/somar/tirar/excluir), assinatura da Play (estado, validade, renovação), histórico (eventos da Play + ações do admin) e **anotações internas** (`AdminNotes`, salvar/apagar).
- Registro: últimas 150 ações do painel (`AdminLog`: Premium dado/tirado, exclusão, anotação, chamado, segundo fator), com quem fez e quando.
- **Exportar planilha**: CSV (separador `;`, abre no Excel) com todos os usuários e números.
- **Segundo fator (TOTP)**: botão "Segurança" gera QR para Google/Microsoft Authenticator; depois de ligado, toda chamada exige o código (sessão de 12 h no navegador, 5 erros bloqueiam 15 min). Segredo em `AdminSecurity/{uid}` (só servidor). Perdeu o celular: apagar esse documento no console do Firestore. Ainda **desligado** na conta do dono.
- **Resumo diário por e-mail** (`adminDailyDigest`, 8h de Brasília: cadastros e cobranças de ontem, perdas, receita do mês, contagens de atenção) e **alertas na hora** (nova assinatura, cancelamento, pagamento recusado, estorno, expiração; vindos de `playNotifications`/`confirmPlayPurchase`). Envio pelo Resend; **desligado** até trocar `RESEND_API_KEY=off` pela chave `re_...` em `functions/.env` e publicar as functions. Destino `ALERT_EMAIL` (kevison.brandes@outlook.com), remetente `onboarding@resend.dev` (no plano grátis do Resend só entrega para o e-mail da própria conta Resend).
- Ações: dar 7/30/90/365 dias (soma se já for Premium; `premium_transaction_id = admin_<dias>d_<ts>`), tirar Premium, excluir conta (apaga Debts, Payments, Bills, PremiumCharges, AdminNotes, AdminContacts, Users, Presence e o login; pede EXCLUIR; admin não pode ser excluído). Tudo vai para o Registro.
- Não mostra a caderneta (clientes e valores) das pessoas: só contagens.
- Código: `admin/` (HTML/CSS/JS, Firebase Auth web via CDN, QR via jsdelivr `qrcode`), `functions/admin.js` (`adminApi` em `https://southamerica-east1-tapago-ae948.cloudfunctions.net/adminApi`: GET `/overview`, `/user?uid=`, `/log`, `/2fa/status`; POST `/premium`, `/revoke`, `/delete`, `/note`, `/note/delete`, `/contacted`, `/2fa/setup|enable|verify|disable`), `functions/totp.js`, `functions/alerts.js`. Publicar painel: `firebase deploy --only hosting --config firebase.admin.json`.
- `functions/.env` (gitignored) precisa ter: `ADMIN_EMAILS`, `ASAAS_API_KEY`, `ASAAS_BASE_URL`, `ASAAS_WEBHOOK_TOKEN`, `RESEND_API_KEY`, `ALERT_EMAIL`, `ALERT_FROM`. Sem eles o deploy não roda (modo não interativo) ou o painel recusa todos.
- Online: `lib/services/presence_service.dart` grava `Presence/{uid}` ao entrar e a cada 5 min com o app aberto (só quando usa Firebase). Só funciona com a versão do app que tem isso (develop em diante).

## Mapa

- `lib/screens/auth_page.dart` — login e cadastro (aceite de termos), nome + “E aí, pagô?”.
- `lib/screens/dashboard_page.dart` — saldo aberto, recebe na semana, vencido a receber, boletos, lista, FAB, ícone WhatsApp.
- `lib/screens/add_debt_page.dart` — lançamento, voz Premium, duplicata bloqueada.
- `lib/screens/client_profile_page.dart` — Abater, OCR, Lembrete / Cobrar hoje / Atraso.
- `lib/screens/caderneta_page.dart` / `contact_history_page.dart` — pessoas e histórico.
- `lib/screens/settings_page.dart` — PIX, banco, mensagem, preferências, Premium, Ajuda, Sair, Excluir minha conta.
- `lib/services/session_gate.dart` — login, cadastro, sair, `deleteAccount`. `lib/services/crash_reporter.dart` — Crashlytics.
- `lib/widgets/pago_menu.dart` — menu do "Pagô!" / avatar.
- `lib/screens/premium_page.dart` — benefícios e botão único "Assinar Premium" (assinatura Google Play), "Restaurar". Sem PIX no app.
- `lib/screens/bills_page.dart` / `add_bill_page.dart` — boletos a pagar. `lib/services/bill_installments.dart` — divisão de parcelas, prazos, código.
- `lib/widgets/pago_logo.dart` — marca. `lib/utils/constants.dart` — nome, frase, links, API.
- `site/` — landing, planos, termos, privacidade, LGPD, ajuda.
- `functions/index.js` — webhook Asaas, PIX (sem uso), `confirmPlayPurchase`, `playNotifications`. `functions/play.js` — consulta da assinatura na Google e eventos. `functions/apple.js` — compra e notificações da App Store (`confirmApplePurchase`, `appleNotifications` no `index.js`). `functions/admin.js` — API do painel + resumo diário.
- `admin/` — painel do administrador (site `pago-admin`).

## Dados

Conta ao vivo: com Firebase, o app escuta `Users/{uid}` em tempo real (`watchCurrentUser` no repositório; `AppController._watchUser` depois do `load`). Premium dado ou tirado pelo painel (ou pela Play no servidor) aparece na hora, sem reabrir o app; lembretes de boleto são refeitos quando o Premium muda.

Firestore: `Users`, `Debts`, `Payments`, `Bills`, `PremiumCharges`, `Presence` (sinal de uso; dono só grava `last_seen_at` = hora do servidor e `plataforma`; ninguém lê pelo app). Só servidor (regra geral nega o app): `PlaySubscriptions` (id = hash do token da compra; uid, estado, vence, pedido, valor, conferida), `PlayEvents` (id = pedido para cobranças, evita contar duas vezes; tipo COMPRA/RENOVADA/CANCELADA/...; da Apple com id `apple_<transactionId>` e `loja: "app_store"`), `AppleSubscriptions` (id = originalTransactionId; uid, appAccountToken, estado, vence, revogada, valor, moeda, teste), `AdminStats` (foto diária), `AdminLog`, `AdminNotes`, `AdminContacts`, `AdminSecurity`. Regras publicadas. `Bills`: dono lê/apaga; criar/editar exige `is_premium` + `premium_vence_em` futuro (regras já publicadas no projeto, aditivas). Saldo no ledger. Sem bot WhatsApp. Sem offline-first.

## Feito

- Caderneta, dashboard, WhatsApp wa.me com PIX, lembretes (véspera, dia, atraso).
- Premium 39,90: voz, OCR no celular, texto próprio.
- Auth e-mail/senha, Firestore, Functions, webhook Asaas. Asaas no CNPJ.
- Ajuda no site e no app: mesmo WhatsApp, só no clique.
- Rename total TáPago → Pagô na `develop`, apps Firebase novos `app.usepago` com configs baixadas.
- Boletos a pagar (Premium) na `develop`, com benefício na tela Premium e na privacidade. No site: seção própria `#boletos` (mock da lista com parcelas, código, prazos), link “Boletos” no menu, notificação de boleto em Avisos e item no plano Premium. Testes: 20 passando.

## Parcial

- `main` = `develop` desde 10/out (Pagô, `f0fb629`). Na internet não sobra nada TáPago: `tapago-ae948.web.app` redireciona para `usepago.web.app`.
- Premium só pela Google Play (assinatura `pago_premium_monthly`, cobrada na conta Google do usuário). PIX saiu do app e do site; o Asaas fica só como conta bancária que recebe o repasse da Google (cadastrar os dados bancários do Asaas no perfil de pagamentos da Play Console). As Functions `createPremiumPix`/`premiumPixStatus` e o webhook continuam publicados, sem uso pelo app. Compra: o app manda o uid como `applicationUserName` (vira `obfuscatedExternalAccountId`) e envia o token da compra para `confirmPlayPurchase`, que consulta a assinatura na Android Publisher API (`subscriptionsv2`), recusa se for de outra conta ou inativa e grava a validade real. Sem token: 400 (fechou o furo de qualquer um ganhar 30 dias). **Se a API da Google ainda não tiver acesso, libera 30 dias sem conferir** e marca `verificada: false`. Renovação/cancelamento: `playNotifications` (Pub/Sub, tópico `play-billing`, já criado no deploy) atualiza `Users` e `PlayEvents`. Falta ligar do lado da Google (ver Pendências).
- Play: conta de desenvolvedor **aprovada em 12/out**. Chave de upload (`android/app/upload-keystore.jks`, alias `upload`, senhas em `android/key.properties`; os dois gitignored, cópia na Área de Trabalho em `Pago-Play`). AAB atual **`2.4.0+25`** (com excluir conta, Crashlytics e ícone novo), assinado: `Pago-Play\pago-2.4.0-25.aab`. Material da loja em `Pago-Play\loja`: `icone-512.png`, `destaque-1024x500.png`, `prints-celular-9x16\1..4` (1350×2400) e `prints-tablet-9x16\1..4` (1440×2560, fundo azul), conta do revisor (a Play só aceita 16:9 ou 9:16; `prints\` 1200×2400 é a origem), e `textos-play-console.md` (ficha, acesso ao app, segurança dos dados, classificação, público, app financeiro, URLs). Gerar AAB: `flutter build appbundle --release` (precisa do NDK `28.2.13676358`, instalado via `cmdline-tools\latest\bin\sdkmanager`). Cada envio novo: subir o número depois do `+` em `pubspec.yaml`.
- Conta do revisor do Google: `revisao.google@usepago.app` ("Mercadinho Revisão", senha no `textos-play-console.md`, fora do git), Premium até out/2027 dado pelo painel, 7 clientes, 3 pagamentos e 5 boletos de exemplo. Não excluir nem tirar o Premium enquanto o app estiver em revisão.
- Conta compartilhada para os testadores da Play: `testador@usepago.app` ("Loja Teste", uid `abPuU5lb7tTXVQqOKcsNtIu0E042`, criada em 13/out, Premium até 14/out/2027 dado pelo painel; senha só com o dono, fora do git). Mesmo projeto Firebase, vale para o app da `main` e da `develop`. Todos que usam veem os mesmos dados.
- Flutter SDK em `C:\Users\kevis\flutter` (PATH do usuário e `android/local.properties`). Saiu de `AppData\Local\Temp\flutter` porque a limpeza automática do Windows apagou arquivos dele.
- Emulador: o app instalado agora é assinado com a chave de upload; um APK assinado com a chave de debug não instala por cima (precisa desinstalar).
- CTAs do site ainda `mailto:` (e-mail pessoal do dono).
- Avisos antigos do analyzer em `app_controller.dart` e `receipt_reader_io.dart` (estilo, não quebram).

- Boletos: compila e abre no emulador Android (`Medium_Phone_API_37.0`); fluxo ainda não testado à mão. Sem leitura de código pela câmera.
- Emulador neste PC (16 GB): a imagem API 37 Play Store trava ("system isn't responding") se o Gradle (`java`, ~2,5 GB) e um `flutter run` debug ficam ligados. Para testar: `flutter build apk --release`, matar `java`, ligar o emulador com `-no-snapshot -gpu host`, animações em 0 e `adb install -r build\app\outputs\flutter-apk\app-release.apk`.
- `android/app/build.gradle.kts`: `import java.util.Properties` / `java.io.FileInputStream` no topo (inline não compila no Gradle 9); release usa `proguard-rules.pro` com `-dontwarn` dos idiomas não usados do ML Kit (chinês, japonês, coreano, devanágari) — sem isso o R8 barra o APK/AAB release. `/android/build/` no `.gitignore`.

## Ideias (só discutidas)

- Parcelamento a receber em 1 clique (Premium): 15/30/45 ou 30/45/60, bloco único, WhatsApp “parcela 1 de 3”. Próxima novidade, depois do lançamento.
- Versão iPhone: depois de validar no Android (conta Apple US$ 99/ano).

## Recomendação combinada (9/out)

Congelar novidades e lançar: 1) Play com assinatura `pago_premium_monthly` + validar renovação no servidor (notificações da Play); 2) cobrar só pela Play (feito: PIX removido); 3) comprar e ligar `usepago.app`, trocar CTAs `mailto:`; 4) Crashlytics antes de publicar; 5) teste fechado com 5–10 lojistas reais; 6) `develop` vira a próxima produção (não publicar a `main` antiga).

## Faltando

- Comprar `usepago.app` (e `usepago.com.br`), conectar no Firebase Hosting, criar `ola@usepago.app` e trocar o e-mail pessoal por ele.
- Ficha da Play com nome Pagô e pacote `app.usepago` (o pacote antigo nunca foi publicado).
- Play (12/out): app criado, ficha e formulários preenchidos (categoria Empresa; tags Empresa, Finanças, Produtividade, Bloco de notas, Agenda), AAB 25 no **teste interno** (instalado pela loja e testado no emulador) e no **teste fechado Alpha** (publicado). Produção bloqueada até ter **12 testadores aceitos por 14 dias** (hoje 0). A proteção automática da Play bloqueia APK instalado fora da loja ("Get this app from Play").
- Site público: publicar sempre no site `usepago` (`firebase.usepago.json`); o site padrão fica só com API + redirecionamento.
- Criar a assinatura `pago_premium_monthly` (R$ 39,90/mês) na Play Console e testar com conta de teste de licença.
- Bot WhatsApp: **futuro, não implementar**.

## Firebase / Console

- Projeto `tapago-ae948`, Blaze. Hosting padrão https://tapago-ae948.web.app (e `.firebaseapp.com`): só API + redirecionamento. `firebase.json` publica a pasta `hosting-redirect/` com `redirects` 301 para `usepago.web.app` (termos, privacidade, LGPD, ajuda vão para a mesma página; o resto para a home) e mantém as rewrites `/api/**` para as Functions. Publicar: `firebase deploy --only hosting` (sem functions). **Nunca publicar o hosting a partir da `main` antiga**: traria o site TáPago de volta.
- Apps: Android `app.usepago` (`1:1077428127080:android:53dca34d493288510042dd`) e iOS/macOS `app.usepago` (`1:1077428127080:ios:577755df013cd6380042dd`). Apps antigos `com.tapago...` continuam registrados enquanto a `main` usar.
- Functions (southamerica-east1): `asaasWebhook`, `createPremiumPix`, `premiumPixStatus`, `confirmPlayPurchase`, `deleteMyAccount` (rewrite `/api/account/delete` no `firebase.json`), `playNotifications` (Pub/Sub `play-billing`), `adminApi`, e na develop ainda não publicadas `confirmApplePurchase` (`/api/apple/confirm`) e `appleNotifications` (`/api/apple/notifications`; URL para o App Store Connect: `https://tapago-ae948.web.app/api/apple/notifications`, Versão 2, Produção e Sandbox), `adminDailyDigest` (agendada 8h). Publicar: `firebase deploy --only functions --project tapago-ae948 --force`.
- Hosting sites: `tapago-ae948` (API/webhook + redirecionamento para o Pagô; nenhum canal de preview), `usepago` (site Pagô da develop no ar: https://usepago.web.app — `pago.web.app` é de outro projeto) e `pago-admin` (painel admin).
- Publicar o site Pagô: `firebase deploy --only hosting --config firebase.usepago.json`. Quando comprar `usepago.app`, conectar o domínio no site `usepago`.
- Web app do Firebase: "Default Web App" `1:1077428127080:web:e82621d06da4bf5c0042dd` (usado só pelo painel).
- Webhook: `https://tapago-ae948.web.app/api/webhooks/asaas`
- Auth: e-mail/senha. Asaas: CNPJ.

## Pendências do dono

1. Comprar `usepago.app` / `usepago.com.br`.
2. Play Console: juntar 12+ testadores Android (Gmail) no teste fechado Alpha, mandar o link de inscrição e manter 14 dias seguidos; depois "Solicitar a produção" e responder as perguntas sobre o teste. Guardar cópia da chave de upload (`upload-keystore.jks` + `key.properties`) fora do PC.
3. Próximas idas da `develop` para a `main` quando testar.
4. Play Console: perfil de pagamentos com a conta bancária do Asaas (CNPJ) para receber o repasse da Google.
5. Trocar a senha provisória do painel admin ("Trocar senha") e ligar o segundo fator (botão "Segurança").
6. Resumo e alertas por e-mail: criar conta grátis no resend.com com kevison.brandes@outlook.com, gerar API key, colocar em `RESEND_API_KEY` no `functions/.env` e publicar as functions.
7. Quando tiver a conta Apple Individual: criar o app `app.usepago` e a assinatura `pago_premium_monthly_ios` (R$ 39,90/mês, grupo de assinatura); em Usuários e acesso → Integrações → Compra dentro do app gerar a chave (.p8, baixa uma vez só) e anotar Key ID e Issuer ID; pôr `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_APP_ID` em `functions/.env`; publicar functions + hosting padrão (rewrites); em Informações do app → Notificações do servidor da App Store colar a URL `/api/apple/notifications` (Versão 2) em Produção e Sandbox e "Solicitar notificação de teste".
8. Receita real da Play (depois do app publicado): no Google Cloud do projeto, ativar a "Google Play Android Developer API"; na Play Console → Usuários e permissões, convidar a conta de serviço das Functions (`1077428127080-compute@developer.gserviceaccount.com`) com permissão de ver dados financeiros e gerenciar pedidos/assinaturas; na Play Console → Monetização → Notificações em tempo real, tópico `projects/tapago-ae948/topics/play-billing`, e no Pub/Sub dar ao `google-play-developer-notifications@system.gserviceaccount.com` o papel de Publicador nesse tópico. Depois "Enviar notificação de teste".

## Última sessão (13/out)

iPhone fases 1, 2 e 3 na develop (commits `30e7e9b`, `3544488` e o da Fase 3). Fase 3 validada localmente: `index.js` carrega, JWS falso recusado (400), corpo vazio 400, UUID v5 igual no Node, no pacote `uuid` e no Dart; 22 testes Flutter. Functions da Apple ainda não publicadas (aguardam revisão do dono). npm portátil (`%TEMP%\tapago-node`) estava quebrado pela limpeza do Windows; reparado regravando o pacote `npm` 11.19.0.

## Sessão anterior (10–12/out)

Preparação para a Play: excluir conta no app + Function + página no site (testado: API sem login 401, com login apaga perfil e login; senha errada no app mostra "Senha incorreta."), "Sair da Conta" consertado, Crashlytics, ícone adaptativo refeito, versão 25, conta do revisor com dados, prints, ícone 512, destaque e textos da loja. Biometria consertada (`FlutterFragmentActivity`) e Premium do painel aparecendo na hora no app (escuta `Users/{uid}`). Flutter movido para `C:\Users\kevis\flutter`. 20 testes passando.
