#!/usr/bin/env python3
"""Gera as páginas de apoio e jurídicas do site (site/*.html) a partir do conteúdo abaixo.
Uso: python3 tool/build-legal.py   (rode na raiz do repositório)"""
import pathlib, shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
UPDATED = "27 de outubro de 2026"
WA = "https://wa.me/5527999019162?text=Oi%2C%20vim%20pelo%20Pag%C3%B4%20e%20quero%20tirar%20uma%20d%C3%BAvida."
WA_LGPD = "https://wa.me/5527999019162?text=Oi%2C%20quero%20fazer%20um%20pedido%20sobre%20meus%20dados%20(LGPD)."
WA_DEL = "https://wa.me/5527999019162?text=Excluir%20minha%20conta"
PLAY = "https://play.google.com/store/apps/details?id=app.usepago&referrer=utm_source%3Dsite%26utm_medium%3Dwebsite%26utm_campaign%3Dlegal"

MARK = ('<svg viewBox="0 0 512 512" aria-hidden="true"><rect width="512" height="512" rx="114" fill="#2F6BFF"/>'
        '<path d="M132 268 L228 364 L348 176" fill="none" stroke="#fff" stroke-width="58" stroke-linecap="round" stroke-linejoin="round"/>'
        '<circle cx="402" cy="110" r="32" fill="#fff"/></svg>')

NAV = [("ajuda", "Ajuda"), ("privacidade", "Privacidade"), ("termos", "Termos"), ("lgpd", "LGPD"), ("excluir-conta", "Excluir conta")]


def page(slug, title, description, eyebrow, h1, body, summary=None, toc=None, updated=True):
    nav = "".join(
        f'<a href="./{s}"{" aria-current=\"page\"" if s == slug else ""}>{t}</a>' for s, t in NAV
    )
    summary_html = ""
    if summary:
        items = "".join(f"<li>{i}</li>" for i in summary)
        summary_html = f'<div class="summary"><h2>Em resumo</h2><ul>{items}</ul></div>'
    toc_html = ""
    if toc:
        items = "".join(f'<li><a href="#{a}">{t}</a></li>' for a, t in toc)
        toc_html = f'<nav class="toc" aria-label="Neste documento"><h2>Neste documento</h2><ol>{items}</ol></nav>'
    upd = f'<p class="updated">Última atualização: {UPDATED}.</p>' if updated else ""
    return f"""<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — Pagô</title>
<meta name="description" content="{description}">
<link rel="canonical" href="https://usepago.web.app/{slug}">
<meta name="theme-color" content="#2f6bff">
<meta property="og:type" content="website">
<meta property="og:locale" content="pt_BR">
<meta property="og:site_name" content="Pagô">
<meta property="og:title" content="{title} — Pagô">
<meta property="og:description" content="{description}">
<meta property="og:url" content="https://usepago.web.app/{slug}">
<meta property="og:image" content="https://usepago.web.app/assets/pago-icon.jpg">
<link rel="icon" href="./assets/pago-icon.jpg" type="image/jpeg">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700;800&display=swap">
<link rel="stylesheet" href="./legal.css">
</head>
<body>
<a class="skip" href="#conteudo">Ir para o conteúdo</a>
<header class="top">
  <div class="in">
    <a class="brand" href="./" aria-label="Pagô, página inicial">{MARK}Pagô</a>
    <nav aria-label="Páginas do site">{nav}</nav>
  </div>
</header>
<main id="conteudo">
<article class="doc">
<p class="eyebrow">{eyebrow}</p>
<h1>{h1}</h1>
{upd}
{summary_html}
{toc_html}
{body}
</article>
</main>
<footer>
  <div class="in">
    <a href="./">Início</a>
    <a href="./ajuda">Ajuda</a>
    <a href="./privacidade">Privacidade</a>
    <a href="./termos">Termos</a>
    <a href="./lgpd">LGPD</a>
    <a href="./excluir-conta">Excluir conta</a>
    <p class="legal">Pagô é uma ferramenta de organização. Não é banco, carteira digital nem meio de pagamento.</p>
  </div>
</footer>
</body>
</html>
"""


