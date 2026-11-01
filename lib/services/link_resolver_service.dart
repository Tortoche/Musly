import '../models/playlist.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:musly/main.dart';
import 'package:musly/models/song.dart';
import 'package:musly/services/deezer_service.dart';
import 'package:musly/services/subsonic_service.dart';

class LinkResolverService {
  /// Développe une URL raccourcie (ex: spotify.link, deezer.page.link)
  static Future<String> _expandShortLink(String url) async {
    try {
      final client = http.Client();
      final req = http.Request('HEAD', Uri.parse(url))..followRedirects = true;
      final streamed = await client.send(req).timeout(const Duration(seconds: 4));
      return streamed.headers['location'] ?? streamed.request?.url.toString() ?? url;
    } catch (_) {
      try {
        final res = await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
        return res.request?.url.toString() ?? url;
      } catch (_) {
        return url;
      }
    }
  }

  /// Vérifie si l'URL correspond à un lien de playlist (Spotify, Deezer, Apple Music)
  static bool isPlaylistLink(String text) {
    final t = text.trim().toLowerCase();
    return t.contains('spotify.com/playlist') ||
        t.contains('spotify:playlist') ||
        t.contains('spotify.link') ||
        t.contains('deezer.com/playlist') ||
        t.contains('deezer.com/fr/playlist') ||
        t.contains('deezer.page.link') ||
        (t.contains('music.apple.com') && t.contains('/playlist'));
  }

