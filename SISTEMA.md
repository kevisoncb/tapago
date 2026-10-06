# TáPago — Contexto do sistema

Arquivo vivo. Reescrito a cada alteração.

## Como a IA deve usar (obrigatório)

1. Ler este arquivo.
2. Código no Git × o que vive só no Console.
3. Implementar.
4. Apagar e reescrever este arquivo.
5. Entre PCs, o contexto commitado é `origin/main`.

## Git neste PC

- Branch `main`. Este retrato entra no commit que sobe para `origin/main`.

## O que o app faz agora

Caderneta de fiado/empréstimo. Site em https://tapago-ae948.web.app. Grátis ilimitado. Premium R$ 39,90: voz, OCR e cobrança no texto. Firestore com rules no Console: dono só vê a própria caderneta; `is_premium` só Functions/Admin. PIX e Play passam por `https://tapago-ae948.web.app/api/...`.

## Mapa

- Site: `site/`
- Rules: `firestore.rules`
- Functions: `functions/index.js` (Node 22, southamerica-east1)
- Android: `com.tapago.tapago_app`

## Firebase / Console

- Projeto `tapago-ae948`, Blaze ativo.
- Functions no ar: `asaasWebhook`, `createPremiumPix`, `premiumPixStatus`, `confirmPlayPurchase`.
- Env vazio até o Asaas: `ASAAS_API_KEY`, `ASAAS_WEBHOOK_TOKEN`.
- Webhook: `https://tapago-ae948.web.app/api/webhooks/asaas`.

## Último commit em origin/main

Este push. Anterior: `1dd07e8` — Ship caderneta, Premium voice/OCR, and the marketing site.

## Pendências

1. Asaas no CPF (migrar para CNPJ depois): colar chaves nas Functions.
2. Android SDK + keystore + AAB + Play (`tapago_premium_monthly` R$ 39,90).
3. Auth e-mail/senha no Console.
4. Domínio tapago.app.

## Última sessão (6/out)

Blaze, Functions e `/api` no ar. Site Premium só com as vantagens pagas. Conta Asaas sobe no CPF.
