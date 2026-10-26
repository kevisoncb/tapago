# Publicação coordenada da integridade financeira

As alterações são aditivas: documentos antigos continuam legíveis, parcelas simples têm defaults e pagamentos sem metadados continuam válidos. Não executar limpeza, reset ou migração em produção como parte da instalação.

## Ordem de publicação

1. Validar regras no Emulator e os testes de repositório/fluxos em uma base de desenvolvimento.
2. Publicar as regras compatíveis com os novos campos antes de distribuir o novo aplicativo.
3. Distribuir a nova versão de forma controlada e comunicar atualização dos aparelhos que compartilham a mesma conta.
4. A primeira operação financeira do cliente novo marca a caderneta com `ledger_revision`. Daí em diante, pagamentos e estornos exigem incremento atômico dessa revisão junto com a alteração do pagamento. Uma versão antiga continua lendo a caderneta, mas suas gravações financeiras sem coordenação são recusadas: atualizar o app, nunca fazer fallback para gravação insegura.

Essa política protege concorrência entre clientes atualizados. Não representa compatibilidade transparente com gravações financeiras de versões antigas. Na primeira inicialização de um ledger legado, evitar que outra versão antiga grave simultaneamente: as escritas antigas não possuem revisão nem lock de documento. Uma integração futura de gravações exclusivamente no servidor é necessária para suportar clientes arbitrários sem esse requisito de atualização.

## Transação Firestore

O SDK móvel não oferece query dentro da transação. O cliente lê a revisão e os pagamentos apenas daquela caderneta no servidor; a transação relê os documentos e confere a revisão antes de gravar. Se outra sessão atualizada vencer, o cliente repete a leitura completa. O grupo de parcelas usa lote atômico de até 12 itens.

Há limite conservador de 400 registros de pagamento por caderneta para não criar transações sem limite de tamanho. Não é limite de clientes ou de vendas por conta. Ao atingir esse histórico, a operação recusa com mensagem explícita; não apaga dados nem grava parcialmente. Antes de remover essa proteção, implementar fechamento/compactação auditável do ledger ou endpoint transacional no servidor e testar os limites reais.

Após marcação, valor principal e taxa de juros não podem ser alterados pela edição comum: criar um novo lançamento ou um futuro fluxo explícito de renegociação. Pagamentos são imutáveis; correção é um estorno com motivo, data do servidor e recálculo da situação. A autorização das regras garante dono, vínculo e coordenação; a aritmética do ledger também é validada no cliente e deve ser levada ao servidor antes de tratar esses registros como liquidação bancária.

## Armazenamento local

`pago_<uid>_finance_v1` guarda as listas relacionadas em um único JSON. Essa gravação é o ponto de commit para pagamento e quitação. Os nomes legados são lidos quando ainda não existe envelope e permanecem preservados. Não há downgrade automático: uma versão antiga que só lê as chaves legadas não verá edições realizadas no envelope novo. Exportar e validar recuperação antes de qualquer rollback de versão local.

SharedPreferences não é banco transacional nem cofre criptografado. A serialização protege operações dentro deste processo; não oferece coordenação entre processos ou garantia de recuperação após falha física do armazenamento. O escopo do modo local permanece demonstração/armazenamento auxiliar, não uma promessa de offline-first.

## Verificação

- `flutter test test/payment_ledger_test.dart`
- Instalar dependências: `npm ci --prefix tool/rules`. Executar: `npx firebase-tools@15.34.1 emulators:exec --only firestore --project demo-pago --config firebase.test.json "node --test test/firestore_rules.test.cjs"` (Java 21 e Node 22).
- Testar duas sessões no mesmo débito, repetição de pagamento com o mesmo ID, erro antes/depois do commit, quitação e estorno.
- Testar usuário A versus B, dívida inexistente, modificação de valor original do pagamento, alteração de principal com ledger marcado e app antigo sobre caderneta marcada.

Não publicar a aplicação nova com regras antigas nem declarar compatibilidade em produção sem testar o artefato e a sequência acima.
