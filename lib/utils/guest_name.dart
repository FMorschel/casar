/// Nome do convidado, guardado no navegador para identificar quem sorteia
/// desafios e envia fotos (FR-2, FR-3, FR-4, FR-8).
library;

import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

/// Chave usada no `localStorage` para guardar o nome do convidado.
const guestNameStorageKey = 'casar-guest-name';

/// Chave usada no `localStorage` para guardar o id do convidado na
/// planilha (aba `convidados`) — o que o site manda de volta ao servidor
/// para se identificar sem depender só do nome, e o que permite corrigir o
/// nome depois (FR de renomear, ver [PhotoChallengesApi.renameGuest]).
///
/// Só existe depois do primeiro sorteio: antes disso o servidor ainda não
/// tinha criado o convidado.
const guestIdStorageKey = 'casar-guest-id';

/// Lê o nome do convidado salvo neste navegador.
///
/// `null` na primeira visita, ou fora da web (SSR/estático).
String? readGuestName() {
  if (!kIsWeb) return null;
  final stored = web.window.localStorage.getItem(guestNameStorageKey);
  return (stored == null || stored.isEmpty) ? null : stored;
}

/// Salva o [name] do convidado exatamente como veio — é o chamador quem
/// deve mandar o nome já normalizado (veja [normalizeGuestName]), esta
/// função não mexe nele.
void writeGuestName(String name) {
  if (!kIsWeb) return;
  web.window.localStorage.setItem(guestNameStorageKey, name);
}

/// Lê o id do convidado salvo neste navegador, se houver.
String? readGuestId() {
  if (!kIsWeb) return null;
  final stored = web.window.localStorage.getItem(guestIdStorageKey);
  return (stored == null || stored.isEmpty) ? null : stored;
}

/// Salva o id do convidado devolvido pelo servidor.
void writeGuestId(String id) {
  if (!kIsWeb) return;
  web.window.localStorage.setItem(guestIdStorageKey, id);
}

/// Apaga o id do convidado salvo neste navegador.
void removeGuestId() {
  if (!kIsWeb) return;
  web.window.localStorage.removeItem(guestIdStorageKey);
}

/// Normaliza o nome do convidado: corta espaços nas pontas, colapsa
/// espaços internos repetidos e capitaliza cada palavra (ex.:
/// `"  maria  DA silva"` vira `"Maria Da Silva"`).
///
/// Devolve string vazia se não sobrar nada depois do `trim`, para o
/// chamador tratar como nome ausente.
String normalizeGuestName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  return trimmed
      .split(RegExp(r'\s+'))
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

/// Quantas letras (sem contar espaços, números ou pontuação) [name] tem.
int _letterCount(String name) =>
    RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]').allMatches(name).length;

/// Menor quantidade de letras aceita num nome de convidado.
const minGuestNameLetters = 3;

/// Se [name] (já normalizado, ver [normalizeGuestName]) é longo o
/// suficiente para ser aceito como nome de convidado.
bool isGuestNameLongEnough(String name) =>
    _letterCount(name) >= minGuestNameLetters;
