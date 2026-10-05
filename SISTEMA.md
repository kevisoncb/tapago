# TáPago — Contexto do sistema

Arquivo vivo. **Não é histórico infinito.** A cada alteração este arquivo é **reescrito do zero** com o estado atual.

## Como a IA deve usar (obrigatório)

Em toda conversa:

1. Ler este arquivo por completo.
2. Entender código no Git, o que foi feito no Console (não vai no Git) e as pendências.
3. Só então implementar.
4. Depois de mexer, **apagar e reescrever** este arquivo.
5. O contexto válido entre PCs é o que está em `origin/main` neste arquivo.

## Estado atual

- App Flutter **TáPago** — gestão de débitos/cobrança. UI em português. Azul `#2F6BFF`.
- Pacote `tapago_app` · Android `com.tapago.tapago_app` · versão `2.4.0+24`.
- Repo: https://github.com/kevisoncb/tapago · branch `main`.
- Este PC: `C:\Users\ADM03\Desktop\tapago-app`. Flutter SDK: `C:\Users\ADM03\flutter` (fora do repo).

## Freemium e pagamentos (decisão de negócio)

- Grátis: **máximo 5 clientes/débitos** (`AppConstants.freeDebtLimit`). Já barrado no app (`reachedFreeLimit` → paywall).
- Premium: **R$ 59,90/mês**. Campo `Users.is_premium` na base.
- Gateway escolhido: **Asaas** (assinatura recorrente com CPF, sem CNPJ agora).
- Firebase: plano **Spark** (gratuito). Firestore em **modo teste** no Console Google — projeto criado em casa (4/out). Isso **não gera arquivo no Git**.
- Assinar Agora no app **ainda abre Play Store** e liga `is_premium` local. **Ainda não há Asaas no código.** Não existe `asaas_server.dart`. Webhook precisa de URL pública (ex.: Render) para o Asaas avisar PIX/assinatura com o PC desligado.

## O que o app faz (código no Git)

Cadastro de débitos, lista com atrasados em vermelho, perfil com WhatsApp, OCR simulado, paywall, configurações (PIX, notificações). Seed: João Dinâmico + clientes fictícios.

### Telas (`lib/screens/`)

| Tela | Arquivo | Função |
|---|---|---|
| Dashboard | `dashboard_page.dart` | Lucro Projetado, A Receber, Dinheiro na Rua; Premium; lista; FAB |
| Novo Débito | `add_debt_page.dart` | Voz simulada, nome, WhatsApp, valor, juros, vencimento |
| Perfil | `client_profile_page.dart` | Score, valor, 3 WhatsApp, OCR, histórico |
| Premium | `premium_page.dart` | R$ 59,90, benefícios, Assinar Agora |
| Configurações | `settings_page.dart` | PIX, banco, toggles, assinatura |

### Dados (schema no código)

- **Users**: `email`, `is_premium`, `chave_pix`, `nome`, notificações, biometria, banco, `premium_vence_em`
- **Debts**: `user_id`, `nome`, `telefone`, `valor_principal`, `taxa_juros`, `data_vencimento`, `status_pago`, `client_score`
- **Payments**: `debt_id`, `user_id`, `valor`, `data`, `descricao`

App sobe em **LocalRepository** (`USE_FIREBASE` default `false`). Sem `lib/firebase_options.dart` no Git — `flutterfire configure` ainda não foi commitado.

```powershell
$env:Path = "$env:USERPROFILE\flutter\bin;$env:LOCALAPPDATA\Pub\Cache\bin;" + $env:Path
flutterfire configure
flutter run --dart-define=USE_FIREBASE=true
```

Depois: commitar `firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`, `firebase.json`, `.firebaserc` e dar **push**.

## Arquitetura de pastas

```
lib/main.dart app.dart
lib/theme/ models/ data/ services/ state/ screens/ widgets/ utils/
assets/images/water_splash.jpg
firestore.rules  firestore.indexes.json
```

Não existe pasta/servidor Asaas no repo.

## Último commit no GitHub

- `d73b4f4` (3/out) — refresh do SISTEMA.md
- `41f0803` (3/out) — criou SISTEMA.md + regra Cursor
- `9a7395c` (2/out) — app Flutter inicial
- **Não houve commit em 4/out.** O trabalho de casa foi Console/Asaas/decisões, não push.

## O que foi feito em casa (4/out) — fora do Git

1. Modelo freemium (5 clientes / R$ 59,90) e `is_premium` na base.
2. Stack: Flutter no Cursor + Firestore Spark + Asaas.
3. Projeto Google criado, Firestore modo teste.
4. Painel Asaas: onde fica webhook, chave de API e assinatura recorrente.
5. Dúvidas resolvidas em conversa: recriar UI no Cursor (sem export de ferramenta visual); gateway com CPF; Git entre PCs; `flutterfire configure`; webhook Asaas exige servidor público (Render) para `asaas_server.dart`.

## Pendências

- `flutterfire configure` + commit/push dos arquivos gerados.
- Trocar Play Store por Asaas (app + `asaas_server.dart` + webhook no Render).
- Atualizar `is_premium` de verdade quando o webhook confirmar o pagamento.
- OCR e voz ainda simulados.
- README ainda genérico.

## Última sessão (este PC, 5/out)

Pull não trouxe commit novo porque o remoto parou em `d73b4f4`. O trabalho de casa não estava no Git — estava no Console e nas decisões acima. Este arquivo foi reescrito para registrar isso.
