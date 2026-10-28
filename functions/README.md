# Functions — validação e direitos de assinatura

## Verificar localmente

Com Node 22, instale as dependências pelo lockfile:

```bash
cd functions
npm ci
node --test test/*.test.js
```

Os testes usam Firestore, autenticação e respostas das lojas simulados. Nenhum
pagamento, publicação ou alteração de dados de produção é executado. Eles
verificam invariantes do backend; a integração real com Play/App Store e o
comportamento do aplicativo ainda precisam de testes de licença e Sandbox.

## Compatibilidade e publicação

Os campos públicos de `Users` continuam os mesmos. A reconciliação escolhe o
maior direito ativo entre assinaturas verificadas da Play/App Store e uma
cortesia/PIX legado ainda vigente. Uma expiração não apaga um direito válido
de outra origem. Tokens substituídos de uma assinatura Play são retirados da
seleção ao receber uma resposta com `linkedPurchaseToken`.

Não há concessão nova sem validação da Play. Indisponibilidade/autorização da
API responde 503 e preserva o perfil existente; compra inválida responde 402.
Compras antigas sem identificador da conta só podem ser restauradas se já
estiverem vinculadas ao mesmo usuário no servidor. Demais casos precisam de
verificação pelo suporte, não de atribuição automática ao primeiro solicitante.

`playNotifications` solicita retry para falhas recuperáveis. A função busca o
estado atual da assinatura; tokens permanentemente inválidos são ignorados.
Verificar as permissões da Android Publisher API e a configuração Pub/Sub no
ambiente antes de testar compra e renovação reais.

## Coleções exclusivas do servidor

- `DeletedAccounts/{uid}`: marcador gravado antes da exclusão de dados. Impede
  recriação de perfil por eventos atrasados. As regras devem impedir também
  escritas de um cliente com sessão ainda válida quando esse marcador existe.
- `PlaySubscriptions` / `AppleSubscriptions`: dados verificados por origem.
  Exclusão da conta marca os registros como `deletedAccount` e remove tokens
  operacionais; registros financeiros e seu vínculo são retidos pelo servidor.
- `MmpOutbox`: fila de receita S2S, criada atomicamente com o evento de negócio
  apenas quando AppsFlyer está configurado e a compra não é de teste.

O catch-all das regras nega acesso direto a essas coleções. Antes de publicar,
definir a finalidade e os prazos de retenção dos registros financeiros,
marcadores e histórico de entrega; não há promessa automática de expurgo ou
TTL configurado por este código.

## AppsFlyer: envio recuperável

`retryMmpRevenue` é uma nova função agendada a cada 15 minutos. Seu deploy cria
um agendamento Cloud Scheduler, sujeito aos custos do serviço. Sem configuração
MMP, não são criados novos trabalhos de envio.

Cada trabalho tem lock de 5 minutos, backoff e até 10 tentativas. Falhas finais
ficam com `state: "failed"` e `lastReason` para investigação. Depois de corrigir
a causa, uma intervenção autorizada pode redefinir `state` como `pending`,
`attempts` como 0 e `nextAttemptAt` como uma data passada para retomar o envio.
Não modificar o identificador da transação para simular uma venda nova.

A entrega é **pelo menos uma vez**, não exatamente uma vez. Se o destinatário
aceitar o evento e a resposta se perder, uma repetição é possível; o pedido
permanece em `af_order_id` para conciliação. O saldo/benefício do assinante não
depende do sucesso desse envio de marketing.

## Cuidados de implantação

Publicar só depois de executar análise/testes do app e das regras junto às
Functions. Não trocar configurações das lojas nem desativar as rotas PIX
antigas sem inventariar clientes. Validar compra, restauração, renovação,
cancelamento, reembolso, exclusão e eventos atrasados com contas de teste.
Nada neste trabalho foi publicado automaticamente.
