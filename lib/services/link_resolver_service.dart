import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:musly/models/song.dart';
import 'package:musly/services/deezer_service.dart';

class LinkResolverService {
  static final LinkResolverService _instance = LinkResolverService._internal();
  factory LinkResolverService() => _instance;
  LinkResolverService._internal();

  /// Vérifie si le texte saisi correspond à une URL de partage musical
  static bool isMusicLink(String text) {
    final t = text.trim().toLowerCase();
    if (!t.startsWith('http://') &&
        !t.startsWith('https://') &&
        !t.startsWith('spotify:') &&
        !t.startsWith('deezer:') &&
        !t.startsWith('musly:')) {
      return false;
    }
    return t.contains('spotify.com') ||
        t.contains('deezer.com') ||
        t.contains('deezer.page.link') ||
        t.contains('music.corentinjanin.fr/track/') ||
        t.contains('musly://track/');
  }

  /// Résout le lien vers un morceau Song complet
  static Future<Song?> resolveLink(String link) async {
    final t = link.trim();
    if (!isMusicLink(t)) return null;

    try {
      // 1. Lien Musly direct (ex: https://music.corentinjanin.fr/track/{songId} ou musly://track/{id})
      if (t.contains('/track/')) {
        final uri = Uri.tryParse(t);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          final songId = uri.pathSegments.last;
          if (songId.isNotEmpty) {
            final cleanId = songId.replaceAll('ext_dz_', '');
            final song = await DeezerService().getTrackDetails(cleanId);
            if (song != null) return song;
          }
        }
      }

      // 2. Lien Deezer (ex: https://www.deezer.com/track/1109731 ou deezer.com/fr/track/1109731)
      if (t.contains('deezer.com/track/') || t.contains('/track/')) {
        final regExp = RegExp(r'track\/(\d+)');
        final match = regExp.firstMatch(t);
        if (match != null) {
          final trackId = match.group(1);
          if (trackId != null) {
            return await DeezerService().getTrackDetails(trackId);
          }
        }
      }

      // 3. Lien Spotify (ex: https://open.spotify.com/track/{id})
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
