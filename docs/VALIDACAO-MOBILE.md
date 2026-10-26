# Validação do aplicativo Android e iOS

O produto é o aplicativo móvel em Flutter, com base compartilhada para Android e iOS. A demo web é apoio visual secundário.

## Android

Toolchain local: Flutter 3.47.7, Dart 3.13.5, JDK 21 (incluindo `javac`), Android SDK 36, Build Tools 36.0.0, NDK 28.2.13676358; Gradle e plugins conforme arquivos do projeto.

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

Para gerar somente o APK local em ambiente que bloqueia o envio de símbolos ao Crashlytics, executar a partir de `android/`:

```sh
./gradlew :app:assembleRelease -x :app:uploadCrashlyticsMappingFileRelease -Ptarget-platform=android-arm64 -Ptarget=lib/main.dart -Pdart-obfuscation=false -Ptrack-widget-creation=false -Ptree-shake-icons=true
```

Essa exclusão vale apenas para a execução local. O fluxo de publicação deve enviar os mapas de símbolos; a configuração de produção do Crashlytics foi preservada.

Sem `android/key.properties`, a configuração existente usa assinatura de debug mesmo no modo release. Esse APK é para validação, não é o artefato assinado para envio à Play. Não desinstalar o aplicativo existente para contornar assinatura incompatível; usar aparelho/perfil de teste.

## iOS

O alvo mínimo é iOS 15.5, exigido pelo ML Kit já usado no aplicativo. O Podfile mantém esse mínimo também nas dependências CocoaPods, preservando mínimos superiores. Swift Package Manager continua referenciado no projeto; o Flutter coordena plugins que necessitam de CocoaPods. Não remover um gerenciador sem verificar os plugins resolvidos.

Configurações revisadas: pacote `app.usepago`, descrições de câmera, fotos, microfone, voz e Face ID, abertura do WhatsApp, delegate de notificações e origem do popover de compartilhamento. Assinaturas usam o produto iOS e verificação Apple no servidor. O suporte no código não significa aprovação na App Store.

Em macOS com Xcode compatível com o Flutter e CocoaPods instalado:

```sh
flutter pub get --enforce-lockfile
flutter build ios --release --no-codesign
open ios/Runner.xcworkspace
```

Configurar a equipe Apple e assinatura no Xcode. Validar os plugins resolvidos, testar em aparelho e só então preparar o IPA/TestFlight. Não foi executado build iOS neste ambiente Linux. A criação/atualização do Podfile.lock depende da resolução real no Mac e deverá ser revisada e versionada antes de distribuir.

## Roteiro funcional em aparelhos de teste

1. Entrar, sair, recuperar senha e tentar abrir com conexão indisponível. Conferir que dados salvos não são apresentados como atualização confirmada.
2. Criar venda simples e parcelada. Conferir centavos, vencimentos, prévia, toque duplo e repetição após falha.
3. Registrar parcial, juros e quitação. Confirmar saldo e histórico, inclusive após fechar e reabrir. Repetir com dois aparelhos usando a mesma conta de teste.
4. Estornar com motivo, conferir reabertura do saldo e preservação do pagamento original. Repetir tentativa de estorno.
5. Exportar PDF/CSV, abrir os arquivos, conferir valores e acentuação; testar compartilhamento em Android, iPhone e iPad.
6. Registrar contato e promessa; confirmar que isso não altera o saldo nem envia mensagem automaticamente.
7. Testar câmera/OCR, fotos e voz com permissão concedida e recusada. Confirmar o valor antes de registrar pagamento.
8. Ativar biometria e testar retomada, falha/cancelamento e troca de conta.
9. Autorizar notificações; testar app aberto, em segundo plano, encerrado e após reiniciar o aparelho. Toque deve abrir o cliente/boleto correto, sem disparar WhatsApp.
10. Em contas de teste das lojas: comprar, restaurar, renovar, cancelar e reembolsar. Simular indisponibilidade do servidor; não conceder Premium sem validação e permitir retomada.
11. Excluir conta de teste e verificar que eventos atrasados não recriam perfil ou benefício. Preservar as contas de revisão das lojas.

Para implantação, seguir também [publicação financeira](financial-data-rollout.md). Os testes locais não comprovam as permissões/configurações do Console nem garantem comportamento de todos os aparelhos.
