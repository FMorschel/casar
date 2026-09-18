/**
 * Backend "serverless" do site do casar.
 *
 * Guarda as ideias de presente e os desafios de foto dos convidados numa
 * planilha do Google, devolvendo tudo para o site estático (GitHub Pages),
 * que não tem servidor próprio.
 *
 * Como publicar: veja tools/apps_script/README.md
 */

var SHEET_ID = '1k3tCCPiyT5ZT9Bf11rGKgDognTCDmyjYxFj8R7P9XeU';
var SHEET_NAME = 'ideias';

/** Colunas da planilha, na ordem. */
var HEADERS = ['timestamp', 'emoji', 'nome', 'valor', 'autor'];

/**
 * Ideias com `timestamp` vazio são o catálogo oficial (a seção "de
 * brincadeira" do site), não sugestão de convidado — essas linhas já vêm
 * populadas na planilha, sem passar por este arquivo. `autor` não serve pra
 * essa distinção: é opcional no formulário, então uma sugestão de convidado
 * também pode chegar sem autor. `timestamp` sim, é gravado sempre que o
 * site manda uma ideia (ver `doPostIdea_`) — só as linhas do catálogo
 * oficial ficam sem ele. Compartilham a aba e o teto de linhas com as
 * ideias sugeridas de propósito: o pedido foi ter as duas listas juntas num
 * lugar só, sem uma aba separada para o catálogo oficial.
 */

/** Limites de tamanho — a planilha é pública para escrita, então nada entra sem teto. */
var MAX_EMOJI = 8;
var MAX_NAME = 120;
var MAX_PRICE = 20;
var MAX_AUTHOR = 60;

/** Teto de ideias guardadas: passou disso, a mais antiga sai. */
var MAX_ROWS = 500;

/**
 * Aba dos desafios de foto: uma linha por desafio sorteado (3 por
 * convidado), não uma linha por convidado. `foto_url`/`tirada_em` ficam
 * vazios até o convidado confirmar a foto daquele desafio — é a mesma linha
 * que vira uma entrada da galeria quando preenchida (FR-16).
 *
 * A linha pertence a um `guest_id`, não a um nome: o nome mora só na aba
 * GUEST_SHEET_NAME. Assim, corrigir um nome digitado errado é uma célula só
 * e todas as fotos daquele convidado já aparecem com o nome novo no álbum,
 * sem tocar em nenhuma linha daqui.
 */
var PHOTO_SHEET_NAME = 'desafios_fotos';
var PHOTO_HEADERS = ['sorteio_timestamp', 'guest_id', 'desafio', 'foto_url', 'tirada_em'];

/**
 * Aba dos convidados: uma linha por convidado, com o `id` gerado aqui e o
 * nome que o álbum mostra. É a única fonte desse nome — as linhas de
 * desafio/foto guardam só o `guest_id`.
 *
 * O nome pode ser corrigido pelo próprio convidado (veja doPostRename_) ou
 * à mão na planilha; nos dois casos o álbum reflete na próxima leitura.
 * `renomeado_em` fica vazio enquanto ninguém corrigiu aquele nome.
 */
var GUEST_SHEET_NAME = 'convidados';
var GUEST_HEADERS = ['id', 'nome', 'criado_em', 'renomeado_em'];

/**
 * Alfabeto do `id` de convidado: minúsculas e números, sem os caracteres
 * que se confundem quando alguém lê o id da planilha (`0`/`o`, `1`/`l`).
 */
var GUEST_ID_ALPHABET = '23456789abcdefghijkmnpqrstuvwxyz';
var GUEST_ID_LENGTH = 8;

/** Id da pasta do Drive onde as fotos dos desafios são salvas. */
var PHOTOS_FOLDER_ID = '1DKM-GqX_0QNhYQELCjREr_ROKL977u-d';

var MAX_GUEST_NAME = 120;
var MAX_GUEST_ID = 40;
var MAX_CHALLENGE = 200;
var MAX_MIME = 40;

/** Quantos desafios saem em cada sorteio. */
var CHALLENGES_PER_DRAW = 3;

/**
 * Quantas vezes uma frase prioritária entra no sorteio em relação a uma não
 * prioritária — veja `pickChallenges_`.
 */
var PRIORITY_WEIGHT = 3;

/**
 * Aba do banco de frases dos desafios de foto: uma linha por frase, com a
 * marca de prioritária. É a única fonte desse banco — essas linhas já vêm
 * populadas na planilha, sem passar por este arquivo.
 */
