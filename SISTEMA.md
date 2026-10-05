# TáPago — Contexto do sistema

Arquivo vivo. Reescrito a cada alteração.

## Como a IA deve usar (obrigatório)

1. Ler este arquivo.
2. Código no Git × o que vive só no Console.
3. Implementar.
4. Apagar e reescrever este arquivo.
5. Entre PCs, o contexto commitado é `origin/main`.

## Git neste PC

- Branch `main`. Este commit sobe o overlay da caderneta para o remoto.

## O que o app faz agora

Caderneta de fiado/empréstimo. Contatos na Configurações (pagos ou não). WhatsApp já usado por outra pessoa trava o Salvar. Sem “lançar mesmo assim”. Novo lançamento da mesma gente só pelo contato.

Abater: sem juros, teclado direto; com juros, total / parte / juros do mês.

Premium **R$ 39,90/mês**: voz no microfone e OCR no celular (ML Kit). Grátis: caderneta, WhatsApp no aparelho da pessoa, abate, dados na conta. Sem PDF. Sync/backup não são extra: são o banco da conta.

Site em `site/`: planos alinhados a isso. Hosting ainda precisa de redeploy.

## Mapa

- App: `lib/`
- Site: `site/`
- Preço: `lib/utils/constants.dart`

## Pendências

Redeploy hosting. Play (IAP a R$ 39,90). Functions/Asaas no ar. Testar voz e OCR no aparelho.

## Última sessão (5/out)

App local desligado. Commit e push do overlay (caderneta, voz, OCR, site, duplicata).