  /// Résout un lien de playlist en un objet Playlist complet avec ses morceaux
  static Future<Playlist?> resolvePlaylistLink(String link) async {
    var t = link.trim();
    if (!isPlaylistLink(t)) return null;

    try {
      // Développer les liens raccourcis si nécessaire
      if (t.contains('spotify.link') || t.contains('deezer.page.link')) {
        t = await _expandShortLink(t);
      }

      // A. Playlist Deezer (ex: https://www.deezer.com/fr/playlist/11600183624)
      final dzMatch = RegExp(r'playlist/(\d+)').firstMatch(t);
      if (dzMatch != null && (t.contains('deezer.com') || t.contains('deezer.page.link'))) {
        final dzId = dzMatch.group(1)!;
        final pl = await DeezerService().getPlaylist(dzId);
        if (pl != null) return pl;
      }

      // B. Serveur CJ Music Resolver (si implémenté /api/resolve)
      try {
        final serverUrl = Uri.parse('https://music.corentinjanin.fr/api/resolve?url=${Uri.encodeComponent(t)}');
        final res = await http.get(serverUrl).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          if (data['status'] == 'success' && data['resolved_type'] == 'playlist') {
            final tracks = (data['tracks'] as List?)?.map((tr) => Song.fromJson(tr as Map<String, dynamic>)).toList() ?? [];
            final totalDuration = (data['duration'] as num?)?.toInt() ??
                tracks.fold<int>(0, (sum, s) => sum + (s.duration ?? 0));
            return Playlist(
              id: data['id']?.toString() ?? 'ext_pl_${DateTime.now().millisecondsSinceEpoch}',
              name: data['title'] ?? 'Playlist',
              owner: data['artist'] ?? data['owner'] ?? 'Import',
              coverArt: data['cover_url']?.toString(),
              songCount: tracks.length,
              duration: totalDuration,
              songs: tracks,
              public: true,
            );
          }
        }
      } catch (_) {}

      // C. Spotify Playlist Embed Scraper (ex: https://open.spotify.com/playlist/...)
      if (t.contains('spotify.com/playlist/') || t.contains('spotify:playlist:')) {
        final spMatch = RegExp(r'playlist[/:]+([a-zA-Z0-9]+)').firstMatch(t);
        if (spMatch != null) {
          final spId = spMatch.group(1)!;
          final embedUrl = Uri.parse('https://open.spotify.com/embed/playlist/$spId');
          final sRes = await http.get(embedUrl, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
          if (sRes.statusCode == 200) {
            final html = sRes.body;

            // Extraire la cover officielle depuis le HTML ou OpenGraph
            String? plCover;
            final ogMatch = RegExp(r'<meta property="og:image"\s+content="([^"]+)"', caseSensitive: false).firstMatch(html) ??
                RegExp(r'<meta content="([^"]+)"\s+property="og:image"', caseSensitive: false).firstMatch(html);
            if (ogMatch != null) {
              plCover = ogMatch.group(1);
            }

            final scripts = RegExp(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true).firstMatch(html);
            if (scripts != null) {
              final jsonStr = scripts.group(1)!;
              final data = jsonDecode(jsonStr) as Map<String, dynamic>;
              final entity = data['props']?['pageProps']?['state']?['data']?['entity'] as Map<String, dynamic>?;
              if (entity != null) {
                final plName = entity['name']?.toString() ?? 'Playlist Spotify';
                plCover ??= (entity['visualIdentity']?['image'] as List?)?.first?['url']?.toString() ??
                    (entity['images'] as List?)?.first?['url']?.toString() ??
                    (entity['coverArt']?['sources'] as List?)?.first?['url']?.toString();

                final rawTracks = (entity['trackList'] as List?) ?? [];

                // Convertir les morceaux en parallèle via Future.wait pour une vitesse instantanée
                final tracksToResolve = rawTracks.take(35).toList();
                final songFutures = tracksToResolve.map((rt) async {
                  final title = rt['title']?.toString() ?? '';
                  final artistsList = (rt['artists'] as List?)
                          ?.map((a) => a['name']?.toString() ?? '')
                          .where((n) => n.isNotEmpty)
                          .toList() ??
                      [];
                  final artist = artistsList.isNotEmpty ? artistsList.first : '';
                  if (title.isEmpty) return null;
                  try {
                    final query = artist.isNotEmpty ? '$title $artist' : title;
                    final found = await DeezerService().searchTracks(query, limit: 1);
                    if (found.isNotEmpty) return found.first;
                  } catch (_) {}
                  return null;
                });

                final resolvedTracks = (await Future.wait(songFutures)).whereType<Song>().toList();
                final totalDuration = resolvedTracks.fold<int>(0, (sum, s) => sum + (s.duration ?? 0));

                return Playlist(
                  id: 'ext_sp_pl_$spId',
                  name: plName,
                  owner: 'Spotify',
                  songCount: resolvedTracks.length,
                  coverArt: plCover ?? (resolvedTracks.isNotEmpty ? resolvedTracks.first.coverArt : null),
                  duration: totalDuration,
                  songs: resolvedTracks,
                  public: true,
                );
              }
            }
          }
        }
      }

      // D. Apple Music Playlist Scraper (ex: https://music.apple.com/.../playlist/...)
      if (t.contains('music.apple.com') && t.contains('/playlist/')) {
        try {
          final aRes = await http.get(Uri.parse(t), headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          }).timeout(const Duration(seconds: 4));
          if (aRes.statusCode == 200) {
            final html = aRes.body;
            final ogImg = RegExp(r'<meta property="og:image"\s+content="([^"]+)"', caseSensitive: false).firstMatch(html) ??
                RegExp(r'<meta content="([^"]+)"\s+property="og:image"', caseSensitive: false).firstMatch(html);
            final plCover = ogImg?.group(1);

            final ogTitle = RegExp(r'<meta property="og:title"\s+content="([^"]+)"', caseSensitive: false).firstMatch(html) ??
                RegExp(r'<meta content="([^"]+)"\s+property="og:title"', caseSensitive: false).firstMatch(html);
            final title = ogTitle?.group(1)?.replaceAll(' - Apple Music', '').replaceAll(' - Playlist sur Apple Music', '') ?? 'Playlist Apple Music';

            final ldMatches = RegExp(r'<script type="application/ld\+json"[^>]*>(.*?)</script>', dotAll: true).allMatches(html);
            List<dynamic> rawTracks = [];
            for (final m in ldMatches) {
              try {
                final json = jsonDecode(m.group(1)!);
                if (json is Map && (json['@type'] == 'MusicPlaylist' || json['track'] != null)) {
                  rawTracks = (json['track'] as List?) ?? [];
                  break;
                }
              } catch (_) {}
            }

            final tracksToResolve = rawTracks.take(35).toList();
            final songFutures = tracksToResolve.map((tr) async {
              final trackName = tr['name']?.toString() ?? '';
              final artistName = tr['byArtist']?['name']?.toString() ?? '';
              if (trackName.isEmpty) return null;
              try {
                final query = artistName.isNotEmpty ? '$trackName $artistName' : trackName;
                final found = await DeezerService().searchTracks(query, limit: 1);
                if (found.isNotEmpty) return found.first;
              } catch (_) {}
              return null;
            });

            final resolvedTracks = (await Future.wait(songFutures)).whereType<Song>().toList();
            final totalDuration = resolvedTracks.fold<int>(0, (sum, s) => sum + (s.duration ?? 0));

            return Playlist(
              id: 'ext_am_pl_${DateTime.now().millisecondsSinceEpoch}',
              name: title,
              owner: 'Apple Music',
              songCount: resolvedTracks.length,
              coverArt: plCover ?? (resolvedTracks.isNotEmpty ? resolvedTracks.first.coverArt : null),
              duration: totalDuration,
              songs: resolvedTracks,
              public: true,
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[LinkResolverService] Erreur resolvePlaylistLink: $e');
    }
    return null;
  }

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
