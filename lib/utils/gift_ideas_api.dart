import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/config.dart';
import '../constants/wedding_data.dart';

/// Ponte entre o site estático e a planilha do Google que guarda as ideias
/// sugeridas pelos convidados.
///
/// O GitHub Pages não tem servidor, então quem grava é um Apps Script
/// publicado como Web App — veja [giftIdeasEndpoint].
class GiftIdeasApi {
  const GiftIdeasApi();

  bool get isEnabled => giftIdeasEndpoint.isNotEmpty;

  /// Ideias que já estão na planilha. Devolve `null` quando não deu para
  /// buscar, para o chamador saber diferenciar "ninguém sugeriu nada" de
  /// "não consegui falar com a planilha".
  Future<List<GiftItem>?> fetchIdeas() async {
    if (!isEnabled) return null;
    try {
      final response = await http
          .get(Uri.parse(giftIdeasEndpoint))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! Map || body['ideas'] is! List) return null;

      return [
        for (final entry in body['ideas'] as List)
          if (entry is Map && '${entry['name']}'.trim().isNotEmpty)
            GiftItem(
              emoji: '${entry['emoji'] ?? '💡'}',
              name: '${entry['name']}',
              price: '${entry['price'] ?? ''}',
              author: '${entry['author'] ?? ''}',
            ),
      ];
    } catch (_) {
      return null;
    }
  }

  /// Grava uma ideia nova. `false` quer dizer que a sugestão não chegou na
  /// planilha e o convidado precisa saber disso.
  Future<bool> submitIdea(GiftItem idea) async {
    if (!isEnabled) return false;
    try {
      final response = await http
          .post(
            Uri.parse(giftIdeasEndpoint),
            // `text/plain` de propósito: `application/json` faria o navegador
            // mandar um preflight CORS que o Apps Script não responde.
            headers: const {'Content-Type': 'text/plain;charset=UTF-8'},
            body: jsonEncode({
              'emoji': idea.emoji,
              'name': idea.name,
              'price': idea.price,
              'author': idea.author,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;

      final body = jsonDecode(response.body);
      return body is Map && body['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}
