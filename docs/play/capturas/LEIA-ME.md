# Capturas do app (demonstração)

Geradas em 27/10/2026 a partir do código, com a versão web de demonstração (`PAGO_DEMO=true`), em tela de celular 360×640 dp, exportadas em 1080×1920 (proporção 9:16, aceita pela Google Play). Os dados são fictícios (João Dinâmico, Mariana, Carlos...). **Não são capturas de aparelho real:** fonte, teclado e barra do sistema podem diferir. Para a ficha da loja, prefira os prints reais da empresa de teste.

## `publicada-main/` — o que está na Google Play hoje (2.4.0+25, branch `main`)
| Arquivo | Tela |
| --- | --- |
| 01-inicio | Início: saldo aberto, recebe esta semana, vencido a receber |
| 02-caderneta-lista | Lista "Na caderneta", com Score por cliente |
| 03-cliente | Perfil do cliente, com "Score de Confiança" |
| 04-boletos | Boletos a pagar |
| 05-configuracoes | Configurações |
| 06-novo-lancamento | Novo lançamento |

Atenção: a versão publicada mostra **Score de Confiança** (estrelas e "Score: 4") no cliente e na lista. Esse score foi retirado na `develop`.

## `develop-atual/` — o código de hoje (ainda não publicado)
| Arquivo | Tela |
| --- | --- |
| 01-abertura | Abertura animada da marca |
| 02-hoje | Hoje ("Meu dia"): a receber, previsto, vencido |
| 03-cobrancas-para-acompanhar | Agenda de cobrança |
| 04-clientes | Caderneta |
| 05-cliente | Contato com saldo, extrato e acompanhamento |
| 06-extrato-do-cliente | Extrato com PDF e CSV |
| 07-boletos | Boletos a pagar |
| 08-mais | Mais: perfil, relatórios, chave PIX, dados bancários |
| 09-relatorios | Relatórios |
| 10-acompanhamentos | Acompanhamentos |
| 11-mais-suporte-e-privacidade | Mais: preferências (resumo das 9h) |
| 12-assinatura | Mais: assinatura Premium |
| 13-novo-lancamento | Novo lançamento preenchido (exemplo) |

Para regenerar: construir a web com `flutter build web --release --dart-define=PAGO_DEMO=true` e rodar um script de navegação (Playwright) em viewport 360×640 com `deviceScaleFactor: 3`.