# ------------------------------------------------------------------ AJUDA
AJUDA = f"""
<p class="lead">Tire dúvidas sobre a caderneta, as cobranças, o Premium e a sua conta. Se não achar a resposta aqui, fale com a gente pelo WhatsApp.</p>
<div class="card">
  <h2>Fale com a gente</h2>
  <p>Toque no botão e a conversa abre no seu WhatsApp, com a mensagem pronta. O mesmo botão está no app, em Configurações → Ajuda.</p>
  <p><a class="btn wa" href="{WA}">Abrir o WhatsApp de suporte</a></p>
  <p class="updated" style="margin:0">Para pedidos sobre seus dados (LGPD), use o botão da <a href="./lgpd">página de LGPD</a>. Nunca peça nem envie sua senha ou códigos de verificação por mensagem: nós não pedimos.</p>
</div>

<h2>Perguntas frequentes</h2>
<details><summary>O Pagô cobra o meu cliente?</summary><p>Não. O app deixa a mensagem de cobrança pronta e abre o seu WhatsApp. Você revisa e decide quando enviar. O Pagô nunca manda mensagem em seu nome.</p></details>
<details><summary>O Pagô recebe o pagamento?</summary><p>Não. O Pagô não é banco e não movimenta dinheiro. O pagamento vai direto de quem paga para você, e no app você registra o que recebeu.</p></details>
<details><summary>Esqueci minha senha. E agora?</summary><p>Na tela de login, toque em “Esqueci minha senha” e informe o e-mail da conta. Enviaremos um link de recuperação. Se não chegar, confira a caixa de spam e se o e-mail está digitado corretamente.</p></details>
<details><summary>Não estou recebendo os lembretes</summary><p>Confira nas configurações do celular se as notificações do Pagô estão permitidas e se o app não está em modo de economia de bateria. No app, em Configurações, a opção de notificações diárias precisa estar ligada.</p></details>
<details><summary>Como assinar o Premium?</summary><p>No app, abra Premium e toque em assinar. A cobrança é feita pela loja do seu aparelho (Google Play ou App Store), e o valor aparece na loja antes de você confirmar. O Premium inclui lançamento por voz, leitura de comprovante por foto, mensagem de cobrança com o seu texto e boletos de fornecedores.</p></details>
<details><summary>Como cancelo o Premium?</summary><p>O cancelamento é feito na loja. No Android: Google Play → seu perfil → Pagamentos e assinaturas → Assinaturas → Pagô. No iPhone: Ajustes → seu nome → Assinaturas → Pagô. Cancele antes da data de renovação; o período já pago continua disponível.</p></details>
<details><summary>Paguei o Premium e não liberou</summary><p>No app, abra Premium e toque em “Restaurar compras”, com a mesma conta da loja usada na compra. Se continuar sem liberar, fale com o suporte e informe o e-mail da sua conta.</p></details>
<details><summary>Errei o valor de um lançamento</summary><p>Enquanto o lançamento não tiver pagamento registrado, você pode editá-lo. Se já houver pagamento, fale com o suporte informando o cliente e o valor correto.</p></details>
<details><summary>Funciona no iPhone?</summary><p>Hoje o Pagô está disponível para Android. A versão para iPhone está em preparação.</p></details>
<details><summary>Como excluo minha conta?</summary><p>Pelo app, em Configurações → Excluir minha conta, ou pela <a href="./excluir-conta">página de exclusão de conta</a>, que também explica como pedir sem o aplicativo.</p></details>
<details><summary>O que o Pagô faz com os dados dos meus clientes?</summary><p>Eles ficam na sua conta e servem só para a caderneta funcionar. O Pagô não os usa para cobrar ninguém nem para marketing. Veja a <a href="./privacidade">Política de Privacidade</a>.</p></details>
"""

