# Medição: de onde vêm os usuários e o que rende

## O que o app mede (Firebase Analytics)
| Evento | Quando | Uso |
| --- | --- | --- |
| `first_open` (automático) | Primeira abertura depois da instalação | Instalação (campanhas de app) |
| `sign_up` | Conta criada | Cadastro |
| `primeiro_lancamento` | Primeiro lançamento da conta | **Evento de valor das campanhas** |
| `lancamento_criado` | Cada lançamento | Uso |
| `baixa_registrada` / `baixa_corrigida` | Pagamento informado / corrigido | Uso |
| `visualizou_premium` | Abriu a tela do Premium | Funil de assinatura |
| `purchase` | Assinatura concluída (com valor) | Receita |
| `avisos_ligados` | Ligou o resumo das 9h | Retenção |

Nenhum evento leva nome, telefone, valor da caderneta ou chave PIX.

## Origem da instalação
O app lê o Install Referrer da Play e registra uma vez, por conta, `utm_source`, `utm_medium`, `utm_campaign`. Sem utm, a origem é "orgânico". O painel admin, página **Marketing**, cruza isso com cadastros, 1º lançamento, uso e receita.

Use o gerador de links da página Marketing para cada canal (Instagram, TikTok, influenciador, QR, parceiro). O site já usa `utm_source=site`. O nome do canal no link deve ser o mesmo do investimento registrado.

## Google Ads (campanha de aplicativo)
1. Vincular o projeto do Firebase ao Google Ads (Firebase → Integrações → Google Ads).
2. No Firebase, marcar como **conversão** os eventos `primeiro_lancamento` e `purchase`.
3. Importar essas conversões no Google Ads e escolher "ação dentro do app" como objetivo, otimizando para `primeiro_lancamento`.
4. As campanhas de app do Google se atribuem sozinhas; não use link com utm nelas.

## Meta e TikTok
Usar o link com utm do gerador. Para otimizar pelo evento (e não só instalação), é preciso o SDK da plataforma ou o AppsFlyer: hoje o AppsFlyer só liga com a chave no build (`--dart-define=PAGO_AF_DEV_KEY=...`). Decidir antes da primeira campanha paga nesses canais.

## Como ler o retorno (página Marketing)
- **Custo por cadastro:** gasto do canal ÷ contas criadas.
- **Custo por 1º lançamento:** gasto ÷ contas que lançaram. É o número que mais importa.
- **Custo por pagante:** gasto ÷ contas que assinaram.
- **Retorno:** receita líquida das contas do canal ÷ gasto. Abaixo de 1x ainda não se paga; leve em conta que a assinatura rende por vários meses.
- Compare canais pelo custo por 1º lançamento antes de aumentar a verba.

## Limites
- Contas criadas antes desta medição aparecem como "Sem origem registrada".
- O painel não recebe do Google/Meta o gasto nem as instalações: lance manualmente em "Registrar investimento".
- O ID de publicidade está removido do app; isso reduz a precisão da atribuição no Android 13+ (ver `docs/play/SEGURANCA-DOS-DADOS.md`).