var CHALLENGE_SHEET_NAME = 'banco_desafios';
var CHALLENGE_HEADERS = ['texto', 'prioridade'];

function ss_() {
  return SpreadsheetApp.openById(SHEET_ID);
}

function sheet_() {
  var ss = ss_();
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_NAME);
  }
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(HEADERS);
  }
  applyDateTimeFormat_(sheet, [1]); // timestamp
  return sheet;
}

function photoSheet_() {
  var ss = ss_();
  var sheet = ss.getSheetByName(PHOTO_SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(PHOTO_SHEET_NAME);
  }
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(PHOTO_HEADERS);
  }
  migratePhotoSheetToGuestIds_(sheet);
  applyDateTimeFormat_(sheet, [1, 5]); // sorteio_timestamp, tirada_em
  return sheet;
}

function guestSheet_() {
  var ss = ss_();
  var sheet = ss.getSheetByName(GUEST_SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(GUEST_SHEET_NAME);
  }
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(GUEST_HEADERS);
  }
  applyDateTimeFormat_(sheet, [3, 4]); // criado_em, renomeado_em
  return sheet;
}

function challengeBankSheet_() {
  var ss = ss_();
  var sheet = ss.getSheetByName(CHALLENGE_SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(CHALLENGE_SHEET_NAME);
  }
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(CHALLENGE_HEADERS);
  }
  return sheet;
}

/** Lê o banco de frases inteiro da aba `CHALLENGE_SHEET_NAME`. */
function readChallengeBank_() {
  var sheet = challengeBankSheet_();
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return [];

  var rows = sheet.getRange(2, 1, lastRow - 1, CHALLENGE_HEADERS.length).getValues();
  return rows
    .filter(function (row) {
      return String(row[0]).trim() !== '';
    })
    .map(function (row) {
      return { text: String(row[0]), priority: row[1] === true };
    });
}

/**
 * Passa a aba de desafios do nome para o `guest_id` na coluna B.
 *
 * Até a versão anterior deste script a coluna B guardava o nome do
 * convidado; a partir daqui guarda o id dele, e o nome mora só na aba
 * GUEST_SHEET_NAME. A conversão roda uma vez só (o cabeçalho da coluna é o
 * que diz se já rodou), criando um convidado por nome distinto que já
 * estiver na planilha — ninguém perde os desafios que já sorteou.
 */
function migratePhotoSheetToGuestIds_(sheet) {
  if (String(sheet.getRange(1, 2).getValue()) === PHOTO_HEADERS[1]) return;

  var lastRow = sheet.getLastRow();
  if (lastRow >= 2) {
    var names = sheet.getRange(2, 2, lastRow - 1, 1).getValues();
    var guests = guestSheet_();
    var guestRows = guestRows_(guests);
    var ids = [];
    for (var i = 0; i < names.length; i++) {
      var name = titleCaseName_(names[i][0]);
      if (!name) {
        // Linha sem nome não pertence a ninguém: fica com o id vazio e some
        // do álbum, como já acontecia.
        ids.push(['']);
        continue;
      }
      var index = findGuestByName_(guestRows, normalizeName_(name));
      ids.push([
        index === -1
          ? createGuest_(guests, guestRows, name)
          : String(guestRows[index][0]),
      ]);
    }
    sheet.getRange(2, 2, ids.length, 1).setValues(ids);
  }

  sheet.getRange(1, 2).setValue(PHOTO_HEADERS[1]);
}

/**
 * Sheets guarda o instante completo (data+hora) internamente sempre que a
 * célula recebe um objeto `Date`, mas exibe só a data se a coluna estiver
 * com formato "Date" em vez de "Date time" — o que aconteceu por padrão
 * nestas planilhas. Reaplicar o formato completo a cada acesso corrige isso
 * sem depender de alguém editar a formatação manualmente na planilha.
 */
function applyDateTimeFormat_(sheet, columns) {
  var rows = Math.max(sheet.getMaxRows() - 1, 1);
  for (var i = 0; i < columns.length; i++) {
    sheet.getRange(2, columns[i], rows, 1).setNumberFormat('yyyy-mm-dd hh:mm:ss');
  }
}

function json_(payload) {
  return ContentService.createTextOutput(JSON.stringify(payload)).setMimeType(
    ContentService.MimeType.JSON
  );
}

