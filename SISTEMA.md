# TáPago — Contexto do sistema

Arquivo vivo. **Não é histórico infinito.** A cada alteração este arquivo é **reescrito do zero**.

## Como a IA deve usar (obrigatório)

1. Ler este arquivo.
2. Separar: código no Git × o que vive só no Console (Firebase/Asaas).
3. Implementar.
4. Apagar e reescrever este arquivo.
5. Entre PCs, o válido é `origin/main`.

## Estado atual

- App Flutter **TáPago**. Pacote `tapago_app` · Android `com.tapago.tapago_app` · `2.4.0+24`.
- Repo: https://github.com/kevisoncb/tapago · `main`.
- Este PC: `C:\Users\ADM03\Desktop\tapago-app`.

## Chaves (não sumiram)

As chaves de **casa (4/out) estão nos painéis**, não no GitHub.

| Onde | O que | Como trazer para este PC |
|---|---|---|
| [Firebase Console](https://console.firebase.google.com) | projeto Spark, Firestore teste, apps | Neste PC: `flutterfire configure` (gera `firebase_options.dart` + `google-services.json`). **Esses arquivos vão no Git.** |
| Painel Asaas | API key, webhook token, assinatura | Copiar de novo no Asaas → colar em `.env` local. **Nunca commitar `.env`.** Modelo: `.env.example`. |

Git **não guarda** chave de API do Asaas (é segredo de servidor). Git **guarda** a ligação Firebase do app depois do `flutterfire configure` + push.

## Freemium e pagamentos

- Grátis: 5 débitos. Premium: R$ 59,90/mês. Campo `Users.is_premium`.
- Gateway: **Asaas** (CPF). Código ainda usa Play Store no botão Assinar.
- Sem `asaas_server.dart`. Webhook precisa de URL pública (Render).

## App no Git

Telas: Dashboard, Novo Débito, Perfil, Premium, Configurações. Dados locais por padrão (`USE_FIREBASE=false`). Schema Users / Debts / Payments no código.

```
lib/  screens/ services/ state/ models/ data/ theme/ widgets/ utils/
firestore.rules  firestore.indexes.json  .env.example
```

## Último commit

- `719b730` — registrou decisões de casa no SISTEMA.md
- `d73b4f4` / `41f0803` — SISTEMA.md
- `9a7395c` — app inicial
- **4/out: zero commit.** Trabalho foi Console + Asaas.

## Pendências

- Neste PC: login Google → `flutterfire configure` → commit/push dos arquivos gerados.
- `.env` local com chave Asaas (copiar do painel).
- Servidor Asaas + webhook Render; paywall deixar de usar Play Store.
- OCR/voz simulados.

## Última sessão (5/out, este PC)

Usuário confirmou que em casa já tinha as chaves. Elas continuam no Firebase/Asaas. Criado `.env.example` e `.gitignore` para `.env`. Falta rodar `flutterfire configure` logado na mesma conta Google de casa.
