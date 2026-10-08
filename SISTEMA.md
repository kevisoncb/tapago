# TáPago — Contexto do sistema

Arquivo vivo. Reescrito a cada alteração.

## Como a IA deve usar (obrigatório)

1. Ler este arquivo.
2. Código no Git × o que vive só no Console.
3. Implementar **só na `dev`**. Não commitar feature na `producao` nem na `main`.
4. Apagar e reescrever este arquivo.
5. Entre PCs: teste é `origin/dev`. Produção é `origin/producao` (e `origin/main`, o mesmo código).

## Git

- `dev` — teste. Trabalho novo entra aqui. Igual à `develop`.
- `producao` — o que está estável. Igual à `main`. Só recebe merge da `dev` quando estiver pronto.
- `main` continua no GitHub como padrão da produção, no mesmo commit da `producao`.
- Segredos Asaas só em `.env` e `functions/.env` (gitignored).

## O que o app faz agora (produção)

Caderneta digital de fiado, venda a prazo e empréstimo. Grátis ilimitado. WhatsApp sai do celular do usuário (wa.me), sem bot do TáPago. Premium: voz, OCR e mensagem no texto. R$ 39,90/mês. Ajuda: no site (`/ajuda`) e no app (Configurações → Ajuda) o botão abre o WhatsApp, sem número na tela. Site: https://tapago-ae948.web.app.

## Mapa

- `lib/screens/auth_page.dart` — login e cadastro (aceite de termos).
- `lib/screens/dashboard_page.dart` — saldo, lista, FAB, ícone WhatsApp.
- `lib/screens/add_debt_page.dart` — lançamento, voz Premium, duplicata bloqueada.
- `lib/screens/client_profile_page.dart` — Abater, OCR, Lembrete / Cobrar hoje / Atraso.
- `lib/screens/caderneta_page.dart` / `contact_history_page.dart` — pessoas e histórico.
- `lib/screens/settings_page.dart` — PIX, banco, mensagem, caderneta, Premium, Ajuda (WhatsApp).
- `lib/screens/premium_page.dart` / `pix_checkout_page.dart` — voz, OCR, texto, PIX 30 dias, Play.
- `site/` — landing, planos, termos, privacidade, LGPD, ajuda.
- `functions/index.js` — webhook Asaas, PIX Premium, status, confirm Play.

## Dados

Firestore: `Users`, `Debts`, `Payments`, `PremiumCharges`. Saldo no ledger. Sem bot WhatsApp. Sem offline-first.

## Feito

- Caderneta, dashboard, WhatsApp wa.me com PIX, lembretes (véspera, dia, atraso).
- Premium 39,90: voz, OCR no celular, texto próprio.
- Auth e-mail/senha, Firestore, Functions, webhook Asaas. Conta Asaas no CNPJ.
- Ajuda no site e no app: mesmo WhatsApp, só no clique do botão.

## Parcial

- Hosting ao vivo pode estar na versão antiga até o deploy.
- PIX Premium: 30 dias. Play no app, sem AAB na loja.
- OCR/voz: real no Android/iOS; stub na web/Windows.
- CTAs do site ainda `mailto:ola@tapago.app`.

## Faltando

- Publicar na Play: documento, SDK, keystore, AAB, ficha.
- Comprar um domínio próprio e apontar no Hosting.
- `firebase deploy --only hosting` a partir da `producao`.
- Teste PIX de ponta a ponta.
- Bot WhatsApp TáPago: futuro, não implementar.
- iOS na loja: não é o go-live.

## Firebase / Console

- Projeto `tapago-ae948`, Blaze. Hosting: https://tapago-ae948.web.app
- Functions: `asaasWebhook`, `createPremiumPix`, `premiumPixStatus`, `confirmPlayPurchase`.
- Webhook: `https://tapago-ae948.web.app/api/webhooks/asaas`
- Auth: e-mail/senha. Asaas: CNPJ.

## Última sessão (8/out)

Este PC criou `dev` (teste) e `producao` (estável) e enviou as duas para o GitHub. Trabalho daqui em diante é na `dev`.
