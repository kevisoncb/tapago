# TáPago — Contexto do sistema

Arquivo vivo. Reescrito a cada alteração.

## Como a IA deve usar (obrigatório)

1. Ler este arquivo.
2. Código no Git × o que vive só no Console.
3. Implementar **só na `develop`**. Não commitar feature na `main`.
4. Apagar e reescrever este arquivo.
5. Produção entre PCs: `origin/main`. Desenvolvimento entre PCs: `origin/develop`.

## Git

- `main` — produção. Código funcional congelado para Play/site. Origin: `c75f224`.
- `develop` — desenvolvimento. Parte da `main`. Novas ideias (parcelamento, a pagar, etc.) entram aqui.
- Só merge `develop` → `main` quando estiver pronto para produção.
- Segredos Asaas só em `.env` e `functions/.env` (gitignored).

## O que o app faz agora (produção)

Caderneta digital de fiado, venda a prazo e empréstimo. Grátis ilimitado. WhatsApp sai do celular do usuário (wa.me), não de bot TáPago. Premium: voz, OCR e mensagem no texto. R$ 39,90/mês. Ajuda: no site (`/ajuda` + menu) e no app (Configurações → Ajuda) o botão abre o WhatsApp, sem número na tela. Site: https://tapago-ae948.web.app.

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
- Auth e-mail/senha, Firestore, Functions, webhook Asaas. Conta Asaas **já no CNPJ**.
- Ajuda no site e no app: mesmo WhatsApp, só no clique do botão.

## Parcial / produção ainda pendente

- Hosting ao vivo pode estar na versão antiga até o deploy.
- PIX Premium: 30 dias. `confirmPlayPurchase` só Auth (validar Play API depois, na `develop` ou na hora da loja).
- Play: documento, SDK, keystore, AAB — à noite, no Android Studio. Não mistura com feature nova.
- CTAs do site ainda `mailto:ola@tapago.app`.

## Ideias só na develop (não na main)

- Parcelamento a receber em 1 clique (Premium): 15/30/45 ou 30/45/60, bloco único, WhatsApp “parcela 1 de 3”.
- Depois: a pagar (o que você deve), lembrete. Não é ERP de fornecedor.

## Faltando (ops, não feature)

- Publicar na Play: documento, SDK, keystore, AAB, ficha.
- Comprar `tapago.app` e apontar no Hosting.
- `firebase deploy --only hosting`.
- Teste PIX e2e.
- Bot WhatsApp TáPago: **futuro, não implementar**.
- iOS na loja: não é o go-live.

## Firebase / Console

- Projeto `tapago-ae948`, Blaze. Hosting: https://tapago-ae948.web.app
- Functions: `asaasWebhook`, `createPremiumPix`, `premiumPixStatus`, `confirmPlayPurchase`.
- Webhook: `https://tapago-ae948.web.app/api/webhooks/asaas`
- Auth: e-mail/senha. Asaas: CNPJ.

## Pendências do dono

1. Play: documento, SDK, keystore, AAB, ficha (noite, Android Studio).
2. Comprar domínio e apontar.
3. Deploy Hosting da produção (`main`).
4. Testar PIX depois do restante.

## Última sessão (8/out)

`main` ficou produção. Abriu `develop` para o que vier depois, sem mexer no código que já funciona.