# ------------------------------------------------------------------ PRIVACIDADE
PRIVACIDADE_TOC = [
    ("quem", "Quem é responsável pelos dados"), ("dados", "Quais dados tratamos"), ("uso", "Para que usamos e por quê"),
    ("compartilhamento", "Com quem compartilhamos"), ("identificadores", "Anúncios e identificadores"),
    ("seguranca", "Segurança"), ("retencao", "Por quanto tempo guardamos"), ("direitos", "Seus direitos"),
    ("menores", "Menores de idade"), ("mudancas", "Mudanças nesta política"), ("contato", "Contato"),
]
PRIVACIDADE = f"""
<h2 id="quem">1. Quem é responsável pelos dados</h2>
<p>Esta política vale para o aplicativo e para o site do Pagô e segue a Lei Geral de Proteção de Dados (Lei nº 13.709/2018, LGPD).</p>
<ul>
  <li><strong>Dados da sua conta:</strong> o Pagô é o controlador.</li>
  <li><strong>Dados dos seus clientes</strong> (nome, telefone, valores): você é o controlador, porque decide quem cadastra. O Pagô é o operador e trata esses dados só para a caderneta funcionar, seguindo as suas instruções.</li>
</ul>
<p>O canal para qualquer assunto de privacidade, inclusive o encarregado pelo tratamento de dados, é o <a href="{WA_LGPD}">WhatsApp de suporte</a>.</p>

<h2 id="dados">2. Quais dados tratamos</h2>
<div class="scroll"><table>
<thead><tr><th>Dado</th><th>Para quê</th></tr></thead>
<tbody>
<tr><td><strong>Conta:</strong> nome, e-mail, senha (guardada de forma protegida), telefone (se informar) e aceite dos termos</td><td>Criar e proteger a sua conta, entrar no app e falar com você</td></tr>
<tr><td><strong>Perfil de cobrança:</strong> chave PIX, dados bancários (opcionais), texto da mensagem de cobrança e preferências</td><td>Montar a mensagem de cobrança e personalizar o app</td></tr>
<tr><td><strong>Caderneta:</strong> nome e telefone dos clientes, valores, juros, vencimentos e pagamentos registrados</td><td>Mostrar o que cada cliente deve e o que vence</td></tr>
<tr><td><strong>Boletos a pagar</strong> (Premium): fornecedor, valor, vencimento, parcelas e o código do boleto, se você colar</td><td>Lembrar os vencimentos dos seus fornecedores</td></tr>
<tr><td><strong>Assinatura:</strong> situação e identificadores da compra enviados pela loja (não recebemos número de cartão)</td><td>Liberar e manter o Premium</td></tr>
<tr><td><strong>Voz</strong> (Premium): o que você dita para lançar</td><td>Sugerir o preenchimento do lançamento. O reconhecimento usa o serviço de voz do seu aparelho, que pode ser do fabricante ou do Google, conforme as configurações do aparelho</td></tr>
<tr><td><strong>Foto de comprovante</strong> (Premium)</td><td>Ler o valor no próprio aparelho e sugerir a baixa. A imagem não é enviada ao Pagô</td></tr>
<tr><td><strong>Notificações:</strong> identificador do aparelho para avisos</td><td>Enviar o lembrete diário de vencimentos</td></tr>
<tr><td><strong>Uso e falhas:</strong> eventos como cadastro, primeiro lançamento e abertura da oferta Premium, e relatórios de travamento (modelo do aparelho, versão do sistema e do app)</td><td>Corrigir erros e entender o que melhorar. Esses dados não incluem nomes, telefones, valores nem a sua caderneta</td></tr>
<tr><td><strong>Origem da instalação:</strong> o canal ou a campanha do link usado para instalar</td><td>Saber de onde vêm os usuários</td></tr>
<tr><td><strong>Site:</strong> dados técnicos de acesso</td><td>Segurança e funcionamento do site</td></tr>
</tbody></table></div>
<p>O app só pede acesso à câmera, ao microfone, às notificações e à biometria quando você usa o recurso que precisa deles. Você pode negar ou retirar essas permissões nas configurações do aparelho.</p>

<h2 id="uso">3. Para que usamos e por quê</h2>
<p>Usamos os dados para prestar o serviço, manter a segurança, cumprir obrigações legais e melhorar o app. As bases legais da LGPD são:</p>
<ul>
  <li><strong>Execução de contrato:</strong> conta, caderneta, cobrança pelo WhatsApp a seu pedido e assinatura.</li>
  <li><strong>Obrigação legal:</strong> guarda de registros de pagamento da assinatura.</li>
  <li><strong>Legítimo interesse:</strong> segurança, prevenção a fraude e estabilidade do app.</li>
  <li><strong>Consentimento:</strong> aceite no cadastro e permissões do aparelho (câmera, microfone, notificações). Você pode retirá-lo quando quiser.</li>
</ul>
<div class="note"><p><strong>O Pagô não vende os seus dados nem a sua lista de clientes</strong> e não usa esses dados para cobrar ninguém em seu nome.</p></div>

<h2 id="compartilhamento">4. Com quem compartilhamos</h2>
<p>Compartilhamos só o necessário, com empresas que prestam serviços ao Pagô:</p>
<ul>
  <li><strong>Google (Firebase):</strong> autenticação, banco de dados, notificações, relatórios de travamento e análise de uso.</li>
  <li><strong>Google Play e App Store:</strong> cobrança e verificação da assinatura Premium.</li>
  <li><strong>AppsFlyer:</strong> medição da origem das instalações e de eventos mínimos de uso, quando essa medição estiver ativada.</li>
  <li><strong>WhatsApp:</strong> abre no seu aparelho quando você toca em cobrar. O envio é feito por você.</li>
</ul>
<p>Esses prestadores podem ter servidores fora do Brasil. Nesses casos, a transferência internacional segue a LGPD (art. 33), com as garantias previstas na lei. Também podemos compartilhar dados quando uma autoridade pública exigir, na forma da lei.</p>

<h2 id="identificadores">5. Anúncios e identificadores</h2>
<p>O app não usa o identificador de publicidade no Android. No iPhone, qualquer uso de identificador de publicidade depende da sua autorização na janela de rastreamento do sistema, e você pode recusar sem perder nenhum recurso do app. Os eventos de medição não levam nomes, telefones, valores, vencimentos, chave PIX nem o conteúdo da caderneta.</p>

<h2 id="seguranca">6. Segurança</h2>
<p>As conexões usam criptografia (HTTPS). Cada pessoa só acessa a própria caderneta, por regras de acesso no banco de dados. O painel interno do Pagô tem acesso restrito e registra as ações feitas nele. Nenhum sistema é totalmente imune, e, se houver um incidente que possa causar risco relevante a você, avisaremos você e a Autoridade Nacional de Proteção de Dados (ANPD), como a lei exige.</p>

<h2 id="retencao">7. Por quanto tempo guardamos</h2>
<p>Guardamos os dados enquanto a sua conta existir. Quando você exclui a conta, apagamos login, perfil, clientes, lançamentos, pagamentos e boletos na hora. Ficam apenas os registros de pagamento da assinatura Premium (número do pedido, data e valor), pelo prazo exigido por lei fiscal, sem os dados da sua caderneta. Cópias de segurança são eliminadas por completo em até 30 dias. Veja <a href="./excluir-conta">como excluir a sua conta</a>.</p>

<h2 id="direitos">8. Seus direitos</h2>
<p>Pela LGPD (art. 18), você pode pedir a qualquer momento:</p>
<ul>
  <li>confirmação de que tratamos seus dados e acesso a eles;</li>
  <li>correção de dados incompletos ou desatualizados;</li>
  <li>anonimização, bloqueio ou eliminação de dados desnecessários ou tratados fora da lei;</li>
  <li>portabilidade dos dados;</li>
  <li>informação sobre com quem compartilhamos;</li>
  <li>eliminação dos dados tratados com o seu consentimento;</li>
  <li>revogação do consentimento e oposição ao tratamento.</li>
</ul>
<p>Faça o pedido pelo <a href="{WA_LGPD}">WhatsApp de suporte</a>, a partir do contato cadastrado na conta. Detalhes e prazos estão na página de <a href="./lgpd">LGPD</a>. Você também pode reclamar à ANPD (<a href="https://www.gov.br/anpd">gov.br/anpd</a>).</p>

<h2 id="menores">9. Menores de idade</h2>
<p>O Pagô é para maiores de 18 anos e não é direcionado a crianças nem adolescentes. Se soubermos que uma conta é de menor, podemos excluí-la.</p>

<h2 id="mudancas">10. Mudanças nesta política</h2>
<p>Podemos atualizar esta política quando o app mudar ou a lei exigir. A data no topo mostra a última revisão, e mudanças importantes serão avisadas no app.</p>

<h2 id="contato">11. Contato</h2>
<p>Dúvidas, pedidos de dados ou reclamações: <a href="{WA_LGPD}">WhatsApp de suporte</a>. Veja também a <a href="./ajuda">Ajuda</a>, os <a href="./termos">Termos de Uso</a> e a página de <a href="./lgpd">LGPD</a>.</p>
"""
PRIVACIDADE_SUMMARY = [
    "Os dados da sua caderneta e dos seus clientes são seus. O Pagô só os usa para o app funcionar.",
    "Não vendemos dados e não cobramos o seu cliente: a mensagem sai do seu WhatsApp, quando você toca.",
    "Câmera, microfone e notificações só são pedidos quando você usa o recurso.",
    "Você pode excluir a conta a qualquer hora, pelo app, e apagamos tudo na hora.",
]

