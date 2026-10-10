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

- `main` — produção (ainda TáPago, pacote `com.tapago.tapago_app`). Origin: `c75f224`.
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

Navegação: "Pagô!" (wordmark com exclamação e setinha) e o avatar com iniciais abrem o menu (`lib/widgets/pago_menu.dart`): Caderneta, Buscar, Boletos a pagar, Novo lançamento, Premium (se grátis), Configurações. Caderneta tem abas **Clientes** (quem te deve) e **Boletos** (empresas/fornecedores com aberto e vencido; toque abre os boletos daquela empresa). Configurações é só do app (conta, PIX, banco, mensagem, preferências, assinatura, ajuda); não lista mais contatos. Descrições mostram o real: chave PIX cadastrada, nome do banco, biometria ligada/desligada; a prévia da mensagem usa a chave PIX do usuário. Ajuda: no site (`/ajuda` + menu) e no app (Configurações → Ajuda) o botão abre o WhatsApp de suporte, sem número na tela.

## Painel do administrador

- Endereço: https://pago-admin.web.app (site Hosting separado `pago-admin`; não vai no app). Conta admin: `pago@administrador.com` (senha só com o dono; trocar pelo botão "Trocar senha" do painel).
- Quem é admin: `ADMIN_EMAILS` em `functions/.env` (gitignored, separado por vírgula). A conta já foi criada para ninguém pegar o e-mail antes.
- Mostra: online agora (sinal nos últimos 5 min), ativos 24h/7d/30d, cadastros e novos 7d, gráfico de cadastros 14 dias, Premium ativos (pagantes × cortesia), receita estimada (pagantes × 39,90), Premium vencendo em 7 dias. Lista com nome, e-mail, telefone, cadastro, último acesso, plataforma, plano/origem (Play, PIX, cortesia) e números de uso (lançamentos, pagamentos, boletos). Filtros e busca. Admins ficam fora das contagens.
- "Precisa de atenção" (calculado no navegador com os dados do `/overview`, sem mudar a API), três abas com contagem: **Premium sumido** (Premium ativo sem abrir há 7+ dias), **Prontos para Premium** (grátis com 10+ lançamentos e acesso nos últimos 7 dias, ou Premium vencido há até 30 dias; botão "Dar 7 dias") e **Travou no começo** (conta de 1 a 30 dias sem lançamento). Cada pessoa tem "Chamar no WhatsApp" (wa.me com mensagem pronta assinada "Kevison, do Pagô!"; sem telefone vira e-mail) e "Já chamei", que tira da fila por 7 dias (guardado no `localStorage` do navegador do admin, não sincroniza entre aparelhos).
- Ações: dar 7/30/90/365 dias (soma se já for Premium; grava `premium_transaction_id = admin_<dias>d_<ts>`; o app desliga sozinho pela data), tirar Premium, excluir conta (apaga Debts, Payments, Bills, PremiumCharges, Users, Presence e o login; pede digitar EXCLUIR; admin não pode ser excluído).
- Não mostra a caderneta (clientes e valores) das pessoas: só contagens.
- Código: `admin/` (HTML/CSS/JS com Firebase Auth web via CDN, app web "Default Web App"), `functions/admin.js` (`adminApi`, chamado direto em `https://southamerica-east1-tapago-ae948.cloudfunctions.net/adminApi`). Publicar painel: `firebase deploy --only hosting --config firebase.admin.json`.
- Online: `lib/services/presence_service.dart` grava `Presence/{uid}` ao entrar e a cada 5 min com o app aberto (só quando usa Firebase). Só funciona com a versão do app que tem isso (develop em diante).

## Mapa

- `lib/screens/auth_page.dart` — login e cadastro (aceite de termos), nome + “E aí, pagô?”.
- `lib/screens/dashboard_page.dart` — saldo aberto, recebe na semana, vencido a receber, boletos, lista, FAB, ícone WhatsApp.
- `lib/screens/add_debt_page.dart` — lançamento, voz Premium, duplicata bloqueada.
- `lib/screens/client_profile_page.dart` — Abater, OCR, Lembrete / Cobrar hoje / Atraso.
- `lib/screens/caderneta_page.dart` / `contact_history_page.dart` — pessoas e histórico.
- `lib/screens/settings_page.dart` — PIX, banco, mensagem, preferências, Premium, Ajuda.
- `lib/widgets/pago_menu.dart` — menu do "Pagô!" / avatar.
- `lib/screens/premium_page.dart` — benefícios e botão único "Assinar Premium" (assinatura Google Play), "Restaurar". Sem PIX no app.
- `lib/screens/bills_page.dart` / `add_bill_page.dart` — boletos a pagar. `lib/services/bill_installments.dart` — divisão de parcelas, prazos, código.
- `lib/widgets/pago_logo.dart` — marca. `lib/utils/constants.dart` — nome, frase, links, API.
- `site/` — landing, planos, termos, privacidade, LGPD, ajuda.
- `functions/index.js` — webhook Asaas, PIX Premium, status, confirm Play. `functions/admin.js` — API do painel admin.
- `admin/` — painel do administrador (site `pago-admin`).

## Dados

Firestore: `Users`, `Debts`, `Payments`, `Bills`, `PremiumCharges`, `Presence` (sinal de uso; dono só grava `last_seen_at` = hora do servidor e `plataforma`; ninguém lê pelo app). Regras publicadas. `Bills`: dono lê/apaga; criar/editar exige `is_premium` + `premium_vence_em` futuro (regras já publicadas no projeto, aditivas). Saldo no ledger. Sem bot WhatsApp. Sem offline-first.

