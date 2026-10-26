import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'library_database_service.dart';
import 'ytdlp_service.dart';

enum PlaylistImportSource {
  spotify,
  youtubeMusic,
  deezer,
  unknown,
}

class _YtMusicCandidate {
  final String id;
  final int? durationSeconds;
  final String? thumbnailUrl;

  const _YtMusicCandidate({
    required this.id,
    this.durationSeconds,
    this.thumbnailUrl,
  });
}

class PlaylistImportTrack {
  final String title;
  final String artist;
  final String? album;
  final int? duration;
  final String? coverArt;
  final String? youtubeVideoId;
  final String? spotifyUri;

  const PlaylistImportTrack({
    required this.title,
    required this.artist,
    this.album,
    this.duration,
    this.coverArt,
    this.youtubeVideoId,
    this.spotifyUri,
  });

  PlaylistImportTrack copyWith({
    String? title,
    String? artist,
    String? album,
    int? duration,
    String? coverArt,
    String? youtubeVideoId,
    String? spotifyUri,
  }) {
    return PlaylistImportTrack(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      coverArt: coverArt ?? this.coverArt,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      spotifyUri: spotifyUri ?? this.spotifyUri,
    );
  }
}

class PlaylistImportPreview {
  final PlaylistImportSource source;
  final String id;
  final String title;
  final String? author;
  final String? coverArtUrl;
  final List<PlaylistImportTrack> tracks;

  const PlaylistImportPreview({
    required this.source,
    required this.id,
    required this.title,
    this.author,
    this.coverArtUrl,
    required this.tracks,
  });

  int get totalTracks => tracks.length;
}

class PlaylistImportService {
  static final PlaylistImportService _instance =
      PlaylistImportService._internal();
  factory PlaylistImportService() => _instance;
  PlaylistImportService._internal();

  final LibraryDatabaseService _db = LibraryDatabaseService();
  final YtDlpService _ytdlp = YtDlpService();

