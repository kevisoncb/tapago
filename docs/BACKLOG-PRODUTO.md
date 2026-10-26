# Pagô — telas: o que tirar, mudar e adicionar

Visão de produto, escrita em 26/10/2026 a partir do que o código e a documentação descrevem. Não foi feita com o app aberto em aparelho: o primeiro passo de cada item é conferir na tela real. Cada bloco pode ser testado separadamente.

## Princípio

O comerciante abre o Pagô para responder três perguntas: quem me deve, quanto, e quem eu cobro hoje. Toda tela deve ajudar a responder uma delas ou sair do caminho.

## Hoje (tela inicial)

- **Tirar:** qualquer número que pareça saldo bancário ou lucro; dois resumos que repetem a mesma informação.
- **Mudar:** a primeira dobra mostra só "para cobrar hoje" (com nome, valor, atraso e botão de WhatsApp) e o total a receber da semana. Histórico e filtros descem.
- **Adicionar:** estado vazio útil ("nada para cobrar hoje") com atalho para lançar; um aviso discreto quando há promessas vencidas.
- **Testar:** com 0, 3 e 40 clientes; se dá para cobrar um cliente em até 2 toques.

## Clientes e caderneta do cliente

- **Tirar:** o que sobrou de score ou nota do cliente nas telas; campos de juros em destaque para quem vende fiado sem juros.
- **Mudar:** o saldo e o próximo vencimento ficam no topo; juros e detalhes ficam recolhidos.
- **Adicionar:** linha do tempo única (lançamento, pagamento, contato, promessa); indicação clara de "parcelado em 3x, 2 pagas"; busca por telefone.
- **Testar:** achar um cliente entre 100 em menos de 5 segundos.

## Novo lançamento

- **Tirar:** opções que só servem a poucos antes do básico (juros, voz, leitura de imagem competindo com o formulário).
- **Mudar:** o caminho curto é nome, valor, vencimento, salvar. O resto aparece sob "mais opções".
- **Adicionar:** parcelamento (Premium) com vencimento no mesmo dia dos meses seguintes e prévia; lançar para cliente já existente sem redigitar.
- **Testar:** tempo para o primeiro lançamento de quem nunca usou.

## Pagamentos e baixa

- **Mudar:** mostrar sempre o que será gravado antes de confirmar e dizer que é um registro informado por você, sem confirmação bancária.
- **Adicionar:** desfazer visível logo após a baixa; correção com motivo fácil de achar.
- **Testar:** erro de digitação de valor e correção, ponta a ponta.

## Cobrança e acompanhamento

- **Tirar:** nada. É o coração do produto.
- **Mudar:** a mensagem pronta vira escolha de tom (amigável, firme, último aviso), com prévia antes de abrir o WhatsApp.
- **Adicionar:** "prometeu pagar dia X" em um toque; lembrete do servidor para quem não abre o app; marca de quem já foi cobrado hoje.
- **Testar:** se o comerciante entende que o app não envia nada sozinho.

## Boletos de fornecedores

- **Mudar:** deixar claro que é o que ele paga, não o que recebe; mesma estrutura de vencimento e parcelas.
- **Avaliar:** se merece uma aba própria ou ficar dentro de "Mais" até haver uso comprovado.

## Mais, relatórios e exportação

- **Tirar:** dois caminhos para a mesma exportação; textos técnicos.
- **Mudar:** relatórios com linguagem de comerciante: recebido, a receber, atrasado.
- **Adicionar:** pedido de backup e restauração real; botão de ajuda e contato.
- **Fora por ora:** importação CSV. O código fica guardado, sem aparecer no app, para retomar depois.

## Assinatura e plano

- **Mudar:** mostrar o grátis ao lado do Premium; preço vindo da loja; sem pressão no primeiro dia.
- **Adicionar:** teste do Premium e plano anual, só depois de medir uso.
- **Testar:** se o usuário sabe o que perde ao cancelar (nada do essencial).

## Primeiro uso e abertura

- **Já feito:** abertura animada da marca (cerca de 2 segundos, respeita reduzir movimento).
- **Adicionar:** depois do primeiro lançamento, mostrar na hora a tela Hoje já preenchida, para provar o valor.

## Site

- Prévia do novo design em `docs/site-novo/`. Ainda falta: prints reais, confirmar o botão da Google Play depois da liberação pública e revisar os textos legais.

## Ordem sugerida de teste

1. Hoje + cobrança de um cliente.
2. Novo lançamento curto e parcelado.
3. Baixa e correção.
4. Assinatura.
5. Lembretes.
6. Site com o app público.