/** Corta o campo no limite e tira os separadores que quebram o site. */
function clean_(value, max) {
  return String(value == null ? '' : value)
    .replace(/[\r\n|]/g, ' ')
    .trim()
    .slice(0, max);
}

/** Chave de idempotência do convidado: nome normalizado (minúsculo, sem espaços nas pontas). */
function normalizeName_(name) {
  return String(name || '').trim().toLowerCase();
}

/**
 * Nome do convidado com a primeira letra de cada palavra maiúscula e o
 * resto minúsculo (ex.: "MARIA da silva" -> "Maria Da Silva"), com espaços
 * internos repetidos colapsados. Devolve string vazia se não sobrar nada
 * depois do trim.
 */
function titleCaseName_(name) {
  return String(name || '')
    .split(/\s+/)
    .filter(function (word) {
      return word.length > 0;
    })
    .map(function (word) {
      return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    })
    .join(' ');
}

/** Quantidade de letras (ignora espaços, números e pontuação) em [text]. */
function countLetters_(text) {
  var matches = String(text || '').match(/[A-Za-zÀ-ÖØ-öø-ÿ]/g);
  return matches ? matches.length : 0;
}

/** Todas as linhas da aba de convidados (sem o cabeçalho). */
function guestRows_(sheet) {
  var lastRow = sheet.getLastRow();
  return lastRow >= 2
    ? sheet.getRange(2, 1, lastRow - 1, GUEST_HEADERS.length).getValues()
    : [];
}

/** Posição do convidado cujo nome normalizado é [key] em [rows], ou -1. */
function findGuestByName_(rows, key) {
  for (var i = 0; i < rows.length; i++) {
    if (normalizeName_(rows[i][1]) === key) return i;
  }
  return -1;
}

/** Posição do convidado de [id] em [rows], ou -1. */
function findGuestById_(rows, id) {
  for (var i = 0; i < rows.length; i++) {
    if (String(rows[i][0]) === id) return i;
  }
  return -1;
}

/** Nome de cada convidado, por id — o que o álbum mostra como autor. */
function guestNamesById_(rows) {
  var names = {};
  for (var i = 0; i < rows.length; i++) {
    names[String(rows[i][0])] = String(rows[i][1]);
  }
  return names;
}

function randomGuestId_() {
  var id = '';
  for (var i = 0; i < GUEST_ID_LENGTH; i++) {
    id += GUEST_ID_ALPHABET.charAt(
      Math.floor(Math.random() * GUEST_ID_ALPHABET.length)
    );
  }
  return id;
}

/**
 * Um id que ainda não está em [rows]. O espaço é grande demais (32^8) para
 * a repetição acontecer na prática, mas o id é a identidade do convidado —
 * o sorteio e as fotos dele penduram nisso —, então não vale confiar na
 * sorte.
 */
function newGuestId_(rows) {
  var used = {};
  for (var i = 0; i < rows.length; i++) used[String(rows[i][0])] = true;

  var id = randomGuestId_();
  while (used[id]) id = randomGuestId_();
  return id;
}

/**
 * Cria o convidado [name] e devolve o id novo. [rows] é a leitura atual da
 * aba, que também é atualizada — quem chamar em laço (a migração) não
 * precisa reler a planilha a cada convidado.
 */
function createGuest_(sheet, rows, name) {
  var id = newGuestId_(rows);
  var createdAt = new Date();
  sheet.appendRow([id, name, createdAt, '']);
  rows.push([id, name, createdAt, '']);
  return id;
}

function guestAt_(rows, index) {
  return { id: String(rows[index][0]), name: String(rows[index][1]) };
}

/**
 * Acha o convidado de uma requisição, sem criar nada: pelo `id` que o site
 * guardou e, na falta dele, pelo nome.
 *
 * O nome ainda é caminho de entrada porque o site só ganha um id na
 * primeira resposta de `draw` — antes disso (ou num aparelho novo, onde o
 * convidado redigita o nome) é tudo o que ele tem para se identificar. Um
 * id que não existe mais (linha apagada na planilha) também cai no nome, em
 * vez de deixar o convidado preso a um id órfão.
 *
 * Devolve `null` quando não achou ninguém.
 */
