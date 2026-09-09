/// Modo prévia: o jeito de os noivos passearem pelo `/fotos` antes do
/// casamento — trocar de nome à vontade e ver o álbum sem o borrão de
/// FR-18 — num site já publicado, onde `kDebugMode` é sempre falso.
///
/// Fica ligado neste navegador até ser desligado no painel, para não ter
/// que redigitar a senha a cada recarga.
library;

import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

import '../constants/wedding_data.dart';

/// Chave usada no `localStorage` para lembrar que o modo prévia está ligado.
const previewModeStorageKey = 'casar-preview-mode';

/// Nome do parâmetro de URL que também liga o modo prévia, para quando o
/// navegador já tem um nome salvo e o portão do nome (onde a senha seria
/// digitada) nem chega a aparecer: `/fotos?previa=felipe+julia`.
const previewModeQueryParam = 'previa';

/// Acentos que os noivos não deveriam precisar acertar para digitar a
/// senha no teclado do celular.
const _accentFolding = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

/// Deixa [value] comparável: minúsculo, sem acento e sem espaço nenhum.
String _fold(String value) {
  final buffer = StringBuffer();
  for (final char in value.toLowerCase().split('')) {
    if (char.trim().isEmpty) continue;
    buffer.write(_accentFolding[char] ?? char);
  }
  return buffer.toString();
}

/// As duas formas aceitas da senha: os nomes dos noivos unidos por `+`, em
/// qualquer ordem.
final _previewCodes = {
  _fold('$groomName+$brideName'),
  _fold('$brideName+$groomName'),
};

/// Se [raw] — digitado no lugar do nome, ou vindo de
/// [previewModeQueryParam] — é a senha que liga o modo prévia.
///
/// Casa sem depender de acento, caixa ou espaço, mas exige o `+` no meio:
/// um convidado que escreva "Júlia e Felipe" de brincadeira continua sendo
/// tratado como convidado.
bool isPreviewModeCode(String raw) => _previewCodes.contains(_fold(raw));

/// Se o modo prévia está ligado neste navegador — ou se a URL atual traz a
/// senha em [previewModeQueryParam], caso em que também fica salvo.
bool readPreviewMode() {
  if (!kIsWeb) return false;
  if (web.window.localStorage.getItem(previewModeStorageKey) == 'on') {
    return true;
  }
  final fromUrl = Uri.parse(
    web.window.location.href,
  ).queryParameters[previewModeQueryParam];
  // Numa query string, `+` significa espaço e é isso que o `Uri` devolve —
  // desfazer aqui deixa `?previa=felipe+julia` funcionar sem obrigar
  // ninguém a escrever `%2B` na barra de endereços.
  if (fromUrl == null || !isPreviewModeCode(fromUrl.replaceAll(' ', '+'))) {
    return false;
  }
  writePreviewMode(enabled: true);
  return true;
}

/// Liga ou desliga o modo prévia neste navegador.
void writePreviewMode({required bool enabled}) {
  if (!kIsWeb) return;
  if (enabled) {
    web.window.localStorage.setItem(previewModeStorageKey, 'on');
  } else {
    web.window.localStorage.removeItem(previewModeStorageKey);
  }
}
