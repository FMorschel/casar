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

### Abas criadas automaticamente

- `convidados` — `id | nome | criado_em | renomeado_em`, **uma linha por
  convidado**. O `id` é gerado pelo próprio script (8 caracteres, sem `0`/`o`
  nem `1`/`l` para não se confundirem numa leitura na planilha) na primeira
  vez que o convidado sorteia. É a única fonte do nome que aparece no
  álbum — as linhas de `desafios_fotos` guardam o `id`, não o nome, então
  corrigir um nome errado aqui vale para todas as fotos daquele convidado
  sem tocar em nenhuma linha delas. `renomeado_em` fica vazio até o
  convidado (ou alguém à mão na planilha) corrigir o nome dele pelo menos
  uma vez.
- `desafios_fotos` — `sorteio_timestamp | guest_id | desafio | foto_url |
  tirada_em`, **uma linha por desafio**, não uma linha por convidado. Um
  convidado tem 3 linhas por sorteio (ele pode sortear mais de uma vez) mais
  uma linha para cada desafio que ele mesmo escreveu.
  `foto_url`/`tirada_em` ficam vazios até o convidado confirmar a foto
  daquele desafio — a mesma linha vira uma entrada da galeria quando
  `doPostUpload_` os preenche (não cria uma linha nova). O primeiro sorteio é
  idempotente: revisitar a página não sorteia de novo.

  Até uma versão anterior deste script, a coluna B guardava o nome do
  convidado direto; a primeira leitura depois de atualizar o `Code.gs`
  migra sozinha essa coluna para `guest_id` (criando uma linha em
  `convidados` para cada nome distinto que já estivesse na planilha) —
  não precisa mexer na planilha à mão.

### Ações novas

- `GET ?action=gallery` — devolve `{photos: [{challenge, author, url,
  timestamp}, ...]}`, uma entrada por linha com `foto_url` preenchida
  (`timestamp` é `tirada_em`, o instante em que o convidado confirmou a foto
  no app, não o instante do upload). `author` vem da aba `convidados`,
  buscado pelo `guest_id` a cada leitura — uma foto de um convidado que já
  não existe mais nessa aba (linha apagada à mão) ainda aparece no álbum,
  só que como "Convidado".
- `POST {action:'draw', name, id?}` — sorteia (ou recupera) os desafios do
  convidado, criando a linha dele em `convidados` na primeira vez.
  `id` é opcional: quando o site já tem um id salvo (de um sorteio
  anterior), manda ele também, e o servidor casa por `id` antes de tentar
  pelo `name` — assim reconhece o convidado mesmo que o nome dele tenha
  sido corrigido em outro aparelho desde então. Devolve `{id, name,
  challenges, photos}` com **tudo** que o convidado já tem (de todos os
  sorteios, mais os que ele escreveu); `name` é o nome como está na
  planilha agora, que o site deve adotar como o nome atual. As regras do
  sorteio, em ordem: nenhuma frase se repete para o mesmo convidado; pelo
  menos uma prioritária por sorteio (enquanto sobrar alguma que ele não
  pegou); as outras vagas saem de qualquer frase, com peso maior para as
  prioritárias (não é obrigatório sair uma não prioritária); e, em
  qualquer vaga, frases que nenhum convidado pegou ainda têm preferência
  sobre as que já saíram para alguém. A mesma frase pode sair para
  convidados diferentes.
- `POST {action:'drawMore', name, id?}` — sorteia mais um trio, para quem
  já mandou as fotos de todos os desafios que tinha. Devolve `{id, name,
  challenges, photos}` com a lista completa do convidado (a de antes mais
  o sorteio novo); quando o banco de frases acaba para ele, devolve só a
  de antes e o site entende que agora só sobraram os desafios escritos à
  mão. Erros: `not_started` (nunca sorteou) e `pending_photos` (ainda tem
  desafio sem foto).
- `POST {action:'check', name}` — só consulta se `name` já tem desafios
  sorteados, sem sortear nem gravar nada (usado pelo portão do site antes
  de assumir um nome já usado). Devolve `{id, name, challenges}`; `id`
  vazio e `challenges` vazio quando ninguém sorteou com esse nome ainda.
- `POST {action:'rename', id, name}` — corrige o nome do convidado de
  `id` para `name`. Muda só a célula de nome em `convidados` — as fotos já
  enviadas aparecem com o nome novo na próxima leitura do álbum, sem
  precisar mexer em `desafios_fotos`. Recusa com `name_taken` se outro
  convidado já estiver usando esse nome, e com `unknown_guest` se o `id`
  não existir.
- `POST {action:'upload', name, id?, challenge, photo, mimeType, timestamp,
  custom}` — salva a foto (`photo` em base64, sem o prefixo
  `data:...;base64,`) no Drive e preenche `foto_url`/`tirada_em` na linha do
  desafio já sorteado (`timestamp` é quando a foto foi tirada, mandado pelo
  cliente). Como em `draw`, `id` (quando o site já tem um) tem prioridade
  sobre `name` para achar o convidado. Com `custom: true`, o desafio é uma
  frase escrita pelo próprio convidado e não existe linha esperando por
  ela: a linha é criada aqui, já com a foto, depois de passar pelas mesmas
  regras de texto que o site cobra (começa com maiúscula, pelo menos três
  palavras de duas letras ou mais, e não pode repetir uma frase do banco de
  desafios).

Sem `action` (nos dois verbos), o comportamento é exatamente o mesmo de
hoje — a lista de presentes não muda em nada.

Para apagar uma foto da galeria (ex.: conteúdo indevido), apague `foto_url`
e `tirada_em` da linha correspondente na aba `desafios_fotos` (não a linha
inteira — ela ainda representa o desafio sorteado daquele convidado) **e**
o arquivo correspondente no Drive — não há endpoint de moderação, igual ao
gift-ideas.

Para corrigir o nome de um convidado à mão (sem passar pelo site), edite a
célula de nome na aba `convidados` — vale para todas as fotos dele, já que
elas apontam para o `id`, não para o nome.