function resolveGuest_(rows, body) {
  var id = clean_(body.id, MAX_GUEST_ID);
  if (id) {
    var byId = findGuestById_(rows, id);
    if (byId !== -1) return guestAt_(rows, byId);
  }

  var name = titleCaseName_(clean_(body.name, MAX_GUEST_NAME));
  if (!name) return null;
  var byName = findGuestByName_(rows, normalizeName_(name));
  return byName === -1 ? null : guestAt_(rows, byName);
}

/** GET: devolve todas as ideias, ou a galeria de fotos com `?action=gallery`. */
function doGet(e) {
  var action = e && e.parameter && e.parameter.action;
  if (action === 'gallery') return doGetGallery_();
  if (action === 'challenges') return json_({ ok: true, challenges: readChallengeBank_() });
  return doGetIdeas_();
}

function doGetIdeas_() {
  var sheet = sheet_();
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return json_({ ideas: [] });

  var rows = sheet.getRange(2, 1, lastRow - 1, HEADERS.length).getValues();
  var ideas = rows
    .filter(function (row) {
      return String(row[2]).trim() !== '';
    })
    .map(function (row) {
      return {
        emoji: String(row[1]),
        name: String(row[2]),
        price: String(row[3]),
        author: String(row[4]),
      };
    });

  return json_({ ideas: ideas });
}

/**
 * Monta o link de exibição de uma foto do Drive.
 *
 * `lh3.googleusercontent.com/d/<id>=w<N>` é o único endpoint terminal dos três
 * que o Drive oferece. Os outros dois são redirects `no-store`:
 * `uc?export=view` cai no endpoint de download, que tem cota por arquivo e
 * responde 403 quando ela estoura; `thumbnail?id=` cai aqui mesmo, gastando um
 * salto que o cache nunca pode poupar.
 *
 * `w600` porque os cards da galeria têm ~200–250px de largura. O sufixo `=w<N>`
 * também é o que `photo_gallery.dart` reescreve para `=w80` enquanto o álbum
 * está borrado — num link sem esse sufixo aquela troca vira no-op silencioso e
 * o card borrado baixa a foto inteira.
 *
 * O que foi medido, e por quê, está em galeria-fotos-carregamento.md, na raiz
 * do repositório.
 */
function photoDisplayUrl_(fileId) {
  return 'https://lh3.googleusercontent.com/d/' + fileId + '=w600';
}

/**
 * Reescreve qualquer link de foto já salvo na planilha (o formato antigo
 * `uc?export=view&id=...`, o `?action=photo&id=...` de uma tentativa anterior,
 * um `file/d/<id>/view` colado à mão, ou um link do CDN com outro `=w<N>`)
 * para o formato de exibição atual, para a galeria se autocorrigir sem
 * migração manual na planilha.
 *
 * Sem id reconhecível, devolve o link como está — melhor mostrar algo que o
 * dono da planilha colou na mão do que montar um link inventado.
 */
function normalizePhotoUrl_(url) {
  var text = String(url);
  var match = text.match(/[?&]id=([A-Za-z0-9_-]+)/) ||
    text.match(/\/d\/([A-Za-z0-9_-]+)/);
  return match ? photoDisplayUrl_(match[1]) : text;
}

function doGetGallery_() {
  var sheet = photoSheet_();
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return json_({ photos: [] });

  // O nome do autor é buscado na aba de convidados a cada leitura, e não
  // copiado para a linha da foto: é o que faz uma correção de nome (pelo
  // site ou à mão na planilha) valer para todas as fotos de quem corrigiu.
  var names = guestNamesById_(guestRows_(guestSheet_()));

  var rows = sheet.getRange(2, 1, lastRow - 1, PHOTO_HEADERS.length).getValues();
  var photos = rows
    .filter(function (row) {
      // foto_url vazio = desafio já sorteado, mas foto ainda não confirmada.
      return String(row[3]).trim() !== '';
    })
    .map(function (row) {
      var author = names[String(row[1])];
      return {
        timestamp: new Date(row[4]).toISOString(), // tirada_em
        // Sem convidado (linha apagada da aba `convidados`) a foto continua
        // no álbum, só que sem dono — perder a foto seria pior.
        author: author || 'Convidado',
        challenge: String(row[2]),
        url: normalizePhotoUrl_(row[3]),
      };
    });

  return json_({ photos: photos });
}

/**
 * POST: dispatcher por `action`. Sem `action` (uso atual do gift-ideas),
 * grava uma ideia nova — comportamento inalterado.
 *
 * O corpo chega como texto puro (JSON) de propósito: `application/json`
 * dispararia um preflight CORS que o Apps Script não responde.
 */
