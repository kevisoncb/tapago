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
- Anterior em origin: `8141917` — Ship live Firestore rules, PIX Functions, and the Premium site cards.
- Segredos Asaas só em `.env` e `functions/.env` (gitignored). Não copiar chave para o Git.

## O que o app faz agora

Caderneta digital de fiado, venda a prazo e empréstimo. Grátis ilimitado. WhatsApp sai do celular do usuário (wa.me), não de bot TáPago. Premium: voz, OCR de recibo e mensagem no texto do usuário. Preço R$ 39,90/mês. Site em https://tapago-ae948.web.app.

## Mapa

- `lib/screens/auth_page.dart` — login e cadastro (aceite de termos).
- `lib/screens/dashboard_page.dart` — saldo aberto, a receber, na rua, lista, FAB, ícone WhatsApp na linha.
- `lib/screens/add_debt_page.dart` — lançamento (máscaras, voz Premium, bloqueio de duplicata).
- `lib/screens/client_profile_page.dart` — saldo, Abater, OCR, Lembrete / Cobrar hoje / Atraso.
- `lib/screens/caderneta_page.dart` / `contact_history_page.dart` — todas as pessoas e histórico.
- `lib/screens/settings_page.dart` — PIX, banco, mensagem pronta, caderneta, Premium, ajuda.
- `lib/screens/premium_page.dart` / `pix_checkout_page.dart` — voz, OCR, texto, PIX 30 dias, Play.
- `lib/screens/legal_page.dart` — termos, privacidade, LGPD no app.
- `site/` — landing, demo, planos, termos, privacidade, LGPD, ajuda.
- `functions/index.js` — webhook Asaas, PIX Premium, status, confirm Play.
- `firestore.rules` — dono só lê/escreve a própria conta; `is_premium` só o servidor muda depois do create.

## Dados

Firestore: `Users`, `Debts`, `Payments`, `PremiumCharges`. Saldo derivado do ledger (juros vs principal). Sem WhatsApp bot. Sem offline-first.

## Feito

- Caderneta: lançar, editar, duplicata bloqueada (nome+telefone), teclado, Abater (total / parte / só juros).
- Dashboard, score, caderneta completa (pago e em aberto), histórico com rótulo do tipo de abate.
- WhatsApp wa.me, tom amigável/formal, chave PIX em Lembrete, Cobrar hoje e Atraso; ícone na lista abre a cobrança.
- Mensagem pronta: grátis fixa, Premium editável em Configurações.
- Lembretes 9h: véspera, dia e atraso; botões Agora não / Enviar cobrança.
- Máscaras (telefone, CPF, PIX, dinheiro), termos obrigatórios no cadastro.
- Premium 39,90: voz, OCR no Android/iOS, texto customizado.
- Auth e-mail/senha no Firebase. Regras Firestore no ar. Functions no ar (`southamerica-east1`). Webhook Asaas configurado.
- Site alinhado ao app: planos, PIX 30 dias vs Play, página Ajuda no repositório.
- Testes `test/product_logic_test.dart`: 17 passando.

## Parcial

- Código da Ajuda e do texto dos planos está no Git; Hosting ao vivo ainda não recebeu este deploy (`/ajuda` 404 até `firebase deploy --only hosting`).
- PIX Premium: 30 dias no webhook. Play no app existe, sem AAB na loja. `confirmPlayPurchase` ainda é só Auth (sem validar a compra na Play API).
- OCR e voz: reais no celular; stub na web/Windows.
- Windows/web: Firebase pode não iniciar → conta local. Produção real é Android + Firestore.
- Play Console: conta pessoal paga; identidade parada no documento físico. Sem SDK Android neste PC, sem keystore, sem AAB.
- CTAs do site ainda `mailto:ola@tapago.app` (não há ficha da Play).
- Demo do hero no site é resumida (nome, valor, juros); o app pede também WhatsApp e vencimento.

## Faltando

- Publicar na Play: documento, Android Studio/SDK, keystore, AAB, ficha, telefone.
- Comprar `tapago.app` (Cloudflare Registrar) e apontar no Hosting.
- `firebase deploy --only hosting` para Ajuda e o texto dos planos.
- Teste PIX e2e (cobrança real Asaas → webhook → `is_premium`).
- CNPJ no Asaas (hoje CPF; migrar depois). PIX atual não é assinatura automática.
- Validar compra Play no servidor.
- Bot WhatsApp TáPago: **futuro, não implementar**.
- iOS na loja: não é o go-live.

## Firebase / Console

- Projeto `tapago-ae948`, Blaze.
- Hosting: https://tapago-ae948.web.app
- Functions: `asaasWebhook`, `createPremiumPix`, `premiumPixStatus`, `confirmPlayPurchase`.
- Webhook: `https://tapago-ae948.web.app/api/webhooks/asaas` — eventos `PAYMENT_CONFIRMED` e `PAYMENT_RECEIVED`.
- Auth: e-mail/senha ligado.

## Pendências do dono

1. Play: documento, SDK, keystore, AAB, ficha.
2. Comprar domínio e apontar.
3. Deploy Hosting desta versão do site.
4. Testar PIX depois do restante.
5. CNPJ no Asaas quando sair.

## Última sessão (6/out)

Auditoria site↔app commitada e enviada ao GitHub. PIX em toda cobrança, lembrete na véspera, WhatsApp na home, Ajuda no site, texto honesto do Premium.
