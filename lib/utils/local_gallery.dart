/// Galeria local de apoio, usada quando o Apps Script não está configurado
/// (FR-15, FR-16 em modo degradado): guarda as fotos confirmadas por
/// qualquer convidado *neste navegador*.
///
/// Compartilhada entre `/fotos` (que grava, ao confirmar uma foto) e
/// `/album` (que só lê, para mostrar o mesmo álbum sem passar pelo portão de
/// nome).
library;

import 'dart:convert';

import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

import '../constants/photo_challenges.dart';

const localGalleryStorageKey = 'casar-photo-gallery-local';

void appendLocalGalleryPhoto(GalleryPhoto photo) {
  if (!kIsWeb) return;
  final raw = web.window.localStorage.getItem(localGalleryStorageKey);
  final list = raw == null || raw.isEmpty
      ? <dynamic>[]
      : jsonDecode(raw) as List;
  list.add({
    'challenge': photo.challengeText,
    'author': photo.authorName,
    'url': photo.photoUrl,
    'timestamp': photo.takenAt.toIso8601String(),
  });
  web.window.localStorage.setItem(localGalleryStorageKey, jsonEncode(list));
}

List<GalleryPhoto> readLocalGalleryPhotos() {
  if (!kIsWeb) return [];
  final raw = web.window.localStorage.getItem(localGalleryStorageKey);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List;
    return [
      for (final entry in list)
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
    return [];
  }
}