function doPost(e) {
  var body;
  try {
    body = JSON.parse((e && e.postData && e.postData.contents) || '{}');
  } catch (err) {
    return json_({ ok: false, error: 'invalid_json' });
  }

  if (body.action === 'draw') return doPostDraw_(body);
  if (body.action === 'drawMore') return doPostDrawMore_(body);
  if (body.action === 'check') return doPostCheck_(body);
  if (body.action === 'rename') return doPostRename_(body);
  if (body.action === 'upload') return doPostUpload_(body);
  return doPostIdea_(body);
}

/**
 * POST action=check: só consulta se [name] já tem desafios sorteados, sem
 * sortear nem gravar nada — usado para perguntar "é você?" antes de assumir
 * a identidade de um nome já usado por outro convidado.
 *
 * Devolve também o `id` desse convidado, que é o que o site guarda quando o
 * convidado confirma ser ele (ex.: entrando por um aparelho novo).
 */
function doPostCheck_(body) {
  var name = titleCaseName_(clean_(body.name, MAX_GUEST_NAME));
  if (!name) return json_({ ok: false, error: 'missing_name' });

  var guests = guestRows_(guestSheet_());
  var index = findGuestByName_(guests, normalizeName_(name));
  if (index === -1) return json_({ ok: true, id: '', name: name, challenges: [] });

  var guest = guestAt_(guests, index);
  var state = guestState_(photoRows_(photoSheet_()), guest.id);
  return json_({
    ok: true,
    id: guest.id,
    name: guest.name,
    challenges: state.challenges,
  });
}

/**
 * POST action=rename: corrige o nome de um convidado que digitou errado da
 * primeira vez (ex.: sem sobrenome, com erro de digitação).
 *
 * Muda só a célula de nome na aba de convidados — as linhas de
 * desafio/foto guardam o `guest_id`, não o nome, então o álbum já mostra o
 * nome novo em todas as fotos dele sem precisar tocar nelas. `renomeado_em`
 * fica marcado, para quem olhar a planilha saber que aquele nome já foi
 * corrigido ao menos uma vez.
 *
 * Sem senha nem confirmação, igual ao resto deste endpoint: quem tem o
 * `id` do convidado (salvo no navegador dele desde o sorteio) pode
 * corrigir o nome dele.
 */
function doPostRename_(body) {
  var name = titleCaseName_(clean_(body.name, MAX_GUEST_NAME));
  if (!name) return json_({ ok: false, error: 'missing_name' });
  if (countLetters_(name) < 3) return json_({ ok: false, error: 'name_too_short' });

  var lock = LockService.getScriptLock();
  lock.waitLock(15000);
  try {
    var sheet = guestSheet_();
    var rows = guestRows_(sheet);
    var guest = resolveGuest_(rows, body);
    if (!guest) return json_({ ok: false, error: 'unknown_guest' });

    // Outro convidado já usando o nome novo: recusa, para não misturar o
    // histórico de dois convidados sob o mesmo nome (a mesma checagem que
    // já vale para nomes novos no portão, ver doPostCheck_/doPostDraw_).
    var key = normalizeName_(name);
    var clash = findGuestByName_(rows, key);
    if (clash !== -1 && String(rows[clash][0]) !== guest.id) {
      return json_({ ok: false, error: 'name_taken' });
    }

    var index = findGuestById_(rows, guest.id);
    // +2: a leitura de `rows` começa na linha 2 (linha 1 é o cabeçalho).
    sheet.getRange(index + 2, 2, 1, 2).setValues([[name, new Date()]]);

    return json_({ ok: true, id: guest.id, name: name });
  } finally {
    lock.releaseLock();
  }
}

function doPostIdea_(body) {
  var name = clean_(body.name, MAX_NAME);
  if (!name) return json_({ ok: false, error: 'missing_name' });

  var idea = {
    emoji: clean_(body.emoji, MAX_EMOJI) || '💡',
    name: name,
    price: clean_(body.price, MAX_PRICE),
    author: clean_(body.author, MAX_AUTHOR),
  };

  // Duas abas do mesmo formulário podem chegar juntas; o lock evita que uma
  // sobrescreva a linha da outra.
  var lock = LockService.getScriptLock();
  lock.waitLock(15000);
  try {
    var sheet = sheet_();
    sheet.appendRow([new Date(), idea.emoji, idea.name, idea.price, idea.author]);
    if (sheet.getLastRow() > MAX_ROWS + 1) {
      deleteOldestSuggestion_(sheet);
    }
  } finally {
    lock.releaseLock();
  }

  return json_({ ok: true, idea: idea });
}

