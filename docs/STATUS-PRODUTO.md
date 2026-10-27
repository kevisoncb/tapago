# Pagô — situação do produto e plano de divulgação

Escrito em 27/10/2026 a partir do código das branches `main` e `develop`, dos documentos do projeto e dos testes que rodei. Nada aqui foi visto funcionando num aparelho, exceto o que a empresa de teste validou (não tenho esses resultados). Legenda: ✅ existe e foi testado em código; 🟡 existe na `develop`, fora do app publicado; ❌ não existe; ⚠️ existe com ressalva.

## 1. A pergunta que decide tudo: qual versão sai hoje

A `main` (o que a Play publica, `2.4.0+25`) e a `develop` têm o **mesmo número de versão** e códigos bem diferentes: 57 arquivos do app e mais de 8 mil linhas de diferença. A `develop` traz a agenda de cobrança, os relatórios, o extrato em PDF, a exportação, o parcelamento a receber, o ledger de pagamentos com estorno, a abertura animada e o push. **Nada disso está no app que vai para produção hoje**, a menos que você envie um build novo.

Subir a `develop` hoje não é recomendável: ela depende da publicação das Functions e das regras do Firestore, na ordem de `docs/financial-data-rollout.md`, e as Functions ainda não foram publicadas. Divulgue apenas o que está na `main`.

## 2. O que o app faz

### Na versão da Play (`main`) — base da divulgação de hoje
| Área | Status |
| --- | --- |
| Cadastro e login por e-mail, recuperação de senha | ✅ |
| Caderneta de clientes: lançar fiado, venda a prazo, empréstimo | ✅ |
| Vencimento, juros opcionais, pagamentos parciais, quitação | ✅ |
| Cobrança pelo WhatsApp do usuário, com mensagem pronta (amigável, no dia, atraso) e chave PIX junto | ✅ |
| Painel inicial com saldo aberto, a receber na semana e vencido | ✅ |
| Lembretes locais de vencimento (dia anterior, no dia, atraso) | ⚠️ dependem de permissão e do aparelho (ver 4) |
| Boletos de fornecedores (Premium) | ✅ |
| Lançamento por voz e leitura de comprovante por foto (Premium) | ✅ |
| Biometria para abrir o app, exclusão de conta | ✅ |
| Assinatura Premium pela Google Play | ✅ validação no servidor |

### Só na `develop` — ainda não está com os clientes
| Área | Status |
| --- | --- |
| Navegação Hoje / Clientes / Boletos / Mais e painel "Meu dia" com agenda de cobrança | 🟡 |
| Acompanhamento: contato, promessa de pagamento, filtros e indicadores | 🟡 |
| Relatórios (recebido, previsto, vencido, atrasos), extrato PDF/CSV, exportação | 🟡 |
| Parcelamento a receber (Premium), vencimento no mesmo dia dos meses seguintes | 🟡 |
| Ledger de pagamentos: idempotência, estorno com motivo | 🟡 (exige migração coordenada) |
| Abertura animada da marca | 🟡 |
| Push das 9h pelo servidor | 🟡 (exige Functions no ar) |
| Primeiro uso orientado, acessibilidade revisada | 🟡 |
| Importação CSV | ⏸️ código guardado, fora do menu por decisão sua |

### Não existe
- Carteira, PIX integrado, conciliação bancária, cobrança automática: ❌ (decisão: o Pagô não movimenta dinheiro).
- Equipe/vários usuários, acesso do contador: ❌
- Backup e restauração pelo usuário (a exportação não restaura): ❌
- App para iPhone publicado: ❌ (código preparado, sem build, sem APNs, backend da Apple não publicado)
- Plano anual, teste grátis do Premium, indicação com benefício: ❌
- Análise de uso dentro do app (Firebase Analytics): ❌ (ver 5)

## 3. Está 100%?

**Não. Está pronto para ser testado por gente real, não para escala.**

- **Validado:** a versão da Play passou pelo teste interno e fechado. Não tenho os resultados detalhados da empresa.
- **Verificado por mim, na `develop`:** análise estática limpa, 95 testes do app, 30 do backend, 9 das regras, APK release compilado.
- **Não verificado:** entrega do push em aparelho, compras reais e renovação em produção, comportamento com dados antigos após a migração, iPhone.
- **Dívidas conhecidas:** código sem uso (Asaas/PIX legado, `trust_score`, stub de WhatsApp, CSV parado), telas muito grandes, avisos de Gradle/R8, envio de símbolos do Crashlytics recusado com 403.