## Feito

- Caderneta, dashboard, WhatsApp wa.me com PIX, lembretes (véspera, dia, atraso).
- Premium 39,90: voz, OCR no celular, texto próprio.
- Auth e-mail/senha, Firestore, Functions, webhook Asaas. Asaas no CNPJ.
- Ajuda no site e no app: mesmo WhatsApp, só no clique.
- Rename total TáPago → Pagô na `develop`, apps Firebase novos `app.usepago` com configs baixadas.
- Boletos a pagar (Premium) na `develop`, com benefício na tela Premium e na privacidade. No site: seção própria `#boletos` (mock da lista com parcelas, código, prazos), link “Boletos” no menu, notificação de boleto em Avisos e item no plano Premium. Testes: 20 passando.

## Parcial

- `main` ainda TáPago (código). Na internet não sobra nada TáPago: `tapago-ae948.web.app` redireciona para `usepago.web.app`.
- Premium só pela Google Play (assinatura `pago_premium_monthly`, cobrada na conta Google do usuário). PIX saiu do app e do site; o Asaas fica só como conta bancária que recebe o repasse da Google (cadastrar os dados bancários do Asaas no perfil de pagamentos da Play Console). As Functions `createPremiumPix`/`premiumPixStatus` e o webhook continuam publicados, sem uso pelo app. `confirmPlayPurchase` só Auth e dá 30 dias, sem checar renovação na Google (falta validar no servidor / notificações da Play).
- Play: documento, SDK, keystore, AAB — à noite, no Android Studio.
- CTAs do site ainda `mailto:` (e-mail pessoal do dono).
- Ícone ainda é o check azul antigo.
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
- Publicar na Play: documento, SDK, keystore, AAB.
- Site público: publicar sempre no site `usepago` (`firebase.usepago.json`); o site padrão fica só com API + redirecionamento.
- Criar a assinatura `pago_premium_monthly` (R$ 39,90/mês) na Play Console e testar com conta de teste de licença.
- Bot WhatsApp: **futuro, não implementar**.

## Firebase / Console

- Projeto `tapago-ae948`, Blaze. Hosting padrão https://tapago-ae948.web.app (e `.firebaseapp.com`): só API + redirecionamento. `firebase.json` publica a pasta `hosting-redirect/` com `redirects` 301 para `usepago.web.app` (termos, privacidade, LGPD, ajuda vão para a mesma página; o resto para a home) e mantém as rewrites `/api/**` para as Functions. Publicar: `firebase deploy --only hosting` (sem functions). **Nunca publicar o hosting a partir da `main` antiga**: traria o site TáPago de volta.
- Apps: Android `app.usepago` (`1:1077428127080:android:53dca34d493288510042dd`) e iOS/macOS `app.usepago` (`1:1077428127080:ios:577755df013cd6380042dd`). Apps antigos `com.tapago...` continuam registrados enquanto a `main` usar.
- Functions: `asaasWebhook`, `createPremiumPix`, `premiumPixStatus`, `confirmPlayPurchase`, `adminApi`.
- Hosting sites: `tapago-ae948` (API/webhook + redirecionamento para o Pagô; nenhum canal de preview), `usepago` (site Pagô da develop no ar: https://usepago.web.app — `pago.web.app` é de outro projeto) e `pago-admin` (painel admin).
- Publicar o site Pagô: `firebase deploy --only hosting --config firebase.usepago.json`. Quando comprar `usepago.app`, conectar o domínio no site `usepago`.
- Web app do Firebase: "Default Web App" `1:1077428127080:web:e82621d06da4bf5c0042dd` (usado só pelo painel).
- Webhook: `https://tapago-ae948.web.app/api/webhooks/asaas`
- Auth: e-mail/senha. Asaas: CNPJ.

## Pendências do dono

1. Comprar `usepago.app` / `usepago.com.br`.
2. Play: documento, SDK, keystore, AAB, ficha Pagô (noite).
3. Decidir quando a `develop` vai para a `main`.
4. Play Console: perfil de pagamentos com a conta bancária do Asaas (CNPJ) para receber o repasse da Google.
5. Trocar a senha provisória do painel admin ("Trocar senha").

## Última sessão (10/out)

PC 2 puxou o GitHub, passou a trabalhar na `develop` (descartou a `dev`), corrigiu o Gradle e o R8 do release (ML Kit). Links legais do app em `usepago.web.app`; e-mail de contato trocado para o pessoal do dono no app, termos e site (site `usepago` republicado). Painel admin conferido: no ar, igual ao repo, API exige login (401). Versão release roda no emulador sem travar. Premium agora só pela Google Play: tela Premium com um botão "Assinar Premium", tela de checkout PIX apagada, termos/privacidade/site sem PIX. Painel admin ganhou "Precisa de atenção" (republicado). 20 testes passando.

## Sessão anterior (9/out)

Rename para Pagô / usepago.app. Boletos a pagar (Premium) com parcelas, código e lembrete; regras `Bills` publicadas. Menu no "Pagô!", Caderneta com abas, Configurações só do app. Acabamento: dashboard sem cards repetidos ("Na rua" saiu, entrou "Vencido a receber"), descrições corretas nas Configurações. Painel do administrador web (`pago-admin.web.app`) com `adminApi`, `Presence` e regras publicadas; testado dar/somar/tirar Premium, excluir e bloqueio de não-admin (403). Site Pagô no ar em https://usepago.web.app; celular de exemplo do site igual ao app (Pagô!, Recebe esta semana, Vencido a receber).