/**
 * Apaga a sugestão mais antiga de [sheet] para respeitar `MAX_ROWS` — pula
 * linhas com `timestamp` vazio (catálogo oficial, ver comentário de
 * `HEADERS`): elas não devem sumir só porque acumularam sugestões de
 * convidados desde então. Sem sugestão nenhuma para apagar (sheet só com
 * catálogo oficial), não faz nada.
 */
function deleteOldestSuggestion_(sheet) {
  var lastRow = sheet.getLastRow();
  var timestamps = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
  for (var i = 0; i < timestamps.length; i++) {
    if (String(timestamps[i][0]).trim() !== '') {
      sheet.deleteRow(i + 2);
      return;
    }
  }
}

/** Todas as linhas da aba de desafios (sem o cabeçalho). */
function photoRows_(sheet) {
  var lastRow = sheet.getLastRow();
  return lastRow >= 2
    ? sheet.getRange(2, 1, lastRow - 1, PHOTO_HEADERS.length).getValues()
    : [];
}

/**
 * O que o convidado de [guestId] já tem: todos os desafios dele (de todos os
 * sorteios mais os que ele escreveu, na ordem da planilha), as fotos já
 * confirmadas e quantos desafios ainda estão sem foto.
 */
function guestState_(rows, guestId) {
  var challenges = [];
  var photos = {};
  var pending = 0;
  for (var i = 0; i < rows.length; i++) {
    if (String(rows[i][1]) !== guestId) continue;
    var challenge = String(rows[i][2]);
    challenges.push(challenge);
    var url = String(rows[i][3]).trim();
    if (url !== '') {
      photos[challenge] = url;
    } else {
      pending++;
    }
  }
  return { challenges: challenges, photos: photos, pending: pending };
}

/**
 * Frases que algum convidado já pegou — fonte única de verdade para dar
 * preferência às que ainda não saíram para ninguém. Mesmo com dois
 * convidados sorteando ao mesmo tempo, o lock do script serializa esta
 * leitura+escrita.
 */
function usedTexts_(rows) {
  var used = {};
  for (var i = 0; i < rows.length; i++) {
    used[String(rows[i][2])] = true;
  }
  return used;
}

/**
 * Grava um desafio por linha; foto_url/tirada_em ficam vazios até a
 * confirmação da foto (doPostUpload_ preenche na mesma linha).
 */
function appendChallenges_(sheet, guestId, challenges) {
  var sorteioTimestamp = new Date();
  for (var i = 0; i < challenges.length; i++) {
    sheet.appendRow([sorteioTimestamp, guestId, challenges[i], '', '']);
  }
}

/**
 * POST action=draw: sorteia (ou recupera) os desafios de um convidado,
 * criando a linha dele na aba de convidados na primeira vez.
 *
 * A resposta sempre traz `id` e `name`: o `id` é o que o site guarda para
 * se identificar daqui pra frente (e o que ele precisa para corrigir o
 * nome), e o `name` é o que está na planilha — que pode não ser o que este
 * navegador tem salvo, se o convidado corrigiu o nome em outro aparelho.
 */
function doPostDraw_(body) {
  var lock = LockService.getScriptLock();
  lock.waitLock(15000);
  try {
    var guestsSheet = guestSheet_();
    var guests = guestRows_(guestsSheet);
    var guest = resolveGuest_(guests, body);

    if (!guest) {
      var name = titleCaseName_(clean_(body.name, MAX_GUEST_NAME));
      if (!name) return json_({ ok: false, error: 'missing_name' });
      if (countLetters_(name) < 3) return json_({ ok: false, error: 'name_too_short' });
      guest = { id: createGuest_(guestsSheet, guests, name), name: name };
    }

    var sheet = photoSheet_();
    var rows = photoRows_(sheet);

    // Sorteio idempotente por convidado (FR-8): já sorteado, devolve tudo
    // que ele tem de novo — todos os sorteios, não só o último, mais os
    // desafios que ele mesmo escreveu. `photos` traz a foto_url de quem já
    // confirmou algum deles antes, para o site marcar como feito sem
    // depender só do localStorage (ex.: convidado em outro aparelho).
    var state = guestState_(rows, guest.id);
    if (state.challenges.length > 0) {
      return json_({
        ok: true,
        id: guest.id,
        name: guest.name,
        challenges: state.challenges,
        photos: state.photos,
      });
    }

    var challenges = pickChallenges_({}, usedTexts_(rows), CHALLENGES_PER_DRAW);
    appendChallenges_(sheet, guest.id, challenges);

    return json_({
      ok: true,
      id: guest.id,
      name: guest.name,
      challenges: challenges,
      photos: {},
    });
  } finally {
    lock.releaseLock();
  }
}

