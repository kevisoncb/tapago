# Pagô no iPhone — o que já está pronto e o que falta

O código do iPhone está preparado. Falta a conta Apple Developer (US$ 99/ano), que deve ser aberta no nome da empresa (Iris Tecnologia Ltda), com CNPJ e número D-U-N-S. Até lá, nada abaixo precisa de pagamento.

## Já pronto no repositório
- `ios/Runner/Runner.entitlements`: notificações push (`aps-environment`). Ligado nas 3 configurações do alvo Runner.
- `ios/Runner/Info.plist`: permissões (câmera, Face ID, fotos, microfone, voz, rastreio) e `UIBackgroundModes` com `remote-notification`.
- `codemagic.yaml`: build na nuvem (Mac) que gera o `.ipa` e envia ao TestFlight. Não envia para revisão da App Store.
- Compra pela App Store (StoreKit 2) em `lib/services/billing_service.dart`; servidor em `functions/apple.js` (`confirmApplePurchase`, `appleNotifications`), 37 testes passando.

## Depois de pagar a conta Apple (nessa ordem)
1. **App Store Connect → Apps → Novo app**: bundle ID `app.usepago`, nome "Pagô: Caderneta e Cobrança", idioma Português (Brasil).
2. **Assinatura**: Monetização → Assinaturas → grupo "Pagô Premium" → produto com ID **`pago_premium_monthly_ios`** (o código espera exatamente esse ID), mensal, preço R$ 19,90, com nome, descrição e uma captura da tela de assinatura.
3. **Chave da API do App Store Connect** (Usuários e acesso → Integrações → Chaves da App Store Connect): guardar o Issuer ID, o Key ID e o arquivo `.p8` (só baixa uma vez).
4. **Chave de push (APNs)**: Certificados, IDs e perfis → Chaves → marcar Apple Push Notifications → baixar o `.p8`. Enviar ao Firebase: Configurações do projeto → Cloud Messaging → app iOS → chave de autenticação APNs.
5. **Chave do servidor (assinaturas)**: em Usuários e acesso → Integrações → In-App Purchase, gerar a chave e anotar o Key ID e o `.p8`.
6. **Codemagic**: conectar o repositório, criar a integração `PagoAppStoreConnect` com a chave do passo 3, criar o grupo de variáveis `pago_ios` (marcar como secreto) e preencher `APP_STORE_APPLE_ID` em `codemagic.yaml` com o Apple ID numérico do app.
7. **Servidor**: preencher em `functions/.env` (nunca no git) `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` e `APPLE_APP_ID`. Só publicar as funções da Apple na ordem de `docs/financial-data-rollout.md` e com decisão do dono.
8. **App Store Server Notifications**: App Store Connect → Informações do app → apontar a URL da função `appleNotifications` (Produção e Sandbox).
9. **AppsFlyer** (opcional): `PAGO_AF_DEV_KEY` no grupo `pago_ios`; no servidor, `MMP_S2S_URL`, `MMP_S2S_TOKEN`, `MMP_APP_ID_IOS` (`id` + Apple ID numérico).
10. **Primeiro build**: rodar o workflow `ios-testflight`, instalar pelo app TestFlight num iPhone e testar login, lançamentos, assinatura em Sandbox e push.

## Antes de enviar para a revisão da Apple
- Botão **Restaurar compras** visível na tela do Premium.
- Aviso de renovação automática com preço, período e como cancelar (já existe em `premiumRenewalNotice`).
- **Excluir conta** dentro do app (exigência da Apple 5.1.1).
- Rastreio: o pedido de permissão (ATT) só liga com `--dart-define=PAGO_ATT=true`. Se ligar, o questionário de privacidade precisa declarar o uso. Sem AppsFlyer nem anúncios, deixe desligado.
- Conta de demonstração para o revisor, se o app exigir login.
- Política de privacidade e exclusão de conta abrindo: `https://usepago.web.app/privacidade` e `/excluir-conta`.

## Texto da App Store (rascunho)
**Nome (até 30):** Pagô: Caderneta e Cobrança
**Subtítulo (até 30):** Organize o fiado e cobre
**Palavras-chave (até 100, separadas por vírgula):** fiado,caderneta,cobrança,whatsapp,contas a receber,quem me deve,vendas a prazo,MEI,empréstimo
**Categoria:** Negócios (secundária: Finanças, se a Apple pedir)
**Texto promocional (até 170):** Saiba quem te deve, quanto e quando cobrar. Sua caderneta digital, com cobrança pelo seu WhatsApp.
**Descrição:** usar a de `docs/play/FICHA-DA-LOJA.md`, trocando "Google Play" por "App Store" e "Play Store → Pagamentos e assinaturas" por "Ajustes → seu nome → Assinaturas". Incluir, no fim, os links de Termos de Uso e Privacidade (a Apple exige para assinaturas).
**Capturas:** iPhone 6,9" (1320×2868) e 6,5" (1284×2778), mínimo 3 por tamanho; gerar a partir das de `docs/play/capturas/`.

## Questionário de privacidade (esboço, conferir com `docs/play/SEGURANCA-DOS-DADOS.md`)
Dados ligados ao usuário: e-mail e nome (conta), dados de uso (Firebase Analytics), identificadores (push), compras. Clientes e valores da caderneta ficam na conta do usuário e não são compartilhados. Rastreio: só se o ATT estiver ligado.