  static HttpClient? _sharedClient;
  static HttpClient get _client {
    _sharedClient ??= HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 30);
    return _sharedClient!;
  }

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static String? _normalizeThumbnailUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.contains('googleusercontent.com') || url.contains('ggpht.com')) {
      final base = url.split('=')[0];
      return '$base=w800-h800-l90-rj';
    }
    if (url.contains('i.ytimg.com') || url.contains('img.youtube.com')) {
      final match = RegExp(r'/vi/([a-zA-Z0-9_-]{11})').firstMatch(url);
      if (match != null) {
        return 'https://i.ytimg.com/vi/${match.group(1)}/hq720.jpg';
      }
    }
    return url;
  }

  PlaylistImportSource detectSource(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('spotify.com') || trimmed.startsWith('spotify:')) {
      return PlaylistImportSource.spotify;
    }
    if (trimmed.contains('deezer.com') || trimmed.contains('deezer.page.link')) {
      return PlaylistImportSource.deezer;
    }
    if (trimmed.contains('youtube.com') ||
        trimmed.contains('youtu.be') ||
        trimmed.startsWith('PL') ||
        trimmed.startsWith('VLPL') ||
        trimmed.startsWith('RD') ||
        trimmed.startsWith('OLAK5uy_')) {
      return PlaylistImportSource.youtubeMusic;
    }
    if (RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(trimmed)) {
      return PlaylistImportSource.spotify;
    }
    return PlaylistImportSource.unknown;
  }

  String? extractSpotifyId(String input) {
    final trimmed = input.trim();
    final match = RegExp(r'(?:playlist[/:]|embed/playlist/|^)([a-zA-Z0-9]{22})')
        .firstMatch(trimmed);
    return match?.group(1);
  }

  String? extractYouTubePlaylistId(String input) {
    final trimmed = input.trim();
    final match = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)').firstMatch(trimmed);
    if (match != null) {
      var id = match.group(1)!;
      if (id.startsWith('VLPL')) id = id.substring(2);
      return id;
    }
    if (trimmed.startsWith('VLPL')) return trimmed.substring(2);
    if (RegExp(r'^[a-zA-Z0-9_-]{10,}$').hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }

  String? extractDeezerId(String input) {
    final match = RegExp(r'playlist/([0-9]+)').firstMatch(input.trim());
    if (match != null) return match.group(1);
    if (RegExp(r'^[0-9]+$').hasMatch(input.trim())) return input.trim();
    return null;
  }

  Future<PlaylistImportPreview> fetchPreview(String input) async {
    final source = detectSource(input);
    switch (source) {
      case PlaylistImportSource.spotify:
        return fetchSpotifyPreview(input);
      case PlaylistImportSource.deezer:
        return fetchDeezerPreview(input);
      case PlaylistImportSource.youtubeMusic:
        return fetchYouTubeMusicPreview(input);
      case PlaylistImportSource.unknown:
        try {
          return await fetchSpotifyPreview(input);
        } catch (_) {
          try {
            return await fetchDeezerPreview(input);
          } catch (_) {
            return await fetchYouTubeMusicPreview(input);
          }
        }
    }
  }

  Future<PlaylistImportPreview> fetchDeezerPreview(String input) async {
    final id = extractDeezerId(input);
    if (id == null) {
      throw Exception('Lien ou identifiant de playlist Deezer non valide');
    }
    final url = Uri.parse('https://api.deezer.com/playlist/$id');
    final req = await _client.getUrl(url);
    final response = await req.close();
    final body = await response.transform(utf8.decoder).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    if (data.containsKey('error')) {
      throw Exception('Playlist Deezer introuvable ou privée');
    }

    final tracksList = (data['tracks']?['data'] as List?) ?? [];
    final tracks = tracksList.map((t) {
      final artistData = t['artist'] as Map<String, dynamic>?;
      final albumData = t['album'] as Map<String, dynamic>?;
      return PlaylistImportTrack(
        title: t['title'] ?? '',
        artist: artistData?['name'] ?? 'Artiste inconnu',
        album: albumData?['title'],
        duration: (t['duration'] as num?)?.toInt(),
        coverArt: albumData?['cover_xl'] ?? albumData?['cover_big'],
      );
    }).toList();

    return PlaylistImportPreview(
      source: PlaylistImportSource.deezer,
      id: id,
      title: data['title'] ?? 'Playlist Deezer',
      author: data['creator']?['name'],
      coverArtUrl: data['picture_xl'] ?? data['picture_big'],
      tracks: tracks,
    );
  }

  Future<PlaylistImportPreview> fetchSpotifyPreview(String input) async {
    final id = extractSpotifyId(input);
    if (id == null) {
      throw Exception('Link o ID playlist Spotify non valido');
    }

    final uri = Uri.parse('https://open.spotify.com/embed/playlist/$id');
    final req = await _client.getUrl(uri);
    req.headers.set('User-Agent', _defaultUserAgent);
    final res = await req.close();
    if (res.statusCode != 200) {
      throw Exception(
          'Impossibile caricare la playlist da Spotify (HTTP ${res.statusCode})');
    }

    final body = await res.transform(utf8.decoder).join();
    final match = RegExp(
            r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>')
        .firstMatch(body);
    if (match == null) {
      throw Exception('Dati della playlist Spotify non trovati');
    }

    final jsonStr = match.group(1)!;
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final entity = data['props']?['pageProps']?['state']?['data']?['entity']
        as Map<String, dynamic>?;
    if (entity == null) {
      throw Exception('Playlist non trovata su Spotify');
    }

    final title = entity['name'] as String? ?? 'Spotify Playlist';
    final author = entity['subtitle'] as String? ?? 'Spotify';

    String? coverArtUrl;
    final images = entity['visualIdentity']?['image'] as List<dynamic>?;
    if (images != null && images.isNotEmpty) {
      final last = images.last as Map<String, dynamic>;
      coverArtUrl = last['url'] as String?;
    }

    final rawTracks = entity['trackList'] as List<dynamic>? ?? [];
    final tracks = <PlaylistImportTrack>[];

    for (final raw in rawTracks) {
      if (raw is! Map<String, dynamic>) continue;
      final trackTitle = raw['title'] as String? ?? 'Unknown';
      final trackArtist = raw['subtitle'] as String? ?? 'Unknown Artist';
      final durMs = raw['duration'] as int?;
      final duration = durMs != null ? durMs ~/ 1000 : null;
      final uri = raw['uri'] as String?;

      tracks.add(PlaylistImportTrack(
        title: trackTitle,
        artist: trackArtist,
        album: title,
        duration: duration,
        coverArt: coverArtUrl,
        spotifyUri: uri,
      ));
    }

    if (tracks.isEmpty) {
      throw Exception('La playlist Spotify non contiene brani');
    }

    return PlaylistImportPreview(
      source: PlaylistImportSource.spotify,
      id: id,
      title: title,
      author: author,
      coverArtUrl: coverArtUrl,
      tracks: tracks,
    );
  }

  Future<PlaylistImportPreview> fetchYouTubeMusicPreview(String input) async {
    final playlistId = extractYouTubePlaylistId(input);
    if (playlistId == null) {
      throw Exception('Link o ID playlist YouTube Music non valido');
    }

    try {
      final browsePreview = await _fetchYouTubeMusicViaBrowse(playlistId);
      if (browsePreview.tracks.isNotEmpty) {
        return browsePreview;
      }
    } catch (e) {
      debugPrint('[PlaylistImport] Browse error: $e, falling back to yt-dlp');
    }

    try {
      final rawItems = await _ytdlp.getPlaylistVideos(playlistId);
      if (rawItems.isNotEmpty) {
        final tracks = rawItems.map((item) {
          final id = item['id'] as String;
          var thumb = item['thumbnailUrl'] as String?;
          if (thumb != null &&
              (thumb.contains('googleusercontent.com') ||
                  thumb.contains('ggpht.com'))) {
            thumb = '${thumb.split('=')[0]}=w800-h800-l90-rj';
          }
          return PlaylistImportTrack(
            title: item['title'] as String? ?? 'Unknown Title',
            artist: item['artist'] as String? ?? 'Unknown Artist',
            album: item['album'] as String?,
            duration: item['duration'] as int?,
            coverArt: thumb ?? 'https://i.ytimg.com/vi/$id/hq720.jpg',
            youtubeVideoId: id,
          );
        }).toList();

        return PlaylistImportPreview(
          source: PlaylistImportSource.youtubeMusic,
          id: playlistId,
          title: 'YouTube Playlist',
          author: 'YouTube Music',
          coverArtUrl: tracks.isNotEmpty ? tracks.first.coverArt : null,
          tracks: tracks,
        );
      }
    } catch (e) {
      debugPrint('[PlaylistImport] YtDlp error: $e');
    }

    throw Exception(
        'Impossibile recuperare i brani della playlist da YouTube Music');
  }

  Future<PlaylistImportPreview> _fetchYouTubeMusicViaBrowse(
      String playlistId) async {
    final browseId = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
    final uri = Uri.parse('https://music.youtube.com/youtubei/v1/browse');
    final req = await _client.postUrl(uri);
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('User-Agent', _defaultUserAgent);

    final payload = {
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20240101.01.00',
          'hl': 'en',
          'gl': 'US',
        }
      },
      'browseId': browseId,
    };

    req.add(utf8.encode(jsonEncode(payload)));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    String? playlistTitle;
    String? playlistAuthor;
    String? playlistCover;

    void findHeader(dynamic obj) {
      if (obj is Map) {
        if (obj.containsKey('musicResponsiveHeaderRenderer')) {
          final h =
              obj['musicResponsiveHeaderRenderer'] as Map<String, dynamic>;
          playlistTitle = h['title']?['runs']?[0]?['text'];
          playlistAuthor = h['straplineTextOne']?['runs']?[0]?['text'];
          final thumbs = h['thumbnail']?['musicThumbnailRenderer']?['thumbnail']
              ?['thumbnails'] as List?;
          if (thumbs != null && thumbs.isNotEmpty) {
            playlistCover =
                _normalizeThumbnailUrl(thumbs.last['url'] as String?);
          }
          return;
        }
        for (final v in obj.values) {
          findHeader(v);
        }
      } else if (obj is List) {
        for (final e in obj) {
          findHeader(e);
        }
      }
    }

    findHeader(data);

    final tracks = <PlaylistImportTrack>[];
    void findTracks(dynamic obj) {
      if (obj is Map) {
        if (obj.containsKey('musicResponsiveListItemRenderer')) {
          final item =
              obj['musicResponsiveListItemRenderer'] as Map<String, dynamic>;
          final videoId = item['playlistItemData']?['videoId'] ??
              item['overlay']?['musicItemThumbnailOverlayRenderer']?['content']
                      ?['musicPlayButtonRenderer']?['playNavigationEndpoint']
                  ?['watchEndpoint']?['videoId'];

          if (videoId != null && videoId.toString().length == 11) {
            final flexCols = item['flexColumns'] as List? ?? [];
            String title = 'Unknown Title';
            String artist = 'Unknown Artist';
            String? album;
            int? duration;

            if (flexCols.isNotEmpty) {
              final r0 = flexCols[0]
                      ['musicResponsiveListItemFlexColumnRenderer']?['text']
                  ?['runs'] as List?;
              if (r0 != null && r0.isNotEmpty) title = r0[0]['text'] ?? title;
            }
            if (flexCols.length > 1) {
              final r1 = flexCols[1]
                      ['musicResponsiveListItemFlexColumnRenderer']?['text']
                  ?['runs'] as List?;
              if (r1 != null && r1.isNotEmpty) artist = r1[0]['text'] ?? artist;
            }

            final fixedCols = item['fixedColumns'] as List? ?? [];
            if (fixedCols.isNotEmpty) {
              final durRuns = fixedCols[0]
                      ['musicResponsiveListItemFixedColumnRenderer']?['text']
                  ?['runs'] as List?;
              if (durRuns != null && durRuns.isNotEmpty) {
                final durStr = durRuns[0]['text'] as String?;
                if (durStr != null && durStr.contains(':')) {
                  final parts = durStr.split(':');
                  if (parts.length == 2) {
                    duration = (int.tryParse(parts[0]) ?? 0) * 60 +
                        (int.tryParse(parts[1]) ?? 0);
                  }
                }
              }
            }

            String? thumb;
            final thumbs = item['thumbnail']?['musicThumbnailRenderer']
                ?['thumbnail']?['thumbnails'] as List?;
            if (thumbs != null && thumbs.isNotEmpty) {
              thumb = _normalizeThumbnailUrl(thumbs.last['url'] as String?);
            }

            tracks.add(PlaylistImportTrack(
              title: title,
              artist: artist,
              album: album ?? playlistTitle,
              duration: duration,
              coverArt: thumb ??
                  playlistCover ??
                  'https://i.ytimg.com/vi/$videoId/hq720.jpg',
              youtubeVideoId: videoId.toString(),
            ));
          }
          return;
        }
        for (final v in obj.values) {
          findTracks(v);
        }
      } else if (obj is List) {
        for (final e in obj) {
          findTracks(e);
        }
      }
    }

    findTracks(data);

    return PlaylistImportPreview(
      source: PlaylistImportSource.youtubeMusic,
      id: playlistId,
      title: playlistTitle ?? 'YouTube Music Playlist',
      author: playlistAuthor,
      coverArtUrl: playlistCover,
      tracks: tracks,
    );
  }

  Future<({String videoId, String? coverArt})?>
      matchSpotifyTrackToYouTubeDetails(
    String title,
    String artist, {
    int? duration,
  }) async {
    // 1. Clean query removing noisy suffixes often present in metadata
    final cleanTitle = title
        .replaceAll(
            RegExp(r'\s*\([^)]*(feat\.|ft\.|remaster|deluxe|version)[^)]*\)',
                caseSensitive: false),
            '')
        .replaceAll(
            RegExp(r'\s*\[[^\]]*(feat\.|ft\.|remaster|deluxe|version)[^\]]*\]',
                caseSensitive: false),
            '')
        .trim();
    final cleanArtist = artist.split(',').first.split('&').first.trim();

    final queriesToTry = [
      '$cleanArtist $cleanTitle'.trim(),
      if (cleanTitle != title || cleanArtist != artist) '$artist $title'.trim(),
      cleanTitle,
    ];

    for (final query in queriesToTry) {
      if (query.isEmpty) continue;
      final candidate =
          await _queryYouTubeMusicCandidate(query, targetDuration: duration);
      if (candidate != null) {
        return (videoId: candidate.id, coverArt: candidate.thumbnailUrl);
      }
    }

    return null;
  }

  Future<String?> matchSpotifyTrackToYouTube(
    String title,
    String artist, {
    int? duration,
  }) async {
    final details = await matchSpotifyTrackToYouTubeDetails(title, artist,
        duration: duration);
    return details?.videoId;
  }

  Future<_YtMusicCandidate?> _queryYouTubeMusicCandidate(
    String query, {
    int? targetDuration,
  }) async {
    try {
      final uri = Uri.parse(
          'https://music.youtube.com/youtubei/v1/search?prettyPrint=false');
      final req = await _client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('User-Agent', _defaultUserAgent);
      req.headers.set('Origin', 'https://music.youtube.com');
      req.headers.set('Referer', 'https://music.youtube.com/');

      // Official YouTube Music filter param for 'Songs' category
      final payload = {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240101.01.00',
            'hl': 'en',
            'gl': 'US',
          }
        },
        'query': query,
        'params': 'EgWKAQIIAWoKEAUQAxAEEAkQBQ==',
      };

      req.add(utf8.encode(jsonEncode(payload)));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final candidates = <_YtMusicCandidate>[];

      void extractCandidates(dynamic obj) {
        if (obj is Map) {
          if (obj.containsKey('musicResponsiveListItemRenderer')) {
            final item =
                obj['musicResponsiveListItemRenderer'] as Map<String, dynamic>;
            final videoId = item['playlistItemData']?['videoId'] ??
                item['overlay']?['musicItemThumbnailOverlayRenderer']
                        ?['content']?['musicPlayButtonRenderer']
                    ?['playNavigationEndpoint']?['watchEndpoint']?['videoId'];

            if (videoId != null && videoId.toString().length == 11) {
              int? candDuration;
              final fixedCols = item['fixedColumns'] as List? ?? [];
              if (fixedCols.isNotEmpty) {
                final durRuns = fixedCols[0]
                        ['musicResponsiveListItemFixedColumnRenderer']?['text']
                    ?['runs'] as List?;
                if (durRuns != null && durRuns.isNotEmpty) {
                  final durStr = durRuns[0]['text'] as String?;
                  if (durStr != null && durStr.contains(':')) {
                    final parts = durStr.split(':');
                    if (parts.length == 2) {
                      candDuration = (int.tryParse(parts[0]) ?? 0) * 60 +
                          (int.tryParse(parts[1]) ?? 0);
                    } else if (parts.length == 3) {
                      candDuration = (int.tryParse(parts[0]) ?? 0) * 3600 +
                          (int.tryParse(parts[1]) ?? 0) * 60 +
                          (int.tryParse(parts[2]) ?? 0);
                    }
                  }
                }
              }

              String? thumb;
              final thumbs = item['thumbnail']?['musicThumbnailRenderer']
                  ?['thumbnail']?['thumbnails'] as List?;
              if (thumbs != null && thumbs.isNotEmpty) {
                thumb = _normalizeThumbnailUrl(thumbs.last['url'] as String?);
              }

              candidates.add(_YtMusicCandidate(
                id: videoId.toString(),
                durationSeconds: candDuration,
                thumbnailUrl: thumb,
              ));
            }
          }
          for (final v in obj.values) {
            extractCandidates(v);
          }
        } else if (obj is List) {
          for (final e in obj) {
            extractCandidates(e);
          }
        }
      }

      extractCandidates(data);

      if (candidates.isEmpty) return null;

      // If targetDuration is available, find the closest matching candidate
      if (targetDuration != null && targetDuration > 0) {
        _YtMusicCandidate? bestCandidate;
        int minDiff = 999999;
        for (final cand in candidates) {
          if (cand.durationSeconds != null) {
            final diff = (cand.durationSeconds! - targetDuration).abs();
            if (diff < minDiff) {
              minDiff = diff;
              bestCandidate = cand;
            }
          }
        }
        // If the closest candidate is within 15 seconds, pick it
        if (bestCandidate != null && minDiff <= 15) {
          return bestCandidate;
        }
      }

      // Default to the first official Song result from YouTube Music
      return candidates.first;
    } catch (e) {
      debugPrint('[PlaylistImport] YouTube Music search error: $e');
      return null;
    }
  }

  Future<Playlist> importFromPreview(
    PlaylistImportPreview preview, {
    String? customName,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    final total = preview.tracks.length;
    final finalName = (customName != null && customName.trim().isNotEmpty)
        ? customName.trim()
        : preview.title;

    final List<Song> resolvedSongs = [];

    if (preview.source == PlaylistImportSource.youtubeMusic) {
      onProgress?.call(0, total, 'Salvataggio brani in corso...');
      for (var i = 0; i < preview.tracks.length; i++) {
        final t = preview.tracks[i];
        final songId = t.youtubeVideoId ?? const Uuid().v4();
        resolvedSongs.add(Song(
          id: songId,
          title: t.title,
          artist: t.artist,
          album: t.album ?? finalName,
          duration: t.duration,
          coverArt: _normalizeThumbnailUrl(t.coverArt) ??
              _normalizeThumbnailUrl(preview.coverArtUrl) ??
              'https://i.ytimg.com/vi/$songId/hq720.jpg',
        ));
        onProgress?.call(i + 1, total, 'Aggiunto: ${t.title}');
      }
    } else {
      onProgress?.call(0, total, 'Inizio corrispondenza tracce...');

      const concurrency = 4;
      var processed = 0;

      for (var i = 0; i < preview.tracks.length; i += concurrency) {
        final end = (i + concurrency < preview.tracks.length)
            ? i + concurrency
            : preview.tracks.length;
        final batch = preview.tracks.sublist(i, end);

        final batchResults = await Future.wait(batch.map((track) async {
          String? vid = track.youtubeVideoId;
          String? matchedCover;
          if (vid == null || vid.isEmpty) {
            final match = await matchSpotifyTrackToYouTubeDetails(
              track.title,
              track.artist,
              duration: track.duration,
            );
            vid = match?.videoId;
            matchedCover = match?.coverArt;
          }
          final effectiveId = vid ??
              'ytsearch:${Uri.encodeComponent('${track.artist} ${track.title}')}';

          final effectiveCover = _normalizeThumbnailUrl(matchedCover) ??
              _normalizeThumbnailUrl(track.coverArt) ??
              _normalizeThumbnailUrl(preview.coverArtUrl) ??
              (effectiveId.length == 11 && !effectiveId.contains(':')
                  ? 'https://i.ytimg.com/vi/$effectiveId/hq720.jpg'
                  : null);

          return Song(
            id: effectiveId,
            title: track.title,
            artist: track.artist,
            album: track.album ?? finalName,
            duration: track.duration,
            coverArt: effectiveCover,
          );
        }));

        resolvedSongs.addAll(batchResults);
        processed += batch.length;
        final lastTrack = batch.last;
        onProgress?.call(
          processed,
          total,
          'Corrispondenza ($processed/$total): ${lastTrack.title}',
        );
      }
    }

    await _db.insertSongsBatch(resolvedSongs);

    final newPlaylistId = const Uuid().v4();
    final firstCover = resolvedSongs.isNotEmpty
        ? resolvedSongs.first.coverArt
        : preview.coverArtUrl;

    final newPlaylist = Playlist(
      id: newPlaylistId,
      name: finalName,
      comment: preview.source == PlaylistImportSource.spotify
          ? 'Imported from Spotify'
          : 'Imported from YouTube Music',
      owner: 'Web Stream',
      songCount: resolvedSongs.length,
      created: DateTime.now(),
      changed: DateTime.now(),
      coverArt: preview.coverArtUrl ?? firstCover,
      songs: resolvedSongs,
    );

    await _db.insertOrUpdatePlaylist(newPlaylist);
    debugPrint(
        '[PlaylistImport] Created playlist "$finalName" with ${resolvedSongs.length} songs');

    return newPlaylist;
  }

  Future<Playlist> importFromUrl(
    String urlOrId, {
    String? customName,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    onProgress?.call(0, 0, 'Caricamento anteprima playlist...');
    final preview = await fetchPreview(urlOrId);
    return importFromPreview(
      preview,
      customName: customName,
      onProgress: onProgress,
    );
  }

  /// Importation directe haute fidélité via l'API CJ Resolver sur notre serveur
  /// POST https://music.corentinjanin.fr/api/music/playlist/import
  Future<Playlist> importToServer({
    required String sourceUrl,
    required String username,
    required String password,
    String? customName,
  }) async {
    final client = HttpClient()..badCertificateCallback = (cert, host, port) => true;
    try {
      final request = await client.postUrl(
        Uri.parse('https://music.corentinjanin.fr/api/music/playlist/import'),
      );
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({
        'source': sourceUrl,
        'user': username,
        'password': password,
      }));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['status'] == 'success') {
        final subsonicId = json['subsonic_id']?.toString() ?? '';
        final name = customName ?? (json['playlist_name']?.toString() ?? 'Playlist importée');
        final totalTracks = (json['total_tracks'] as num?)?.toInt() ?? 0;
        return Playlist(
          id: subsonicId.isNotEmpty ? subsonicId : const Uuid().v4(),
          name: name,
          songCount: totalTracks,
          created: DateTime.now(),
          changed: DateTime.now(),
        );
      } else {
        throw Exception(json['detail'] ?? json['message'] ?? 'Erreur lors de l\'importation');
      }
    } finally {
      client.close();
    }
  }
}
