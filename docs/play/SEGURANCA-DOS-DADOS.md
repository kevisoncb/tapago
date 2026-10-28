# Formulário "Segurança dos dados" (Play Console) — rascunho

Montado a partir do código e das permissões do APK de 27/10/2026. **Revise antes de enviar:** a declaração é de responsabilidade do titular do app, e uma resposta errada pode derrubar o app. Em caso de dúvida, consulte um profissional de privacidade/LGPD.

## Permissões do aplicativo
INTERNET, CAMERA (leitura de comprovante), RECORD_AUDIO (voz), USE_BIOMETRIC, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, BILLING (assinatura), WAKE_LOCK, VIBRATE, leitura do Install Referrer da Play (origem da instalação). O ID de publicidade **está removido** do manifesto (`com.google.android.gms.permission.AD_ID`).

Decisão pendente: manter o AD_ID removido protege a privacidade, mas reduz a precisão da medição de campanhas pagas no Android 13+. Se for investir em anúncios de instalação, avalie liberar e atualizar este formulário.

## Coleta e compartilhamento por tipo de dado
| Tipo | Coletado? | Para quê | Compartilhado? | Opcional? |
| --- | --- | --- | --- | --- |
| Nome | Sim | Funcionamento do app, conta | Não | Não |
| E-mail | Sim | Conta, login, suporte | Não | Não |
| Telefone do usuário | Sim | Perfil | Não | Sim |
| Clientes que o usuário cadastra (nome e telefone) | Sim (conteúdo do usuário) | Funcionamento do app | Não | Não |
| Valores e vencimentos da caderneta (informação financeira) | Sim | Funcionamento do app | Não | Não |
| Histórico de compras (assinatura Premium) | Sim | Validar o Premium | Com a loja (Google) | Não |
| Áudio (voz) | Processado no aparelho para ditado | Lançamento por voz | Confirmar se o serviço de reconhecimento do sistema envia o áudio ao Google | Sim |
| Fotos (comprovante) | Lidas no aparelho (reconhecimento de texto) | Leitura de comprovante | Não | Sim |
| Registros de falhas e diagnóstico | Sim (Crashlytics) | Estabilidade | Com o Google (Firebase) como prestador | Não |
| Identificadores do app e do aparelho | Sim | Análise de uso, medição de campanhas (Analytics, AppsFlyer se configurado) | Com os prestadores de análise | Não |
| Eventos de uso (ex.: primeiro lançamento) | Sim | Análise e medição | Com Google Analytics; AppsFlyer se ativado | Não |
| Origem da instalação (utm) | Sim | Medir qual canal trouxe o usuário | Não | Não |

## Práticas
- **Criptografia em trânsito:** sim (HTTPS).
- **Exclusão de dados:** o usuário pode pedir a exclusão pelo app e pela página `excluir-conta`. Registros financeiros retidos seguem a política de retenção (definir e publicar).
- **Sem venda de dados.** Os dados dos clientes cadastrados pelo usuário não são usados para cobrança nem marketing pela equipe do Pagô.

## Pontos a confirmar antes de enviar
1. Se o reconhecimento de voz usa o serviço do sistema (que pode enviar áudio a servidores do Google).
2. Se o AppsFlyer entra no build de produção (hoje só liga com a chave no build).
3. Política de retenção após a exclusão da conta.
