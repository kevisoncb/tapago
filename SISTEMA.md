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
- `develop` — desenvolvimento, já toda em Pagô. Rename completo **ainda não commitado** na sessão de 9/out.
- Só merge `develop` → `main` quando estiver pronto para produção.
- Segredos Asaas só em `.env` e `functions/.env` (gitignored).

## Marca, pacote e domínio

- Nome visível: Pagô (app, ícone, web, site, termos, privacidade, LGPD, ajuda). Frase “E aí, pagô?” no login do app e no site.
- Código todo renomeado: pacote Dart `pago_app`, classes `PagoApp`, `PagoMark`, `PagoWordmark`, `showPagoSnack`; arquivos `assets/brand/pago-*` e `site/assets/pago-*`; Functions `pago-functions`; chaves locais `pago_*`; produto Play `pago_premium_monthly`; define `PAGO_API_BASE`.
- Pacote nativo: **`app.usepago`** (Android applicationId/namespace e `MainActivity` em `kotlin/app/usepago`, bundle iOS/macOS, Linux).
- Única sobra de “tapago”: o ID do projeto Firebase `tapago-ae948` (não pode ser renomeado). A API (`apiBase`) e o webhook continuam em `tapago-ae948.web.app`, que nunca muda.
- Links do app (termos, privacidade, LGPD) apontam para `https://usepago.app` (`AppConstants.siteOrigin`) — só abrem depois de comprar e conectar o domínio.
- E-mail de contato: `ola@usepago.app` (criar depois de comprar).
- Domínios livres em 9/out: `usepago.app` (escolhido), `usepago.com.br`, `eaipago.app`, `eaipago.com.br`, `pagoapp.app`, `meupago.app`. Já registrados: `pago.app`, `pago.com`, `pago.com.br`, `pagou.app`, `pagou.com.br`.

## O que o app faz agora

Caderneta digital de fiado, venda a prazo e empréstimo. Grátis ilimitado. WhatsApp sai do celular do usuário (wa.me), não de bot. Premium: voz, OCR e mensagem própria. R$ 39,90/mês. Ajuda: no site (`/ajuda` + menu) e no app (Configurações → Ajuda) o botão abre o WhatsApp de suporte, sem número na tela.

## Mapa

- `lib/screens/auth_page.dart` — login e cadastro (aceite de termos), nome + “E aí, pagô?”.
- `lib/screens/dashboard_page.dart` — saldo, lista, FAB, ícone WhatsApp.
- `lib/screens/add_debt_page.dart` — lançamento, voz Premium, duplicata bloqueada.
- `lib/screens/client_profile_page.dart` — Abater, OCR, Lembrete / Cobrar hoje / Atraso.
- `lib/screens/caderneta_page.dart` / `contact_history_page.dart` — pessoas e histórico.
- `lib/screens/settings_page.dart` — PIX, banco, mensagem, caderneta, Premium, Ajuda.
- `lib/screens/premium_page.dart` / `pix_checkout_page.dart` — voz, OCR, texto, PIX 30 dias, Play.
- `lib/widgets/pago_logo.dart` — marca. `lib/utils/constants.dart` — nome, frase, links, API.
- `site/` — landing, planos, termos, privacidade, LGPD, ajuda.
- `functions/index.js` — webhook Asaas, PIX Premium, status, confirm Play.

## Dados

Firestore: `Users`, `Debts`, `Payments`, `PremiumCharges`. Saldo no ledger. Sem bot WhatsApp. Sem offline-first.

## Feito

- Caderneta, dashboard, WhatsApp wa.me com PIX, lembretes (véspera, dia, atraso).
- Premium 39,90: voz, OCR no celular, texto próprio.
- Auth e-mail/senha, Firestore, Functions, webhook Asaas. Asaas no CNPJ.
- Ajuda no site e no app: mesmo WhatsApp, só no clique.
- Rename total TáPago → Pagô na `develop`, apps Firebase novos `app.usepago` com configs baixadas. Testes: 17 passando.

## Parcial

- `main` e site ao vivo ainda TáPago.
- PIX Premium: 30 dias. `confirmPlayPurchase` só Auth.
- Play: documento, SDK, keystore, AAB — à noite, no Android Studio.
- CTAs do site ainda `mailto:` (`ola@usepago.app`).
- Ícone ainda é o check azul antigo.
- Avisos antigos do analyzer em `app_controller.dart` e `receipt_reader_io.dart` (estilo, não quebram).

## Ideias (só discutidas)

- Parcelamento a receber em 1 clique (Premium): 15/30/45 ou 30/45/60, bloco único, WhatsApp “parcela 1 de 3”.
- Depois: a pagar (o que você deve), lembrete. Não é ERP de fornecedor.

## Faltando

- Comprar `usepago.app` (e `usepago.com.br`), conectar no Firebase Hosting, criar `ola@usepago.app`.
- Ficha da Play com nome Pagô e pacote `app.usepago` (o pacote antigo nunca foi publicado).
- Publicar na Play: documento, SDK, keystore, AAB.
- Deploy Hosting depois do merge na `main`.
- Teste PIX e2e.
- Bot WhatsApp: **futuro, não implementar**.

## Firebase / Console

- Projeto `tapago-ae948`, Blaze. Hosting padrão: https://tapago-ae948.web.app (domínio customizado futuro: usepago.app).
- Apps: Android `app.usepago` (`1:1077428127080:android:53dca34d493288510042dd`) e iOS/macOS `app.usepago` (`1:1077428127080:ios:577755df013cd6380042dd`). Apps antigos `com.tapago...` continuam registrados enquanto a `main` usar.
- Functions: `asaasWebhook`, `createPremiumPix`, `premiumPixStatus`, `confirmPlayPurchase`.
- Webhook: `https://tapago-ae948.web.app/api/webhooks/asaas`
- Auth: e-mail/senha. Asaas: CNPJ.

## Pendências do dono

1. Comprar `usepago.app` / `usepago.com.br`.
2. Play: documento, SDK, keystore, AAB, ficha Pagô (noite).
3. Decidir quando a `develop` vai para a `main`.
4. Testar PIX.

## Última sessão (9/out)

Tudo renomeado de TáPago para Pagô (app, site, código, pacote `app.usepago`), site definido como usepago.app.
