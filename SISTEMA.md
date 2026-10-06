# TáPago — Contexto do sistema

Arquivo vivo. Reescrito a cada alteração.

## Como a IA deve usar (obrigatório)

1. Ler este arquivo.
2. Código no Git × o que vive só no Console.
3. Implementar.
4. Apagar e reescrever este arquivo.
5. Entre PCs, o contexto commitado é `origin/main`.

## Git neste PC

- Branch `main`. Este retrato sobe neste commit para `origin/main`.
- Anterior: `df2e5cb`. Asaas já no CNPJ. Ajuda no site e no app, WhatsApp só no clique, número nunca na tela.
- Segredos Asaas só em `.env` e `functions/.env` (gitignored).

## O que o app faz agora

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
- Testes: 17 passando no último run.

## Parcial

- Hosting ao vivo ainda pode estar na versão antiga até o próximo deploy.
- PIX Premium: 30 dias, sem renovação automática. Play no app, sem AAB na loja. `confirmPlayPurchase` só Auth.
- OCR/voz: real no Android/iOS; stub na web/Windows.
- Play Console: conta pessoal paga; identidade parada no documento. Sem SDK/keystore/AAB neste PC.
- CTAs “Baixar” / “Quero ser Premium” ainda `mailto:ola@tapago.app`.

## Faltando

- Publicar na Play: documento, SDK, keystore, AAB, ficha.
- Comprar `tapago.app` e apontar no Hosting.
- `firebase deploy --only hosting` para a Ajuda ir ao ar.
- Teste PIX e2e.
- Validar compra Play no servidor.
- Bot WhatsApp TáPago: **futuro, não implementar**.
- iOS na loja: não é o go-live.

## Firebase / Console

- Projeto `tapago-ae948`, Blaze. Hosting: https://tapago-ae948.web.app
- Functions: `asaasWebhook`, `createPremiumPix`, `premiumPixStatus`, `confirmPlayPurchase`.
- Webhook: `https://tapago-ae948.web.app/api/webhooks/asaas`
- Auth: e-mail/senha. Asaas: CNPJ.

## Pendências do dono

1. Play: documento, SDK, keystore, AAB, ficha.
2. Comprar domínio e apontar.
3. Deploy Hosting desta versão.
4. Testar PIX depois do restante.

## Última sessão (6/out)

Ajuda unificada commitada: site (menu + `/ajuda`) e app (Configurações → Ajuda). Número não aparece na tela.
