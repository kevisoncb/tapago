# Pagô! — Contexto do sistema

Arquivo vivo. Reescrito a cada alteração. Slogan: **E aí, pagô?** (antigo nome: TáPago).

## Como a IA deve usar (obrigatório)

1. Ler este arquivo.
2. Código no Git × o que vive só no Console.
3. Implementar **só na `dev`**. Não commitar feature na `producao` nem na `main`.
4. Apagar e reescrever este arquivo.
5. Entre PCs: teste é `origin/dev`. Produção é `origin/producao` (e `origin/main`, o mesmo código).

## Git

- `dev` — teste. Trabalho novo entra aqui.
- `producao` — estável. Igual à `main`. Só recebe merge da `dev` quando estiver pronto.
- Segredos Asaas só em `.env` e `functions/.env` (gitignored).

## Marca

- Nome na tela: `Pagô!` (`AppConstants.appName`). Slogan: `AppConstants.slogan` = "E aí, pagô?".
- Em texto corrido (termos, LGPD, iOS): "o Pagô".
- **Não mudou**: package `com.tapago.tapago_app` / bundle `com.tapago.tapagoApp`, projeto Firebase `tapago-ae948`, pasta `tapago`, classes `Tapago*`, chaves locais `tapago_*`. Trocar quebra Firebase e dados salvos.

## O que o app faz agora

- **Caderneta (a receber)**: fiado, venda a prazo, empréstimo. Grátis ilimitado. Cobrança pelo WhatsApp do usuário (wa.me). Premium R$ 39,90: voz, OCR, texto próprio.
- **Boletos a pagar (só na `dev`)**: contas da empresa do usuário (fornecedor, aluguel, imposto). Empresa, CNPJ opcional, valor, vencimento, descrição e código do boleto. O código (47 dígitos bancário, 48 consumo, 44 barras) preenche valor e vencimento sozinho. Copiar código, marcar pago/desfazer, editar, excluir.
- **Notificações** às 9h (mesmo interruptor "notificações diárias"):
  - Caderneta: véspera, dia, atraso. Canal `cobrancas`, ações Agora não / Enviar cobrança.
  - Boletos: 3 dias antes, véspera, dia ("E aí, pagô?") e todo dia enquanto vencido. Canal `boletos`. Payload `boleto|aviso|id`.

## Mapa

- `lib/screens/auth_page.dart` — login/cadastro, nome + slogan.
- `lib/screens/dashboard_page.dart` — "E aí, Nome", saldo, card de boletos, ícone de boletos com contador (vencidos + vencendo em 3 dias).
- `lib/screens/boletos_page.dart` — total a pagar, abertos, pagos, ações.
- `lib/screens/add_boleto_page.dart` — formulário com colar código.
- `lib/screens/add_debt_page.dart`, `client_profile_page.dart`, `caderneta_page.dart`, `contact_history_page.dart` — caderneta.
- `lib/screens/settings_page.dart`, `premium_page.dart`, `pix_checkout_page.dart`.
- `lib/utils/boleto_code.dart` — máscara e leitura do código (fator de vencimento base 22/02/2025).
- `lib/services/reminder_service.dart` — `reminderKind` (caderneta) e `boletoAviso` (boletos).
- `site/` — landing com slogan e boletos, termos, privacidade, LGPD, ajuda.
- `functions/index.js` — webhook Asaas, PIX Premium, status, confirm Play.

## Dados

Firestore: `Users`, `Debts`, `Payments`, `Boletos`, `PremiumCharges`.
`Boletos`: `user_id`, `empresa`, `cnpj`, `descricao`, `valor`, `data_vencimento`, `linha_digitavel`, `status_pago`, `pago_em`, `created_at`. Regras publicadas em `tapago-ae948` (8/out).
Local: `tapago_${uid}_boletos` no SharedPreferences (cache).

## Parcial

- Boletos e marca nova só na `dev`; produção/Hosting ainda mostram TáPago até merge + deploy.
- Toque na notificação de boleto abre o app, não a tela de boletos.
- PIX Premium: 30 dias. Play no app, sem AAB na loja.
- OCR/voz: real no Android/iOS; stub na web/Windows.
- CTAs do site ainda `mailto:ola@tapago.app`.
- Ícone do app continua o mesmo (check azul).

## Faltando

- Publicar na Play: documento, SDK, keystore, AAB, ficha (nome "Pagô!").
- Domínio próprio para o Pagô! e apontar no Hosting.
- `firebase deploy --only hosting` a partir da `producao`.
- Teste PIX de ponta a ponta.
- Ler boleto pela câmera (código de barras): futuro.
- Bot WhatsApp: futuro, não implementar.

## Firebase / Console

- Projeto `tapago-ae948`, Blaze. Hosting: https://tapago-ae948.web.app
- Functions: `asaasWebhook`, `createPremiumPix`, `premiumPixStatus`, `confirmPlayPurchase` (descrição do PIX vira "Pagô! Premium" no próximo deploy das Functions).
- Webhook: `https://tapago-ae948.web.app/api/webhooks/asaas`
- Auth: e-mail/senha. Asaas: CNPJ.

## Última sessão (8/out)

App rodando no emulador Android (`Medium_Phone_API_37.0`, via `flutter run -d emulator-5554`). Corrigido `android/app/build.gradle.kts` (imports `java.util.Properties` / `java.io.FileInputStream`) que não compilava no Gradle 9. Na `dev`: renomeado para Pagô! ("E aí, pagô?") em app, Android, iOS, web, site e textos legais. Criados os Boletos a pagar com leitura do código e avisos (3 dias, véspera, dia, vencido). Regras do Firestore publicadas. 21 testes passando.