# ------------------------------------------------------------------ TERMOS
TERMOS_TOC = [
    ("aceite", "Aceite e quem pode usar"), ("servico", "O serviço"), ("conta", "Sua conta"), ("uso", "Uso permitido"),
    ("clientes", "Seus clientes e a cobrança"), ("premium", "Assinatura Premium"), ("disponibilidade", "Disponibilidade e mudanças"),
    ("propriedade", "Propriedade intelectual"), ("responsabilidade", "Responsabilidade"), ("encerramento", "Encerramento"),
    ("lei", "Lei aplicável e contato"),
]
TERMOS = f"""
<h2 id="aceite">1. Aceite e quem pode usar</h2>
<p>Estes Termos regulam o uso do aplicativo e do site do Pagô. Ao criar uma conta você declara ter 18 anos ou mais e aceita estes Termos e a <a href="./privacidade">Política de Privacidade</a>. O aceite eletrônico vale como manifestação de vontade (Lei nº 12.965/2014, Marco Civil da Internet, e MP nº 2.200-2/2001).</p>

<h2 id="servico">2. O serviço</h2>
<p>O Pagô é uma caderneta digital para organizar fiado, vendas a prazo e empréstimos entre você e os clientes que você cadastra. Ele ajuda a registrar valores, vencimentos e pagamentos e a preparar mensagens de cobrança.</p>
<div class="note"><p><strong>O Pagô não é banco, carteira digital nem meio de pagamento.</strong> Não somos instituição financeira, não concedemos crédito, não consultamos contas bancárias, não confirmamos transferências e não movimentamos dinheiro. Os pagamentos registrados no app são informados por você.</p></div>
<p>As mensagens de cobrança abrem no WhatsApp do seu aparelho. O envio é seu: o Pagô não manda mensagens em nome próprio nem em seu nome. Juros são opcionais e definidos por você.</p>

<h2 id="conta">3. Sua conta</h2>
<p>Você responde pelos dados que informa e pela guarda da sua senha. Avise-nos se suspeitar de uso indevido da conta. Podemos suspender ou encerrar contas em caso de fraude, abuso ou violação da lei, com aviso quando possível.</p>

<h2 id="uso">4. Uso permitido</h2>
<p>Você não pode usar o Pagô para fraude, para cobrar dívidas que não existem, para assediar pessoas, para tratar dados sem base legal ou para violar direitos de terceiros ou a lei. Também não pode tentar acessar contas ou dados de outras pessoas, nem interferir no funcionamento do serviço.</p>

<h2 id="clientes">5. Seus clientes e a cobrança</h2>
<p>Os dados dos clientes que você lança na caderneta são de sua responsabilidade: você é o controlador e precisa ter base legal para tratá-los (LGPD). Informe só o necessário.</p>
<p>A cobrança deve respeitar o Código de Defesa do Consumidor (Lei nº 8.078/1990), em especial o art. 42: é proibido constranger, ameaçar ou expor o consumidor ao ridículo. Assédio, ameaça e cobrança de valor indevido são proibidos.</p>

<h2 id="premium">6. Assinatura Premium</h2>
<ul>
  <li><strong>O que inclui:</strong> lançamento por voz, leitura de comprovante por foto, mensagem de cobrança com o seu texto e boletos de fornecedores. O plano gratuito continua com a caderneta essencial.</li>
  <li><strong>Preço:</strong> o valor mensal é exibido na loja antes da confirmação da compra (atualmente R$ 39,90 por mês). O valor da loja prevalece, e mudanças de preço são comunicadas pela loja antes de valerem para você.</li>
  <li><strong>Cobrança e renovação:</strong> a assinatura é feita pela loja do aparelho (Google Play no Android, App Store no iPhone) e renova automaticamente todo mês até você cancelar.</li>
  <li><strong>Cancelamento:</strong> feito na própria loja, antes da data de renovação (na App Store, pelo menos 24 horas antes do fim do período). O cancelamento vale para o ciclo seguinte e o período já pago continua disponível. Excluir a conta no Pagô não cancela a assinatura na loja.</li>
  <li><strong>Reembolso:</strong> segue as regras da loja em que você assinou. Quando se aplicar, vale também o direito de arrependimento de 7 dias para contratações feitas fora do estabelecimento comercial (CDC, art. 49), que você exerce pela loja ou pelo nosso suporte.</li>
  <li><strong>Restaurar compras:</strong> no app, “Restaurar compras” recupera uma assinatura já feita com a mesma conta da loja.</li>
</ul>

<h2 id="disponibilidade">7. Disponibilidade e mudanças</h2>
<p>Trabalhamos para manter o serviço no ar, mas ele pode ficar indisponível por manutenção ou falhas de terceiros. Podemos melhorar, alterar ou descontinuar recursos, avisando com antecedência razoável quando a mudança afetar o que você usa.</p>

<h2 id="propriedade">8. Propriedade intelectual</h2>
<p>O app, a marca Pagô, o design e o código são nossos ou licenciados a nós. Você ganha uma licença pessoal, limitada e revogável para usar o app. Os dados que você lança na caderneta continuam sendo seus.</p>

<h2 id="responsabilidade">9. Responsabilidade</h2>
<p>O serviço é prestado como está disponível. Não respondemos pela inadimplência dos seus clientes, por bloqueios no seu WhatsApp ou por falhas de terceiros (como Google, Apple e WhatsApp), sem prejuízo dos direitos que o Código de Defesa do Consumidor garante a você quando você for consumidor do app.</p>

<h2 id="encerramento">10. Encerramento</h2>
<p>Você pode parar de usar o Pagô e <a href="./excluir-conta">excluir a conta</a> quando quiser. Depois da exclusão, os dados são apagados conforme a <a href="./privacidade#retencao">Política de Privacidade</a>.</p>

<h2 id="lei">11. Lei aplicável e contato</h2>
<p>Estes Termos seguem a legislação brasileira. Para consumidores, fica garantido o foro do domicílio do consumidor. Dúvidas: <a href="{WA}">WhatsApp de suporte</a>. Veja também a <a href="./ajuda">Ajuda</a> e a página de <a href="./lgpd">LGPD</a>.</p>
"""
TERMOS_SUMMARY = [
    "O Pagô organiza o seu fiado e as suas cobranças. Não é banco e não movimenta dinheiro.",
    "A mensagem de cobrança sai do seu WhatsApp, quando você decide enviar.",
    "Cobre com respeito: ameaça, constrangimento e cobrança indevida são proibidos.",
    "O Premium é cobrado pela loja, renova todo mês e pode ser cancelado na própria loja.",
]

