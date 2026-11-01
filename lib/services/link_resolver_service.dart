import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:musly/main.dart';
import 'package:musly/models/song.dart';
import 'package:musly/services/deezer_service.dart';
import 'package:musly/services/subsonic_service.dart';

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
  static Future<Song?> resolveLink(String link, {BuildContext? context}) async {
    final t = link.trim();
    if (!isMusicLink(t)) return null;

    try {
      // 0. Résolution dynamique via le serveur CJ Music Resolver si accessible
      try {
        final serverUrl = Uri.parse('https://music.corentinjanin.fr/api/resolve?url=${Uri.encodeComponent(t)}');
        final sRes = await http.get(serverUrl).timeout(const Duration(seconds: 3));
        if (sRes.statusCode == 200) {
          final sData = jsonDecode(sRes.body) as Map<String, dynamic>;
          if (sData['status'] == 'success' && sData['id'] != null) {
            final songId = sData['id'].toString();
            return Song(
              id: songId,
              title: sData['title'] ?? 'Titre inconnu',
              artist: sData['artist'] ?? 'Artiste inconnu',
              album: sData['album']?.toString(),
              coverArt: sData['cover_url']?.toString(),
              duration: (sData['duration'] as num?)?.toInt(),
            );
          }
        }
      } catch (_) {}

      // 1. Lien Musly direct, Deezer track ou Intent (ex: musly://track/ext_dz_3862037071, musly://track/5mWmy8AoMwEeTUvFBcO3vx)
      final trackMatch = RegExp(r'track\/([a-zA-Z0-9_\-]+)').firstMatch(t);
      if (trackMatch != null) {
        final rawId = trackMatch
            .group(1)!
            .split('#')
            .first
            .split('?')
            .first
            .trim();

        if (rawId.isNotEmpty) {
          // A. Si c'est un morceau Deezer externe (ext_dz_... ou ID numérique)
          if (rawId.startsWith('ext_dz_') || RegExp(r'^\d+$').hasMatch(rawId)) {
            final cleanId = rawId.replaceAll('ext_dz_', '');
            final song = await DeezerService().getTrackDetails(cleanId);
            if (song != null) return song;
          }

          // B. Tenter de récupérer le morceau via Subsonic directement si l'app est connectée
          final ctx = context ?? navigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            try {
              final subsonic = Provider.of<SubsonicService>(ctx, listen: false);
              final song = await subsonic.getSong(rawId);
              if (song != null) return song;
            } catch (_) {}
          }

          // C. Fallback universel : extraction des métadonnées de la page web Musly
          try {
            final pageUrl = Uri.parse('https://music.corentinjanin.fr/track/$rawId');
            final res = await http.get(pageUrl).timeout(const Duration(seconds: 4));
            if (res.statusCode == 200) {
              final html = res.body;

              String title = '';
              final tMatch = RegExp(r'<h1[^>]*class="track-title"[^>]*>(.*?)</h1>', caseSensitive: false).firstMatch(html) ??
                  RegExp(r'property="og:title"\s+content="(.*?)"', caseSensitive: false).firstMatch(html);
              if (tMatch != null) {
                title = tMatch.group(1)?.trim() ?? '';
              }

              String artist = 'Musly';
              final aMatch = RegExp(r'<div[^>]*class="track-artist"[^>]*>(.*?)</div>', caseSensitive: false).firstMatch(html);
              if (aMatch != null) {
                artist = aMatch.group(1)?.trim() ?? 'Musly';
              }

              String? cover;
              final cMatch = RegExp(r'property="og:image"\s+content="(.*?)"', caseSensitive: false).firstMatch(html);
              if (cMatch != null) {
                cover = cMatch.group(1)?.trim();
              }

              if (title.isNotEmpty) {
                return Song(
                  id: rawId,
                  title: title,
                  artist: artist,
                  coverArt: (cover != null && cover.isNotEmpty) ? cover : null,
                );
              }
            }
          } catch (e) {
            debugPrint('[LinkResolverService] Erreur fallback web : $e');
          }
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
