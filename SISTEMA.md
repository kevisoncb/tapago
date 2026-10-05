# TáPago — Contexto do sistema

Arquivo vivo do projeto. Não é histórico. A cada alteração de código este arquivo é reescrito com o estado atual.

## Como a IA deve usar

1. Ler este arquivo por completo antes de alterar o sistema.
2. Implementar em cima do que está descrito aqui.
3. Depois de mexer no código, reescrever este arquivo com o estado novo.
4. No outro PC, o contexto válido é o `SISTEMA.md` commitado em `origin/main`.

## Estado atual

- App Flutter TáPago, gestão de débitos, português, azul `#2F6BFF`.
- Pacote `tapago_app`. Android `com.tapago.tapago_app`. Versão `2.4.0+24`.
- Repositório: https://github.com/kevisoncb/tapago
- Branch `main`, tracking `origin/main`.
- Pasta neste PC: `C:\Users\kevis\OneDrive\Documentos\Projetos\tapago`.
- A conta, o PIX, a carteira, o comprovante, a voz, a biometria, o lembrete, o webhook, o Firebase e o saldo estão no branch `cursor/cloud-billing-and-balances`.
- O CLI do Firebase neste PC já está autenticado. O projeto padrão é `tapago-ae948`, em `.firebaserc`.
- Este PC não tem Android SDK, então o APK ainda não foi gerado aqui.

## O que o app faz agora

Entra com e-mail e senha. Com o Firebase ligado, a conta e os débitos vão para a nuvem, com cópia local. Se o Firebase não iniciar, a conta fica só no aparelho.

O saldo do débito é o combinado menos o que já foi pago. O combinado é o principal mais a taxa. O juro que resta acompanha só o que ainda está aberto. Pagamento parcial abate esse saldo. Quando a soma cobre o saldo, o débito fica pago. "Marcar como pago" grava uma quitação com o valor que faltava.

No perfil, o histórico mostra os três pagamentos mais recentes. "Ver tudo" abre a lista completa. O WhatsApp cobra o saldo aberto, não o valor original.

Débitos, cobrança por WhatsApp, comprovante lido de verdade, cadastro por voz, lembrete diário às 9h, biometria e exclusão de débito. Score sobe com pagamento e cai com atraso.

Na home, "Dinheiro na rua" é o principal que ainda falta. "Lucro projetado" é o juro que ainda falta. "A receber" é o saldo da semana e dos atrasados.

Premium custa R$ 59,90. Dois caminhos, os dois só ligam depois da confirmação:

- PIX pelo Asaas, via `server/asaas_server.dart`. A chave fica no `.env` da raiz, fora do Git. Ainda não está na nuvem.
- Cartão da carteira do telefone, pela Play Store (`tapago_premium_monthly`).

## Firebase

Projeto `tapago-ae948`, plano Spark. Console: https://console.firebase.google.com/project/tapago-ae948/overview

Apps registrados:

- Android `com.tapago.tapago_app`
- iOS e macOS `com.tapago.tapagoApp`

`lib/firebase_options.dart` aponta para esse projeto. Android usa `android/app/google-services.json` e o plugin do Google Services. iOS usa `ios/Runner/GoogleService-Info.plist`, incluído no alvo do Xcode.

O Firestore `(default)` já existe. As regras de `firestore.rules` e os índices foram publicados. Cada usuário só mexe no próprio `user_id`.

O login por e-mail e senha está ligado no projeto.

## Webhook do Asaas

`functions/index.js` é a Cloud Function `asaasWebhook` (Node 20, região `southamerica-east1`). O código está pronto e não foi publicado. Cloud Functions pedem o plano Blaze.

O PIX fica para depois. Não há túnel temporário.

## Dados

Coleções `Users`, `Debts` e `Payments`. O saldo não é um campo gravado: ele sai do principal, da taxa e da soma dos pagamentos, em `lib/services/debt_balance.dart`.

## Último commit

- Hash: `80dea79`
- Branch: `cursor/cloud-billing-and-balances`
- Mensagem: `Record real debt balances and keep accounts in Firebase.`
- O `.env` continua fora do Git.

## Pendências

- Instalar o Android SDK neste PC e gerar o APK de teste.
- Provar no celular: conta Firebase, comprovante, voz, biometria e lembrete das 9h.
- PIX na nuvem, para cobrar com o app fechado. A função pronta espera o Blaze, ou um servidor que fique sempre aceso.
- Publicar o produto `tapago_premium_monthly` na Play Store.