/**
 * POST action=drawMore: sorteia mais um trio para quem já mandou as fotos de
 * todos os desafios que tinha.
 *
 * Devolve a lista completa do convidado (a de antes mais o sorteio novo) —
 * quando o banco de frases acaba, devolve só a de antes, e o site entende
 * pela ausência de novidades que só sobraram os desafios escritos à mão.
 */
function doPostDrawMore_(body) {
  var lock = LockService.getScriptLock();
  lock.waitLock(15000);
  try {
    var guest = resolveGuest_(guestRows_(guestSheet_()), body);
    if (!guest) return json_({ ok: false, error: 'not_started' });

    var sheet = photoSheet_();
    var rows = photoRows_(sheet);
    var state = guestState_(rows, guest.id);

    if (state.challenges.length === 0) return json_({ ok: false, error: 'not_started' });
    if (state.pending > 0) return json_({ ok: false, error: 'pending_photos' });

    var pickedByGuest = {};
    for (var i = 0; i < state.challenges.length; i++) {
      pickedByGuest[state.challenges[i]] = true;
    }

    var challenges = pickChallenges_(pickedByGuest, usedTexts_(rows), CHALLENGES_PER_DRAW);
    if (challenges.length > 0) appendChallenges_(sheet, guest.id, challenges);

    return json_({
      ok: true,
      id: guest.id,
      name: guest.name,
      challenges: state.challenges.concat(challenges),
      photos: state.photos,
    });
  } finally {
    lock.releaseLock();
  }
}

/** O banco de frases inteiro, com a marca de prioritária. */
function allChallenges_() {
  return readChallengeBank_();
}

/**
 * Sorteia até `count` frases para um convidado. Espelha
 * `drawPhotoChallenges` de lib/utils/challenge_draw.dart, que roda no site
 * quando este endpoint não está configurado — as duas precisam andar juntas.
 *
 * As regras, em ordem:
 *
 * 1. nenhuma frase se repete para o mesmo convidado (`pickedByGuest`);
 * 2. todo sorteio traz pelo menos uma frase prioritária, enquanto sobrar
 *    alguma prioritária que este convidado ainda não pegou;
 * 3. as vagas restantes saem de qualquer frase, com peso maior para as
 *    prioritárias — não é obrigatório sair uma não prioritária;
 * 4. em qualquer vaga, frases que nenhum convidado pegou ainda
 *    (`pickedByAnyone`) têm preferência absoluta sobre as que já saíram para
 *    alguém — o banco de frases é percorrido inteiro antes de repetir;
 * 5. se não sobrar frase suficiente, devolve menos que `count` (inclusive
 *    lista vazia) em vez de repetir.
 */
function pickChallenges_(pickedByGuest, pickedByAnyone, count) {
  var available = allChallenges_().filter(function (challenge) {
    return !pickedByGuest[challenge.text];
  });

  var picked = [];
  var pickedTexts = {};

  function take(candidates) {
    var choice = pickOne_(candidates, pickedByAnyone);
    picked.push(choice.text);
    pickedTexts[choice.text] = true;
  }

  if (count > 0) {
    var priority = available.filter(function (challenge) {
      return challenge.priority;
    });
    if (priority.length > 0) take(priority);
  }

  while (picked.length < count) {
    var candidates = available.filter(function (challenge) {
      return !pickedTexts[challenge.text];
    });
    if (candidates.length === 0) break;
    take(candidates);
  }

  return picked;
}

/**
 * Escolhe uma frase de `candidates`, preferindo as que ninguém pegou ainda
 * e, dentro disso, dando mais peso às prioritárias.
 */