# ------------------------------------------------------------------ LGPD
LGPD = f"""
<p class="lead">A Lei Geral de Proteção de Dados (Lei nº 13.709/2018) garante a você controle sobre os seus dados. Aqui está, de forma direta, como isso funciona no Pagô e como fazer um pedido.</p>

<h2>Quem faz o quê</h2>
<div class="scroll"><table>
<thead><tr><th>Dados</th><th>Controlador</th><th>Operador</th></tr></thead>
<tbody>
<tr><td>Sua conta (nome, e-mail, assinatura)</td><td>Pagô</td><td>Prestadores de serviço, como o Google (Firebase)</td></tr>
<tr><td>Seus clientes na caderneta</td><td>Você</td><td>Pagô, só para prestar o serviço</td></tr>
</tbody></table></div>
<p>Informe na caderneta só dados que você tem legitimidade para tratar. O Pagô não cobra o seu cliente em nome próprio: a mensagem sai do seu WhatsApp. Cobrança vexatória é proibida pelo Código de Defesa do Consumidor (art. 42).</p>

<h2>Bases legais</h2>
<p>Execução de contrato (conta, caderneta e assinatura), obrigação legal (registros de pagamento), legítimo interesse (segurança e estabilidade) e consentimento (aceite no cadastro e permissões do aparelho). Os detalhes por tipo de dado estão na <a href="./privacidade#dados">Política de Privacidade</a>.</p>

<h2>Seus direitos</h2>
<p>Você pode pedir:</p>
<ul>
  <li>confirmação e acesso aos seus dados;</li>
  <li>correção de dados incompletos ou errados;</li>
  <li>anonimização, bloqueio ou eliminação de dados desnecessários;</li>
  <li>portabilidade dos dados;</li>
  <li>informação sobre quem recebe os seus dados;</li>
  <li>eliminação dos dados tratados com consentimento;</li>
  <li>revogação do consentimento e oposição ao tratamento.</li>
</ul>

<div class="card">
  <h2>Como fazer um pedido</h2>
  <ol class="steps">
    <li>Toque no botão abaixo. O WhatsApp abre com a mensagem pronta.</li>
    <li>Envie a partir do número ou informe o e-mail cadastrado na conta, para confirmarmos que é você.</li>
    <li>Diga qual direito quer exercer. Para pedir exclusão, você também pode usar o próprio app.</li>
  </ol>
  <p><a class="btn wa" href="{WA_LGPD}">Fazer um pedido de LGPD</a></p>
</div>

<h2>Prazos</h2>
<p>Respondemos no prazo da LGPD: de imediato, em formato simplificado, ou em até 15 dias, por declaração completa. A exclusão da conta pelo app é feita na hora. Podemos guardar o que a lei obriga, como os registros de pagamento da assinatura, e diremos quando for o caso.</p>

<h2>Encarregado e autoridade</h2>
<p>O contato do encarregado pelo tratamento de dados pessoais é o <a href="{WA_LGPD}">WhatsApp de suporte</a>. Se não ficar satisfeito com a resposta, você pode reclamar à Autoridade Nacional de Proteção de Dados (ANPD): <a href="https://www.gov.br/anpd">gov.br/anpd</a>.</p>

<h2>Incidentes de segurança</h2>
<p>Se ocorrer um incidente que possa causar risco ou dano relevante, avisaremos você e a ANPD, como a lei exige.</p>

<p>Leia também a <a href="./privacidade">Política de Privacidade</a>, os <a href="./termos">Termos de Uso</a> e a <a href="./ajuda">Ajuda</a>.</p>
"""

