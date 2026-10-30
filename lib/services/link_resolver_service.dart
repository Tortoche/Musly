import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:musly/models/song.dart';
import 'package:musly/services/deezer_service.dart';

class LinkResolverService {
  static final LinkResolverService _instance = LinkResolverService._internal();
  factory LinkResolverService() => _instance;
  LinkResolverService._internal();

  /// Vérifie si le texte saisi correspond à une URL ou URI de partage musical
  static bool isMusicLink(String text) {
    final t = text.trim().toLowerCase();
    return t.contains('spotify.com') ||
        t.contains('spotify:') ||
        t.contains('deezer.com') ||
        t.contains('deezer.page.link') ||
        t.contains('deezer:') ||
        t.contains('music.corentinjanin.fr/track') ||
        t.contains('musly://') ||
        t.contains('intent://') ||
        t.contains('/track/');
  }

  /// Résout le lien vers un morceau Song complet
  static Future<Song?> resolveLink(String link) async {
    final t = link.trim();
    if (!isMusicLink(t)) return null;

    try {
      // 1. Lien Musly direct, Deezer track ou Intent (ex: musly://track/ext_dz_3862037071, https://music.corentinjanin.fr/track/ext_dz_3862037071)
      final trackMatch = RegExp(r'track\/([a-zA-Z0-9_\-]+)').firstMatch(t);
      if (trackMatch != null) {
        final rawId = trackMatch.group(1)!;
        final cleanId = rawId
            .replaceAll('ext_dz_', '')
            .split('#')
            .first
            .split('?')
            .first
            .trim();
        if (cleanId.isNotEmpty) {
          final song = await DeezerService().getTrackDetails(cleanId);
          if (song != null) return song;
        }
      }

      // 2. Lien Spotify (ex: https://open.spotify.com/track/{id})
      if (t.contains('spotify.com/track/')) {
        final oembedUrl = Uri.parse(
          'https://open.spotify.com/oembed?url=${Uri.encodeComponent(t)}',
        );
        final res = await http.get(oembedUrl);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final title = data['title'] as String? ?? '';
          if (title.isNotEmpty) {
            final songs = await DeezerService().searchTracks(title, limit: 1);
            if (songs.isNotEmpty) return songs.first;
          }
        }
      }
    } catch (e) {
      debugPrint('[LinkResolverService] Erreur résolution lien: $e');
    }

    return null;
  }
}
