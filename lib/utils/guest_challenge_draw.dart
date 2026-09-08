/// Desafios de um convidado, guardados no navegador (FR-8, FR-10).
library;

import 'dart:convert';

import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

import '../constants/photo_challenges.dart';

/// Prefixo da chave de `localStorage` com os desafios + fotos de um
/// convidado. Cada convidado tem sua própria chave, pelo nome.
const _guestDrawStorageKeyPrefix = 'casar-photo-draw::';

String _storageKeyFor(String guestName) =>
    '$_guestDrawStorageKeyPrefix$guestName';

/// Desafios de [guestName] guardados neste navegador.
///
/// [challenges] tem todos os desafios do convidado, de todos os sorteios
/// mais os que ele escreveu, na ordem em que apareceram; [photos] mapeia o
/// texto do desafio para a foto confirmada dele; [revealed] tem os textos
/// cuja animação de sorteio já rodou (cada sorteio novo anima só os seus).
typedef GuestChallengeDraw = ({
  List<PhotoChallenge> challenges,
  Map<String, String> photos,
  Set<String> revealed,
});

/// Lê os desafios de [guestName] guardados neste navegador, se houver.
GuestChallengeDraw? readGuestChallengeDraw(String guestName) {
  if (!kIsWeb) return null;
  final raw = web.window.localStorage.getItem(_storageKeyFor(guestName));
  if (raw == null || raw.isEmpty) return null;
  try {
    final json = jsonDecode(raw) as Map;
    final challenges = [
      for (final text in (json['challenges'] as List).cast<String>())
        resolvePhotoChallenge(text),
    ];
    final photos = <String, String>{
      for (final entry in (json['photos'] as Map).entries)
        '${entry.key}': '${entry.value}',
    };
    return (
      challenges: challenges,
      photos: photos,
      revealed: _readRevealed(json['revealed'], challenges),
    );
  } catch (_) {
    return null;
  }
}

/// `revealed` já foi um booleano para o sorteio único de 3 desafios; hoje é a
/// lista dos textos já revelados, porque cada sorteio novo anima só as frases
/// dele. Um `true` antigo vale por "tudo que estava salvo já foi revelado".
Set<String> _readRevealed(Object? stored, List<PhotoChallenge> challenges) {
  if (stored is List) return {for (final text in stored) '$text'};
  if (stored == true) return {for (final c in challenges) c.text};
  return const {};
}

/// Salva os desafios de [guestName] neste navegador.
void writeGuestChallengeDraw(
  String guestName,
  List<PhotoChallenge> challenges,
  Map<String, String> photos, {
  required Set<String> revealed,
}) {
  if (!kIsWeb) return;
  web.window.localStorage.setItem(
    _storageKeyFor(guestName),
    jsonEncode({
      'challenges': [for (final c in challenges) c.text],
      'photos': photos,
      'revealed': revealed.toList(),
    }),
  );
}

/// Apaga os desafios de [guestName] guardados neste navegador.
void removeGuestChallengeDraw(String guestName) {
  if (!kIsWeb) return;
  web.window.localStorage.removeItem(_storageKeyFor(guestName));
}