# ------------------------------------------------------------------ EXCLUIR CONTA
EXCLUIR = f"""
<p class="lead">Você pode excluir a sua conta e os seus dados quando quiser. É definitivo, então leia o que acontece antes de confirmar.</p>

<div class="card">
  <h2>Pelo aplicativo (na hora)</h2>
  <ol class="steps">
    <li>Abra o Pagô e vá em <strong>Configurações</strong>.</li>
    <li>No fim da tela, toque em <strong>Excluir minha conta</strong>.</li>
    <li>Digite a sua senha e toque em <strong>Excluir para sempre</strong>.</li>
  </ol>
  <p>A conta e os dados são apagados na mesma hora.</p>
</div>

<div class="card">
  <h2>Sem o aplicativo</h2>
  <p>Se você não consegue abrir o app, envie o pedido pelo WhatsApp, a partir do número ou informando o e-mail cadastrado no Pagô, com o assunto <strong>“Excluir minha conta”</strong>. Confirmamos que é você e apagamos em até 15 dias.</p>
  <p><a class="btn wa" href="{WA_DEL}">Pedir exclusão pelo WhatsApp</a></p>
</div>

<h2>O que é apagado</h2>
<ul>
  <li>login (e-mail e senha), nome e telefone;</li>
  <li>chave PIX, dados bancários, texto de cobrança e preferências;</li>
  <li>clientes, lançamentos, pagamentos e boletos cadastrados;</li>
  <li>identificadores de aparelho usados nos lembretes e a origem da instalação.</li>
</ul>

<h2>O que fica guardado</h2>
<p>Os registros de pagamento da assinatura Premium (número do pedido, data e valor) ficam pelo prazo exigido por lei fiscal, sem os dados da sua caderneta. Cópias de segurança são eliminadas por completo em até 30 dias.</p>

<div class="note"><p><strong>Se você assina o Premium:</strong> excluir a conta <strong>não cancela</strong> a cobrança na loja. Cancele antes: no Android, Google Play → seu perfil → Pagamentos e assinaturas → Assinaturas → Pagô; no iPhone, Ajustes → seu nome → Assinaturas → Pagô.</p></div>

<h2>Antes de excluir</h2>
<p>A exclusão não pode ser desfeita. Se quiser guardar informações, anote ou capture a tela dos seus clientes e valores antes. Dúvidas? Veja a <a href="./ajuda">Ajuda</a> ou a <a href="./privacidade#retencao">Política de Privacidade</a>.</p>
"""

