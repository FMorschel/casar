# Ideias de presente na planilha do Google

O site é estático (GitHub Pages), então ele não tem para onde gravar nada. Quem
guarda as ideias sugeridas pelos convidados é um Google Apps Script publicado
como *Web App*, escrevendo numa planilha do Google.

Planilha usada:
<https://docs.google.com/spreadsheets/d/1k3tCCPiyT5ZT9Bf11rGKgDognTCDmyjYxFj8R7P9XeU/edit>

## Publicando o script (uma vez só)

1. Abra a planilha → **Extensões → Apps Script**.
2. Apague o conteúdo de `Código.gs` e cole o de [`Code.gs`](Code.gs).
3. Salve (o nome do projeto pode ser `casar-ideias`).
4. **Implantar → Nova implantação → Tipo: App da Web**, com:
   - *Executar como*: **Eu**
   - *Quem pode acessar*: **Qualquer pessoa**
5. Autorize quando o Google pedir (vai aparecer um aviso de "app não
   verificado" — é o seu próprio script; siga em *Avançado → Acessar*).
6. Copie a **URL do app da Web** (termina em `/exec`).
7. Cole essa URL em `giftIdeasEndpoint`, em
   [`lib/constants/config.dart`](../../lib/constants/config.dart), e publique o
   site.

A aba `ideias` é criada sozinha no primeiro envio, com as colunas
`timestamp | emoji | nome | valor | autor`.

## Depois

- Para apagar uma ideia, basta deletar a linha na planilha — o site reflete na
  próxima visita.
- Se mudar o `Code.gs`, use **Implantar → Gerenciar implantações → editar →
  Nova versão** para manter a *mesma* URL. Uma "Nova implantação" gera uma URL
  diferente e o site pararia de achar a planilha.
- Enquanto `giftIdeasEndpoint` estiver vazia, o site funciona igual, só que as
  ideias ficam apenas no navegador de quem escreveu.

## O que este endpoint é (e não é)

A URL aceita escrita de qualquer pessoa, sem login e sem aprovação — foi o
combinado. Os limites que existem são de tamanho de campo e um teto de 500
ideias (a mais antiga sai). Se alguém escrever bobagem, a correção é apagar a
linha na planilha.

## Desafios de foto (mesma implantação)

O mesmo Apps Script também guarda o sorteio de desafios de foto de cada
convidado e as fotos que eles confirmarem — é a mesma implantação de cima
(não crie uma "Nova implantação" separada), só um dispatcher por `action`
a mais em `doGet`/`doPost`.

### Criar a pasta do Drive

1. Crie uma pasta no seu Google Drive para guardar as fotos (ex.:
   "Fotos do casar").
2. Abra a pasta e copie o **id** da URL:
   `https://drive.google.com/drive/folders/<ID_DA_PASTA>`.
3. Em `Code.gs`, cole esse id em `PHOTOS_FOLDER_ID`.

### Publicar (atualizar a implantação existente)

Depois de colar o `Code.gs` atualizado (com o id da pasta):

**Implantar → Gerenciar implantações → editar (ícone de lápis) → Nova
versão → Implantar.** Isso mantém a mesma URL `/exec` de sempre — não use
"Nova implantação", que geraria uma URL diferente e quebraria o
`giftIdeasEndpoint` que já está publicado.

Depois cole a mesma URL (sem mudar nada) em `photoChallengesEndpoint`, em
[`lib/constants/config.dart`](../../lib/constants/config.dart).

### Aba criada automaticamente

- `desafios_fotos` — `sorteio_timestamp | nome | desafio | foto_url |
  tirada_em`, **uma linha por desafio**, não uma linha por convidado. Um
  convidado tem 3 linhas por sorteio (ele pode sortear mais de uma vez) mais
  uma linha para cada desafio que ele mesmo escreveu.
  `foto_url`/`tirada_em` ficam vazios até o convidado confirmar a foto
  daquele desafio — a mesma linha vira uma entrada da galeria quando
  `doPostUpload_` os preenche (não cria uma linha nova). O primeiro sorteio é
  idempotente: revisitar a página não sorteia de novo.

### Ações novas

- `GET ?action=gallery` — devolve `{photos: [{challenge, author, url,
  timestamp}, ...]}`, uma entrada por linha com `foto_url` preenchida
  (`timestamp` é `tirada_em`, o instante em que o convidado confirmou a foto
  no app, não o instante do upload).
- `POST {action:'draw', name}` — sorteia (ou recupera) os desafios de
  `name`, devolvendo `{challenges, photos}` com **tudo** que ele já tem (de
  todos os sorteios, mais os que ele escreveu). As regras do sorteio, em
  ordem: nenhuma frase se repete para o mesmo convidado; pelo menos uma
  prioritária por sorteio (enquanto sobrar alguma que ele não pegou); as
  outras vagas saem de qualquer frase, com peso maior para as prioritárias
  (não é obrigatório sair uma não prioritária); e, em qualquer vaga, frases
  que nenhum convidado pegou ainda têm preferência sobre as que já saíram
  para alguém. A mesma frase pode sair para convidados diferentes.
- `POST {action:'drawMore', name}` — sorteia mais um trio, para quem já
  mandou as fotos de todos os desafios que tinha. Devolve a lista completa
  do convidado (a de antes mais o sorteio novo); quando o banco de frases
  acaba para ele, devolve só a de antes e o site entende que agora só
  sobraram os desafios escritos à mão. Erros: `not_started` (nunca sorteou)
  e `pending_photos` (ainda tem desafio sem foto).
- `POST {action:'upload', name, challenge, photo, mimeType, timestamp,
  custom}` — salva a foto (`photo` em base64, sem o prefixo
  `data:...;base64,`) no Drive e preenche `foto_url`/`tirada_em` na linha do
  desafio já sorteado (`timestamp` é quando a foto foi tirada, mandado pelo
  cliente). Com `custom: true`, o desafio é uma frase escrita pelo próprio
  convidado e não existe linha esperando por ela: a linha é criada aqui, já
  com a foto, depois de passar pelas mesmas regras de texto que o site
  cobra (começa com maiúscula, pelo menos três palavras de duas letras ou
  mais, e não pode repetir uma frase do banco de desafios).

Sem `action` (nos dois verbos), o comportamento é exatamente o mesmo de
hoje — a lista de presentes não muda em nada.

Para apagar uma foto da galeria (ex.: conteúdo indevido), apague `foto_url`
e `tirada_em` da linha correspondente na aba `desafios_fotos` (não a linha
inteira — ela ainda representa o desafio sorteado daquele convidado) **e**
o arquivo correspondente no Drive — não há endpoint de moderação, igual ao
gift-ideas.
