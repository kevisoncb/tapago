# TáPago — Contexto do sistema

Arquivo vivo do projeto. **Não é histórico infinito.** A cada alteração de código este arquivo é **reescrito do zero** com o estado atual (o que existe agora, o último commit e o que ficou pendente).

## Como a IA deve usar (obrigatório)

Em **toda** conversa, antes de criar ou alterar qualquer coisa:

1. Ler este arquivo por completo.
2. Entender o que já existe, o último commit e as pendências.
3. Só então implementar.
4. Depois de mexer no código, **apagar o conteúdo antigo e reescrever** este arquivo com o estado novo.
5. Se o usuário estiver em outro PC, o contexto correto é o que está **commitado neste arquivo** no GitHub (`origin/main`).

## Estado atual

- App Flutter **TáPago** (gestão de débitos / cobrança), UI em português, visual fintech (branco, cinza claro, azul `#2F6BFF`).
- Pacote: `tapago_app` · Android id: `com.tapago.tapago_app` · versão `2.4.0+24`.
- Repositório: https://github.com/kevisoncb/tapago
- Branch: `main` (tracking `origin/main`).
- Pasta local: `C:\Users\ADM03\Desktop\tapago-app` (neste PC).
- Flutter SDK neste PC: `C:\Users\ADM03\flutter` (não faz parte do repo).

## O que o app faz

Cadastro de clientes/débitos, lista priorizando atrasados (vermelho) e próximos (azul), perfil do cliente com cobrança via WhatsApp, comprovante OCR (simulado), paywall Premium R$ 59,90/mês e configurações (PIX, notificações).

Dados de demonstração: usuário **João Dinâmico**, clientes fictícios (Carlos, Mariana, Roberto, Ana, Ricardo).

## Telas (`lib/screens/`)

| Tela | Arquivo | Função |
|---|---|---|
| Dashboard | `dashboard_page.dart` | Cards Lucro Projetado, A Receber, Dinheiro na Rua; banner Premium; lista de débitos; FAB Novo Débito |
| Novo Débito | `add_debt_page.dart` | Cadastro por voz (simulado), nome, WhatsApp, valor, juros, vencimento, total |
| Perfil do Cliente | `client_profile_page.dart` | Score, valor atualizado, 3 botões WhatsApp, OCR, histórico de pagamentos |
| Premium | `premium_page.dart` | Benefícios, R$ 59,90/mês, Assinar Agora (Play Store) |
| Configurações | `settings_page.dart` | Perfil, chave PIX, banco, toggles, assinatura, suporte |

## Dados e Firebase

Schema em `lib/data/firestore_schema.dart` e regras em `firestore.rules`.

- **Users**: `email`, `is_premium`, `chave_pix`, `nome`, notificações, biometria, banco, `premium_vence_em`
- **Debts**: `user_id`, `nome`, `telefone`, `valor_principal`, `taxa_juros`, `data_vencimento`, `status_pago`, `client_score`
- **Payments**: `debt_id`, `user_id`, `valor`, `data`, `descricao`

Por padrão o app **não** usa Firebase: `LocalRepository` + `SharedPreferences` (`USE_FIREBASE` default `false`).

Para ligar o Firestore (console já existe):

```powershell
$env:Path = "$env:USERPROFILE\flutter\bin;$env:LOCALAPPDATA\Pub\Cache\bin;" + $env:Path
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
cd C:\Users\ADM03\Desktop\tapago-app
flutterfire configure
flutter run --dart-define=USE_FIREBASE=true
```

Ainda **não** existe `lib/firebase_options.dart`. `Firebase.initializeApp()` sem options só funciona depois do `flutterfire configure`.

## Arquitetura de pastas

```
lib/
  main.dart                 entrada, orientação retrato
  app.dart                  MaterialApp pt_BR + Provider + moldura de celular no desktop
  theme/                    cores e tema (Plus Jakarta Sans)
  models/models.dart        AppUser, Debt, Payment
  data/                     seed fictício + nomes das coleções
  services/                 repositório local/Firestore, WhatsApp, factory
  state/app_controller.dart estado (Provider)
  screens/                  as 5 telas
  widgets/                  campos, cards, botões
  utils/                    dinheiro, datas, constantes
assets/images/water_splash.jpg   hero do Premium
```

Estado: `provider`. Persistência local: `shared_preferences`. WhatsApp: `url_launcher` + `wa.me`.

## Último commit

- Hash: `41f0803`
- Mensagem: `Add a living SISTEMA.md so both PCs share the same project context.`
- Conteúdo: criou `SISTEMA.md` e a regra `.cursor/rules/contexto-sistema.mdc`.
- Anterior: `9a7395c` — app Flutter inicial (telas, Firestore, assets).
- Remote: `origin/main` atualizado.

## Pendências

- Rodar `flutterfire configure` e commitar `firebase_options.dart` + arquivos nativos gerados.
- Ligar `USE_FIREBASE=true` no dia a dia depois disso.
- OCR e cadastro por voz ainda são simulados (não há microfone/ML reais).
- Assinar Agora abre a Play Store e ativa Premium localmente (não há billing real).
- README padrão do Flutter, desatualizado.

## Última sessão (o que aconteceu neste PC)

1. Pasta vazia; Flutter não estava no PATH. SDK clonado em `C:\Users\ADM03\flutter` e `flutter create --empty` gerou o projeto.
2. App TáPago montado a partir das imagens de referência: 5 telas, tema, seed fictício, WhatsApp, PIX, paywall.
3. Camada Firestore escrita, mas o app sobe em modo local até configurar o Firebase.
4. Código enviado para https://github.com/kevisoncb/tapago (`9a7395c`).
5. Usuário pediu este arquivo para trabalhar em **dois PCs**: ler → entender → alterar código → reescrever este arquivo.
6. Criada regra Cursor `.cursor/rules/contexto-sistema.mdc` (`alwaysApply: true`) para a IA sempre passar por aqui.