function pickOne_(candidates, pickedByAnyone) {
  var fresh = candidates.filter(function (challenge) {
    return !pickedByAnyone[challenge.text];
  });
  var pool = fresh.length > 0 ? fresh : candidates;

  var weighted = [];
  for (var i = 0; i < pool.length; i++) {
    var weight = pool[i].priority ? PRIORITY_WEIGHT : 1;
    for (var w = 0; w < weight; w++) weighted.push(pool[i]);
  }
  return weighted[Math.floor(Math.random() * weighted.length)];
}

/**
 * Regras da frase que o convidado escreve depois de completar os desafios
 * sorteados — espelha `validateCustomChallenge` de
 * lib/utils/custom_challenge.dart, que é quem avisa o convidado na tela;
 * aqui é só a checagem de quem grava, já que a planilha é pública para
 * escrita.
 */
function isValidCustomChallenge_(text) {
  var first = text.charAt(0);
  if (countLetters_(first) === 0 || first !== first.toUpperCase()) return false;

  var words = text.split(/\s+/);
  if (words.length < 3) return false;
  for (var i = 0; i < words.length; i++) {
    if (countLetters_(words[i]) < 2) return false;
  }

  // Comparação em maiúsculas: o que muda só na caixa é o mesmo desafio.
  var upper = text.toUpperCase();
  var all = allChallenges_();
  for (var j = 0; j < all.length; j++) {
    if (all[j].text.toUpperCase() === upper) return false;
  }

  return true;
}

/** POST action=upload: salva a foto de um desafio confirmado. */
function doPostUpload_(body) {
  var guest = resolveGuest_(guestRows_(guestSheet_()), body);
  if (!guest) return json_({ ok: false, error: 'unknown_guest' });
  var name = guest.name;

  var challenge = clean_(body.challenge, MAX_CHALLENGE);
  if (!challenge) return json_({ ok: false, error: 'missing_challenge' });

  var photoBase64 = body.photo;
  if (!photoBase64) return json_({ ok: false, error: 'missing_photo' });

  var mimeType = clean_(body.mimeType, MAX_MIME) || 'image/jpeg';
  var timestamp = body.timestamp ? new Date(body.timestamp) : new Date();

  // Sobe pro Drive antes do lock, para segurar o lock pelo menor tempo
  // possível — o upload em si não precisa de coordenação entre convidados.
  var url;
  try {
    var bytes = Utilities.base64Decode(photoBase64);
    var blob = Utilities.newBlob(bytes, mimeType, name + '-' + challenge + '.jpg');
    var folder = DriveApp.getFolderById(PHOTOS_FOLDER_ID);
    var file = folder.createFile(blob);
    // A permissão por link é o que deixa o CDN servir a foto para quem abrir
    // o site sem estar logado numa conta com acesso à pasta.
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
    url = photoDisplayUrl_(file.getId());
  } catch (err) {
    return json_({ ok: false, error: 'upload_failed', detail: String((err && err.message) || err) });
  }

  var lock = LockService.getScriptLock();
  lock.waitLock(15000);
  try {
    var sheet = photoSheet_();
    var lastRow = sheet.getLastRow();
    var rows = lastRow >= 2
      ? sheet.getRange(2, 1, lastRow - 1, PHOTO_HEADERS.length).getValues()
      : [];

    // Acha a linha do desafio sorteado do convidado (doPostDraw_ já criou
    // uma linha vazia de foto_url/tirada_em pra cada desafio) e preenche
    // nela — não cria uma linha nova.
    var rowIndex = -1;
    for (var i = 0; i < rows.length; i++) {
      if (String(rows[i][1]) === guest.id && String(rows[i][2]) === challenge) {
        rowIndex = i;
        break;
      }
    }

    if (rowIndex === -1) {
      // Desafio escrito pelo próprio convidado: não existe linha sorteada
      // esperando por ele, a linha nasce aqui já com a foto.
      if (body.custom !== true) return json_({ ok: false, error: 'challenge_not_assigned' });
      if (!isValidCustomChallenge_(challenge)) {
        return json_({ ok: false, error: 'invalid_challenge' });
      }
      sheet.appendRow([timestamp, guest.id, challenge, url, timestamp]);
    } else if (String(rows[rowIndex][3]).trim() !== '') {
      return json_({ ok: false, error: 'duplicate' });
    } else {
      // +2: a leitura acima começa na linha 2 (linha 1 é o cabeçalho).
      sheet.getRange(rowIndex + 2, 4, 1, 2).setValues([[url, timestamp]]);
    }
  } finally {
    lock.releaseLock();
  }

  return json_({ ok: true, url: url });
}