## 4. Lembretes: o que é e o que não é garantido
- Os avisos locais dependem da permissão de notificação do sistema; antes desta semana o app **não a pedia** no fluxo diário. A `develop` corrige isso.
- No Android o horário pode atrasar em economia de bateria; a agenda cobre 14 dias e só se refaz quando o app abre.
- O push do servidor resolve isso, mas só vale depois do deploy das Functions e de uma nova versão.

## 5. Antes de gastar com anúncio
1. **Medição.** O app não tem Firebase Analytics, e o AppsFlyer só liga se a chave for passada no build (`PAGO_AF_DEV_KEY`). Sem isso, os anúncios de instalação não conseguem medir cadastro, primeiro lançamento nem assinatura. Para campanhas de app no Google Ads é preciso medir pelo menos instalação e um evento de valor (primeiro lançamento).
2. **Página pública.** O site no ar ainda é a versão antiga, com o "Score de Confiança 92/100" e a promessa de que a IA "baixa o saldo". A página de privacidade e termos corrigida está na `main`, mas **não publicada**. A Play exige política de privacidade acessível: publique o site antes de divulgar.
3. **Ficha da Play.** Capturas reais da versão publicada, descrição sem promessas que o app não cumpre, formulário de Segurança dos dados, categoria e palavras-chave.
4. **Suporte.** Um canal de resposta rápida (WhatsApp ou e-mail). Para um app que lida com dinheiro, resposta lenta mata avaliação.
5. **Lançamento gradual.** Na Play, liberar em etapas (por exemplo 10%, 50%, 100%) e acompanhar falhas no Crashlytics e as avaliações antes de ampliar.

## 6. Como divulgar (comece pelo barato e meça)

**Sem custo, começa hoje**
- **Sua própria rede e WhatsApp:** o público é o comerciante que já usa WhatsApp para cobrar. Peça a 20 a 50 conhecidos que cadastrem 3 clientes e peçam uma opinião. Isso gera as primeiras avaliações reais.
- **Conteúdo curto em vídeo** (Instagram Reels, TikTok, YouTube Shorts): demonstração de 30 segundos de "lançar o fiado, ver quem cobrar hoje, cobrar no WhatsApp". Mostre o app, não promessas.
- **Grupos e comunidades de comerciantes, MEI e pequenas lojas:** participe e ajude antes de divulgar; respeite as regras de cada grupo.
- **Parceiros que já falam com o público:** contadores e escritórios de contabilidade, associações comerciais, Sebrae local, distribuidores e atacadistas. Ofereça uma conta de teste e um material de uma página.
- **Ficha da loja bem feita (ASO):** título e descrição com os termos que o comerciante procura (caderneta digital, controle de fiado, cobrança no WhatsApp).
- **Avaliações:** peça avaliação depois que o usuário cobra com sucesso, não na primeira abertura.

**Com verba**
- **Google Ads, campanhas de aplicativo:** aprendem sozinhas com o evento que você mede. Comece pequeno e otimize para o primeiro lançamento, não só para a instalação.
- **Meta (Instagram e Facebook), anúncio de instalação do aplicativo:** bom para segmentar por interesse em pequeno negócio e por região.
- **TikTok Ads** e **influenciadores locais** de empreendedorismo: teste um criador pequeno antes de contratar um grande.
- **Orçamento de teste:** algo como R$ 30 a R$ 50 por dia por canal, por 7 a 14 dias, sem expectativa de escala. Os valores de custo por instalação mudam muito; não confio em números genéricos e prefiro que você meça os seus.
- **Decida com dados:** custo por instalação, custo por primeiro lançamento, retorno na semana seguinte e conversão para o Premium. Só aumente a verba no canal em que o primeiro lançamento sai barato.

**Cuidados**
- Anunciar só o que a versão publicada faz.
- Não prometer "fim da inadimplência" nem "cobrança automática".
- Dizer com clareza que o Pagô não é banco e não movimenta dinheiro.
- Preço: o Premium está configurado em R$ 39,90; a recomendação é testar R$ 19,90 e plano anual antes de investir pesado.

## 7. O que faria hoje, em ordem
1. Confirmar qual AAB vai para produção (o da `main`).
2. Publicar o site (`usepago`) com as correções, após sua aprovação, antes das 19h.
3. Liberar a produção em etapas e acompanhar o Crashlytics.
4. Convidar os primeiros 30 usuários pelo WhatsApp.
5. Em paralelo, preparar a medição (Analytics ou AppsFlyer) para a primeira campanha paga.
6. Depois: publicar Functions e regras, subir a `develop` como `2.5.0`, ligar o push das 9h.