PAGES = [
    ("ajuda", "Ajuda", "Tire dúvidas sobre a caderneta, as cobranças, o Premium e a sua conta, ou fale com o suporte do Pagô pelo WhatsApp.", "Central de ajuda", "Como podemos ajudar?", AJUDA, None, None, False),
    ("privacidade", "Política de Privacidade", "Como o Pagô trata os seus dados: o que coletamos, para quê, com quem compartilhamos, por quanto tempo guardamos e quais são os seus direitos.", "Lei nº 13.709/2018 (LGPD)", "Política de Privacidade", PRIVACIDADE, PRIVACIDADE_SUMMARY, PRIVACIDADE_TOC, True),
    ("termos", "Termos de Uso", "Regras de uso do aplicativo e do site do Pagô: o serviço, a conta, a cobrança dos seus clientes e a assinatura Premium.", "Documento", "Termos de Uso", TERMOS, TERMOS_SUMMARY, TERMOS_TOC, True),
    ("lgpd", "LGPD no Pagô", "Seus direitos sobre dados pessoais no Pagô e como fazer um pedido de acesso, correção, exclusão ou portabilidade.", "Lei nº 13.709/2018", "LGPD no Pagô", LGPD, None, None, True),
    ("excluir-conta", "Excluir conta", "Como excluir a sua conta do Pagô e os seus dados, pelo aplicativo ou pelo WhatsApp, e o que é apagado ou guardado.", "Sua conta", "Excluir sua conta", EXCLUIR, None, None, True),
]

if __name__ == "__main__":
    for slug, title, desc, eyebrow, h1, body, summary, toc, upd in PAGES:
        (SITE / f"{slug}.html").write_text(page(slug, title, desc, eyebrow, h1, body, summary, toc, upd), encoding="utf-8")
    shutil.copyfile(ROOT / "tool" / "legal.css", SITE / "legal.css")
    print("páginas geradas:", ", ".join(p[0] for p in PAGES))
