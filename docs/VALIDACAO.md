# Validação da entrega — 26/10/2026

Branch `develop`, base `2c987d5e7161123b511d99971a903440033d77ce`. Verificações locais; nenhum deploy foi realizado. O alvo principal é o aplicativo Android e iOS. A demo web é apenas apoio e não substitui a validação nativa.

| Verificação | Resultado |
| --- | --- |
| APK Android release ARM64 | Compilação aprovada em 26/10, assinatura local de debug; envio de símbolos Crashlytics excluído somente do comando local |
| APK: assinatura, pacote e 16 KB | Verificados: app.usepago, 2.4.0+25, minSdk 24, targetSdk 36; zipalign e 5 bibliotecas ARM64 compatíveis com alinhamento de 16 KB |
| Flutter analyze | Sem problemas encontrados |
| Flutter test | 76 testes aprovados, incluindo navegação, relatórios, importação CSV, primeiro uso, acessibilidade, métricas mínimas e agenda de cobrança |
| Backend Node 22 | 23 testes aprovados |
| Regras Firestore, projeto demo-pago | 9 testes aprovados |
| Build web release, PAGO_DEMO=true | Compilação aprovada; renderizador local incluído |
| Chromium, viewport 390 × 844 | Dashboard da demo abriu sem erros JavaScript nem aviso de falha de carregamento |
| Site institucional local | HTML e `styles.css` respondem separadamente com HTTP 200; configuração dedicada aponta o Hosting `usepago` para a pasta `site` |
| git diff --check | Sem erros de whitespace |

Testes cobrem regressões existentes, parcelas e centavos, pagamento duplicado, quitação e estorno, isolamento de contas, campos imutáveis, titularidade de assinatura, falha de verificação da loja, eventos atrasados, exclusão, retomada de atribuição, recuperação de senha, notificações e layouts com texto ampliado. Testes do backend usam dependências simuladas: não comprovam configuração real das lojas.

A revisão de acessibilidade agrupou título, valor e contexto dos cartões financeiros, associou os rótulos visuais aos campos editáveis, definiu ações de teclado e nomeou o seletor de vencimento. O cartão do cliente e a cobrança pelo WhatsApp são expostos como ações distintas. TalkBack e VoiceOver em aparelhos reais continuam pendentes.

As métricas de produto registram somente atributos operacionais limitados depois da confirmação da escrita. Baixa manual e correção de baixa descrevem ações no organizador; não são confirmação bancária. O teste injetável comprova primeiro lançamento, origem CSV e conclusão manual de uma caderneta sem depender do SDK externo. Entrega real e visualização no AppsFlyer dependem das chaves e do painel de produção.

A agenda do Meu dia cobre promessa vencida, contato atrasado, data de hoje, próximos sete dias e cliente vencido sem contato. O teste confirma que uma promessa exibida não cria baixa nem altera a caderneta. A listagem local permanece isolada por conta; a consulta Firestore usa o proprietário autenticado.

O build JavaScript emite aviso de incompatibilidade potencial WebAssembly em `flutter_timezone` e referência a fonte Cupertino ausente. Não foi gerado build WebAssembly. A interface usa Material Icons; suporte nativo continua dependente de validação em aparelho.

A revisão visual identificou rótulos de botões sem fonte explícita; os estilos agora herdam a fonte local do tema.

A primeira inspeção em Chromium revelou falha de carregamento do CanvasKit pelo CDN externo. `web/flutter_bootstrap.js` passou a usar o renderizador incluído em `build/web/canvaskit`, eliminando essa dependência de inicialização. A inspeção também identificou inicialização indevida de compras nativas no navegador; o serviço agora inicia somente em plataformas suportadas (ou quando injetado em teste).

Os testes automatizados acima foram concluídos em 24/10; a compilação Android foi concluída em 26/10 com SDK e JDK completos. O comando padrão encontrou HTTP 403 ao enviar o mapa de símbolos ao Crashlytics; o build local foi concluído excluindo apenas essa tarefa, sem alterar a configuração de produção.

## Não verificado nesta entrega

- AAB/APK com assinatura de publicação, Android/iOS em aparelho, permissão e entrega real de notificações.
- Compras reais/sandbox, renovação, restauração e configurações dos consoles.
- Compartilhamento nativo, câmera/OCR e biometria em aparelho.
- Migração de dados reais, concorrência entre aparelhos em produção e atualização coordenada de clientes antigos.
- Implantação de regras, Functions, site ou demonstração pública.

O endereço público não pôde ser consultado deste ambiente porque o proxy recusou a conexão com Firebase Hosting. A correção do diretório de publicação foi validada localmente, mas ainda precisa ser publicada para alterar o site no ar.

Antes de publicar, executar a sequência de [publicação financeira](financial-data-rollout.md). A segurança de escrita nova pode recusar pagamentos de aplicativos antigos após marcação do ledger; não prometer atualização transparente. A entrega implementa uma etapa do [plano de produto](EVOLUCAO.md), não todas as propostas comerciais e bancárias.

## Artefato Android local

- Arquivo: `build/app/outputs/flutter-apk/app-release.apk` (58.002.369 bytes), recompilado após integrar o seletor nativo de CSV.
- SHA-256: `ed70e35f6f29c75b6c473a779122f573a55382b1c82f5c9aac0e948ea2c9f2a3`.
- Modo release, arquitetura Flutter ARM64, certificado Android Debug. Não enviar esse artefato à Play; usar aparelho/perfil de teste sem substituir a instalação de produção.
- Build nativo concluiu `lintVitalRelease`, otimização R8, empacotamento e assinatura. Avisos remanescentes: plugins que usam KGP legado, leitura de metadados SDK mais novos, aviso R8 do SDK AppsFlyer e deprecações de Gradle. Não foi atualizada a cadeia de plugins apenas para eliminar esses avisos; revisar antes de uma futura atualização de Gradle/Flutter.
- Procedimento de reprodução e roteiro de aparelhos: [VALIDACAO-MOBILE.md](VALIDACAO-MOBILE.md).
