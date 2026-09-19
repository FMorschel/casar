import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/config.dart';
import '../constants/photo_challenges.dart';

/// Ponte entre o site estático e a planilha do Google que guarda os
/// desafios sorteados e as fotos enviadas pelos convidados.
///
/// O GitHub Pages não tem servidor, então quem grava é um Apps Script
/// publicado como Web App — veja [photoChallengesEndpoint].
class PhotoChallengesApi {
  const PhotoChallengesApi();

  bool get isEnabled => photoChallengesEndpoint.isNotEmpty;

  /// Verifica se [guestName] já tem desafios sorteados, sem sortear nem
  /// gravar nada.
  ///
  /// Usado antes de assumir um nome (FR-2/FR-3): se já existe sorteio para
  /// esse nome, quem está digitando pode não ser a mesma pessoa que
  /// sorteou da primeira vez. Devolve lista vazia (com [DrawnChallenges.guestId]
  /// vazio) quando o nome ainda não tem sorteio, e `null` quando a chamada
  /// falha (o chamador trata como "não deu pra checar" e segue em frente,
  /// para não travar o convidado).
  Future<DrawnChallenges?> checkExisting(
    String guestName, {
    required List<PhotoChallenge> challengeBank,
  }) async {
    if (!isEnabled) return null;
    try {
      final response = await http
          .post(
            Uri.parse(photoChallengesEndpoint),
            headers: const {'Content-Type': 'text/plain;charset=UTF-8'},
            body: jsonEncode({'action': 'check', 'name': guestName}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      return _parseDraw(response.body, challengeBank).$1;
    } catch (_) {
      return null;
    }
  }

  /// Busca o banco de frases dos desafios (aba `banco_desafios` da
  /// planilha) — única fonte dele, sem cópia local no site. Devolve `null`
  /// quando não deu para buscar.
  Future<List<PhotoChallenge>?> fetchChallengeBank() async {
    if (!isEnabled) return null;
    try {
      final response = await http
          .get(Uri.parse('$photoChallengesEndpoint?action=challenges'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! Map || body['ok'] != true || body['challenges'] is! List) {
        return null;
      }

      return [
        for (final entry in body['challenges'] as List)
          if (entry is Map)
            PhotoChallenge(
              text: '${entry['text']}',
              priority: entry['priority'] == true,
            ),
      ];
    } catch (_) {
      return null;
    }
  }

  /// Sorteia (ou recupera) os desafios de [guestName].
  ///
  /// [guestId] é o id salvo deste convidado (ver [GuestChallengeDraw] /
  /// `guest_name.dart`), quando este navegador já tem um — é o que deixa o
  /// servidor reconhecer o convidado mesmo que o nome dele tenha sido
  /// corrigido em outro aparelho desde então. Sem id (primeira vez), o
  /// servidor casa pelo nome e cria o convidado se for a primeira vez dele
  /// em qualquer aparelho.
  ///
  /// Idempotente por convidado (FR-8): chamar de novo para o mesmo
  /// convidado devolve tudo que ele já tem — todos os sorteios, não só o
  /// último, mais os desafios que ele mesmo escreveu — em vez de sortear
  /// outra vez. Devolve `null` quando a chamada falha, para o chamador cair
  /// no sorteio local (FR-9) em vez de travar o convidado sem desafios.
  ///
  /// `confirmedPhotos` traz a URL de quem já confirmou a foto de algum
  /// desses desafios antes (ex.: o convidado abrindo em outro aparelho, sem
  /// o `localStorage` de quando confirmou) — chave é o texto do desafio.
  Future<DrawnChallenges?> drawChallenges(
    String guestName, {
    String? guestId,
    required List<PhotoChallenge> challengeBank,
  }) async {
    final (drawn, _) = await _postDraw({
      'action': 'draw',
      'name': guestName,
      if (guestId != null) 'id': guestId,
    }, challengeBank);
    return drawn;
  }

  /// Sorteia mais um trio para o convidado de [guestId]/[guestName], depois
  /// que ele mandou as fotos de todos os desafios que já tinha.
  ///
  /// Devolve a lista completa dele (a de antes mais o sorteio novo), igual a
  /// [drawChallenges]. Quando o banco de frases acaba, o servidor responde
  /// com a mesma lista de antes — o chamador percebe que nada foi somado e
  /// avisa que só sobraram os desafios escritos à mão.
  ///
  /// O segundo item do record é o motivo da falha (ex.: `pending_photos`,
  /// vindo do `error` que o Apps Script devolve, ou a exceção de rede/timeout
  /// como string) — só para mostrar ao convidado no toast de erro, não para
  /// decisão de fluxo.
  Future<(DrawnChallenges?, String?)> drawMore(
    String guestName, {
    String? guestId,
    required List<PhotoChallenge> challengeBank,
  }) async {
    return _postDraw({
      'action': 'drawMore',
      'name': guestName,
      if (guestId != null) 'id': guestId,
    }, challengeBank);
  }

  Future<(DrawnChallenges?, String?)> _postDraw(
    Map<String, Object?> payload,
    List<PhotoChallenge> challengeBank,
  ) async {
    if (!isEnabled) return (null, 'endpoint_disabled');
    try {
      final response = await http
          .post(
            Uri.parse(photoChallengesEndpoint),
            headers: const {'Content-Type': 'text/plain;charset=UTF-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return (null, 'http_${response.statusCode}');
      }
      return _parseDraw(response.body, challengeBank);
    } catch (err) {
      return (null, '$err');
    }
  }

  /// Lê a resposta de `draw`/`drawMore`/`check`, que têm o mesmo formato.
  ///
  /// Frases fora de [challengeBank] são as que o próprio convidado
  /// escreveu, então voltam como [PhotoChallenge.custom] em vez de
  /// invalidarem a resposta inteira.
  (DrawnChallenges?, String?) _parseDraw(
    String responseBody,
    List<PhotoChallenge> challengeBank,
  ) {
    final body = jsonDecode(responseBody);
    if (body is! Map || body['ok'] != true || body['challenges'] is! List) {
      final error = body is Map ? body['error'] : null;
      return (null, error != null ? '$error' : 'invalid_response');
    }

    final photos = body['photos'];
    return (
      DrawnChallenges(
        guestId: '${body['id'] ?? ''}',
        guestName: '${body['name'] ?? ''}',
        challenges: [
          for (final text in body['challenges'] as List)
            resolvePhotoChallenge(challengeBank, '$text'),
        ],
        confirmedPhotos: {
          if (photos is Map)
            for (final entry in photos.entries)
              '${entry.key}': '${entry.value}',
        },
      ),
      null,
    );
  }

  /// Envia a foto de um desafio confirmado.
  ///
  /// [photoDataUrl] é a string completa `data:image/...;base64,...` que
  /// vem do canvas de captura. Devolve a URL da foto já salva, ou o motivo
  /// do erro (`http_<status>`, o `error` que o Apps Script devolve, ou a
  /// exceção de rede/timeout como string) quando o envio falha — nesse caso
  /// o chamador mantém a foto no `localStorage` para tentar de novo depois
  /// (FR-15).
  ///
  /// Um desafio escrito pelo convidado ([PhotoChallenge.isCustom]) não tem
  /// linha sorteada esperando na planilha; o servidor cria a linha dele no
  /// momento do envio.
  Future<(String?, String?)> uploadPhoto({
    required String guestName,
    String? guestId,
    required PhotoChallenge challenge,
    required String photoDataUrl,
    required DateTime takenAt,
  }) async {
    if (!isEnabled) return (null, 'endpoint_disabled');
    try {
      final commaIndex = photoDataUrl.indexOf(',');
      if (commaIndex == -1) return (null, 'invalid_photo_data');
      final header = photoDataUrl.substring(5, commaIndex); // after 'data:'
      final mimeType = header.split(';').first;
      final base64Data = photoDataUrl.substring(commaIndex + 1);

      final response = await http
          .post(
            Uri.parse(photoChallengesEndpoint),
            headers: const {'Content-Type': 'text/plain;charset=UTF-8'},
            body: jsonEncode({
              'action': 'upload',
              'name': guestName,
              if (guestId != null) 'id': guestId,
              'challenge': challenge.text,
              'custom': challenge.isCustom,
              'photo': base64Data,
              'mimeType': mimeType,
              'timestamp': takenAt.toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        return (null, 'http_${response.statusCode}');
      }

      final body = jsonDecode(response.body);
      if (body is! Map || body['ok'] != true) {
        final error = body is Map ? body['error'] : null;
        return (null, error != null ? '$error' : 'invalid_response');
      }
      return ('${body['url']}', null);
    } catch (err) {
      return (null, '$err');
    }
  }

  /// Corrige o nome do convidado de [guestId] (FR de renomear): quem
  /// escreveu o nome errado da primeira vez pode consertá-lo depois — vale
  /// para todas as fotos já enviadas por ele, já que a planilha guarda o
  /// desafio/foto pelo id, não pelo nome (ver tools/apps_script/Code.gs).
  ///
  /// Devolve o nome já normalizado pelo servidor quando dá certo, ou o
  /// motivo do erro (`name_too_short`, `name_taken`, `unknown_guest`, ou a
  /// exceção de rede/timeout como string) caso contrário.
  Future<(String?, String?)> renameGuest({
    required String guestId,
    required String newName,
  }) async {
    if (!isEnabled) return (null, 'endpoint_disabled');
    try {
      final response = await http
          .post(
            Uri.parse(photoChallengesEndpoint),
            headers: const {'Content-Type': 'text/plain;charset=UTF-8'},
            body: jsonEncode({
              'action': 'rename',
              'id': guestId,
              'name': newName,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return (null, 'http_${response.statusCode}');
      }

      final body = jsonDecode(response.body);
      if (body is! Map || body['ok'] != true) {
        final error = body is Map ? body['error'] : null;
        return (null, error != null ? '$error' : 'invalid_response');
      }
      return ('${body['name']}', null);
    } catch (err) {
      return (null, '$err');
    }
  }

  /// Busca as fotos confirmadas de todos os convidados (FR-16).
  ///
  /// Devolve `null` quando não deu para buscar, para o chamador diferenciar
  /// "ninguém confirmou fotos ainda" de "não consegui falar com a planilha".
  Future<List<GalleryPhoto>?> fetchGallery() async {
    if (!isEnabled) return null;
    try {
      final response = await http
          .get(Uri.parse('$photoChallengesEndpoint?action=gallery'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! Map || body['photos'] is! List) return null;

      return [
        for (final entry in body['photos'] as List)
          if (entry is Map)
            GalleryPhoto(
              challengeText: '${entry['challenge']}',
              authorName: '${entry['author']}',
              photoUrl: '${entry['url']}',
              takenAt:
                  DateTime.tryParse('${entry['timestamp']}') ?? DateTime.now(),
            ),
      ];
    } catch (_) {
      return null;
    }
  }
}
