# Pagô

Caderneta digital para pequenos comerciantes: vendas a prazo, pagamentos parciais, cobrança manual pelo WhatsApp e boletos a pagar. Aplicativo Flutter com Firebase; backend de assinaturas em Node.js.

Esta implementação está na `develop`. APK Android ARM64 compilado localmente; iOS preparado no código, aguardando compilação em macOS/Xcode. A produção exige a validação e a sequência de publicação descritas em [publicação financeira](docs/financial-data-rollout.md) e [backend](functions/README.md).

## Implementado nesta entrega

- Dashboard **Meu dia**, filtros de vencimento, resumo financeiro, pagamentos recentes e recuperação de falhas de sincronização.
- Relatórios por período de pagamentos recebidos, valores previstos, atrasos por faixa e boletos de fornecedores, com definições visíveis.
- Identidade visual atualizada, fontes incluídas no aplicativo, telas com suporte a texto ampliado. Renderizador web servido junto com o app, sem depender do CDN externo.
- Parcelamento a receber em até 12 parcelas, distribuição em centavos, prévia e proteção contra envio duplicado.
- Extrato do cliente em PDF/CSV; exportação dos registros carregados em JSON/CSV. Exportação não é restauração de backup e não inclui anotações de acompanhamento.
- Estorno com motivo e preservação do histórico; quitação registra um pagamento; gravações financeiras coordenadas.
- Acompanhamento privado de contato e promessa de pagamento, sem registrar recebimento nem enviar mensagem automaticamente.
- Recuperação de senha, identificação de dados em cache, tratamento de falhas de sessão e correção da leitura de comprovantes.
- Validação de assinatura no servidor antes de concluir a compra, proteção de titularidade, renovação, reembolso e exclusão de conta.
- Notificações com destino no app e reagendamento limitado; fila recuperável de atribuição de receita quando configurada.

O [plano de evolução](docs/EVOLUCAO.md) contém propostas adicionais. Integração bancária, carteira, liquidação PIX, pesquisa de mercado, precificação e aquisição de clientes continuam sendo etapas futuras. O site institucional não foi redesenhado nesta implementação.

## Executar

Ambiente validado: Flutter **3.47.7**, Dart **3.13.5**, Node **22**, Java **21** para o emulador Firestore.

```sh
flutter pub get --enforce-lockfile
flutter devices
flutter run -d <id-do-aparelho-android>
```

O desenvolvimento e a validação principal são do aplicativo móvel Android e iOS, usando Firebase e as lojas conforme o ambiente. Para uma demonstração secundária no navegador: `flutter run -d chrome --dart-define=PAGO_DEMO=true`; essa demonstração usa dados locais fictícios. Não colocar credenciais de servidor no app ou no Git.

## Verificar

```sh
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
npm ci --prefix functions
npm test --prefix functions
npm ci --prefix tool/rules
npx firebase-tools@15.34.1 emulators:exec --only firestore --project demo-pago --config firebase.test.json "node --test test/firestore_rules.test.cjs"
```

Em contêiner com diretório pessoal somente leitura, configurar `PUB_CACHE`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `ANALYZER_STATE_LOCATION_OVERRIDE` e `FIREBASE_EMULATORS_PATH` para diretórios graváveis; `FLUTTER_SUPPRESS_ANALYTICS=true` e `DART_SUPPRESS_ANALYTICS=true` evitam escrita de telemetria.

## Antes de publicar

- Testar Android/iOS em aparelho e validar compra, restauração, renovação, notificações, OCR e compartilhamento nas plataformas alvo. O build web não substitui esses testes.
- Regras novas e app novo exigem publicação coordenada. Depois da primeira operação financeira nova, versões antigas não podem gravar pagamentos naquela caderneta. Não publicar as regras isoladamente sem revisar o plano de atualização.
- Validar permissões da API Google Play: indisponibilidade agora recusa a concessão de Premium, em vez de conceder acesso sem verificação.
- Preservar chaves de assinatura, contas de revisão e dados existentes; incrementar o número de build antes de novo envio à loja.
- Armazenamento local migra para envelope único; um downgrade não lê alterações novas. Há limite de 400 pagamentos por caderneta no fluxo Firestore.

O roteiro para Android/iPhone e as configurações nativas estão em [VALIDACAO-MOBILE.md](docs/VALIDACAO-MOBILE.md).

Consulte [SISTEMA.md](SISTEMA.md) para o contexto atual e [VALIDACAO.md](docs/VALIDACAO.md) para a evidência desta entrega.
