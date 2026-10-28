# Liberação em etapas na Google Play

## Antes de começar
- Confirmar que o AAB da produção é o da `main` (2.4.0+25), com a assinatura de produção.
- Site público com política de privacidade e exclusão de conta no ar.
- Ficha da loja e formulário de segurança dos dados preenchidos.
- Canal de suporte funcionando (ver `docs/SUPORTE.md`).
- Alguém de plantão nas primeiras 24 horas.

## Etapas sugeridas
| Etapa | % | Quando avançar |
| --- | --- | --- |
| 1 | 10% | Depois de 24 a 48 horas sem falhas novas e sem avaliação 1 estrela repetida |
| 2 | 50% | Depois de 2 a 3 dias estáveis |
| 3 | 100% | Depois de uma semana estável |

Na Play Console: Produção → Criar nova versão → "Lançamento em etapas" (percentual).

## O que olhar antes de cada avanço
- **Falhas e ANR** (Play Console → Qualidade do app; Crashlytics). Meta: nenhuma falha que afete o login, a caderneta ou a assinatura.
- **Avaliações e comentários:** responder todos em até 48 horas.
- **Painel admin:** cadastros, quem fez o 1º lançamento, quem voltou em 7 dias, assinaturas e recusas de pagamento.
- **Suporte:** perguntas repetidas viram texto de ajuda.

## Quando parar
Parar a liberação (Play Console → Parar liberação) se houver:
- falha no login ou na abertura do app para mais de poucos usuários;
- perda ou duplicação de dados na caderneta;
- cobrança de assinatura errada.

## Depois
A versão da `develop` sai como nova versão (2.5.0), com publicação coordenada das Functions e regras (`docs/financial-data-rollout.md`) e nova liberação em etapas.
