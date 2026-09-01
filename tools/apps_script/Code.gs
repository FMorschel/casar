/**
 * Backend "serverless" da lista de presentes do casar.
 *
 * Guarda as ideias sugeridas pelos convidados numa planilha do Google e as
 * devolve para o site estático (GitHub Pages), que não tem servidor próprio.
 *
 * Como publicar: veja tools/apps_script/README.md
 */

var SHEET_ID = '1k3tCCPiyT5ZT9Bf11rGKgDognTCDmyjYxFj8R7P9XeU';
var SHEET_NAME = 'ideias';

/** Colunas da planilha, na ordem. */
var HEADERS = ['timestamp', 'emoji', 'nome', 'valor', 'autor'];

/** Limites de tamanho — a planilha é pública para escrita, então nada entra sem teto. */
var MAX_EMOJI = 8;
var MAX_NAME = 120;
var MAX_PRICE = 20;
var MAX_AUTHOR = 60;

/** Teto de ideias guardadas: passou disso, a mais antiga sai. */
var MAX_ROWS = 500;

function sheet_() {
  var ss = SpreadsheetApp.openById(SHEET_ID);
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_NAME);
  }
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(HEADERS);
  }
  return sheet;
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

/** GET: devolve todas as ideias que os convidados já mandaram. */
function doGet() {
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
 * POST: grava uma ideia nova.
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
      sheet.deleteRow(2);
    }
  } finally {
    lock.releaseLock();
  }

  return json_({ ok: true, idea: idea });
}
