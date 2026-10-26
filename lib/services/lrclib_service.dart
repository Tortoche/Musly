import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'storage_service.dart';
import 'genius_lyrics_service.dart';

class LrcLibService {
  static final LrcLibService _instance = LrcLibService._internal();
  factory LrcLibService() => _instance;
  LrcLibService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://lrclib.net/api',
      connectTimeout: const Duration(seconds: 7),
      receiveTimeout: const Duration(seconds: 7),
      headers: {
        'User-Agent': 'Musly/1.2.0 (https://github.com/musly)',
      },
    ),
  );

  final Map<String, Map<String, dynamic>> _cache = {};

  static final List<RegExp> _noiseRegexes = [
    RegExp(
      r'\((?:official|music|video|audio|lyrics?|lyric video|visualizer|hd|4k|remastered|live|explicit|clip|video oficial|clip officiel|deluxe|version originale).*?\)',
      caseSensitive: false,
    ),
    RegExp(
      r'\[(?:official|music|video|audio|lyrics?|lyric video|visualizer|hd|4k|remastered|live|explicit|clip|video oficial|clip officiel|deluxe|version originale).*?\]',
      caseSensitive: false,
    ),
    RegExp(r'\((?:feat\.|ft\.|featuring).*?\)', caseSensitive: false),
    RegExp(r'\[(?:feat\.|ft\.|featuring).*?\]', caseSensitive: false),
    RegExp(r'(?:feat\.|ft\.|featuring)\s+.*$', caseSensitive: false),
    RegExp(r'\((?:prod\.|produced by).*?\)', caseSensitive: false),
    RegExp(r'\[(?:prod\.|produced by).*?\]', caseSensitive: false),
    RegExp(r'\s+with\s+.*$', caseSensitive: false),
  ];

  static final RegExp _multiSpaceRegex = RegExp(r'\s+');
  static final RegExp _topicRegex =
      RegExp(r'\s*-\s*Topic$', caseSensitive: false);
  static final RegExp _vevoRegex = RegExp(r'\s*VEVO$', caseSensitive: false);
  static final RegExp _officialRegex =
      RegExp(r'\s*Official$', caseSensitive: false);

  /// Strips accents/diacritics from strings to maximize search hits
  static String stripAccents(String input) {
    const accents = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÌÍÎÏìíîïÙÚÛÜùúûüÿÑñÇç';
    const clean   = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeIIIIiiiiUUUUuuuuyNnCc';
    var result = input;
    for (var i = 0; i < accents.length; i++) {
      result = result.replaceAll(accents[i], clean[i]);
    }
    return result;
  }

  static String cleanTitle(String rawTitle, [String? knownArtist]) {
    var title = rawTitle;

    // Handle "Artist - Title" or "Title - Remix"
    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      if (knownArtist != null && knownArtist.isNotEmpty) {
        final artistLower = knownArtist.trim().toLowerCase();
        final firstPartLower = parts[0].trim().toLowerCase();
        if (firstPartLower == artistLower || artistLower.contains(firstPartLower)) {
          title = parts.sublist(1).join(' - ');
        } else {
          final lastPartLower = parts.last.trim().toLowerCase();
          const noiseWords = [
            'remix', 'radio edit', 'live', 'remaster', 'bonus', 'deluxe',
            'version', 'acoustic', 'edit', 'clip', 'orchestral'
          ];
          if (noiseWords.any((w) => lastPartLower.contains(w))) {
            title = parts.sublist(0, parts.length - 1).join(' - ');
          }
        }
      } else {
        // Without known artist, check if last part is noise
        final lastPartLower = parts.last.trim().toLowerCase();
        const noiseWords = [
          'remix', 'radio edit', 'live', 'remaster', 'bonus', 'deluxe',
          'version', 'acoustic', 'edit', 'clip', 'orchestral'
        ];
        if (noiseWords.any((w) => lastPartLower.contains(w))) {
          title = parts.sublist(0, parts.length - 1).join(' - ');
        }
      }
    }

    for (final reg in _noiseRegexes) {
      title = title.replaceAll(reg, ' ');
    }

    title = title
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('`', '')
        .replaceAll('’', '')
        .replaceAll(_multiSpaceRegex, ' ')
        .trim();

    return title.isNotEmpty ? title : rawTitle;
  }

  static String cleanArtist(String rawArtist) {
    var artist = rawArtist;
    artist = artist.replaceAll(_topicRegex, '');
    artist = artist.replaceAll(_vevoRegex, '');
    artist = artist.replaceAll(_officialRegex, '');
    return artist.trim().isNotEmpty ? artist.trim() : rawArtist;
  }

  /// Extracts primary artist from "Artist A, Artist B", "Artist A & Artist B", etc.
  static String extractPrimaryArtist(String rawArtist) {
    final cleaned = cleanArtist(rawArtist);
    final separators = RegExp(
      r'\s*(?:feat\.|ft\.|featuring|&|,|/|\bx\b|\bvs\.?\b|\bwith\b)\s*',
      caseSensitive: false,
    );
    final parts = cleaned.split(separators);
    if (parts.isNotEmpty && parts.first.trim().isNotEmpty) {
      return parts.first.trim();
    }
    return cleaned;
  }

  /// Helper with automatic retry on 503 / 429
  Future<Response<T>?> _getWithRetry<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final resp = await _dio.get<T>(path, queryParameters: queryParameters);
        return resp;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (attempt == 0 && (status == 503 || status == 502 || status == 504 || status == 429)) {
          await Future.delayed(const Duration(milliseconds: 350));
          continue;
        }
        return null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> searchLyrics({
    String? artist,
    required String title,
    int? durationSeconds,
  }) async {
    final isEnabled = await StorageService().getLrcLibFallback();
    if (!isEnabled) return null;

    if (title.trim().isEmpty) return null;

    final cleanedTitle = cleanTitle(title, artist);
    final cleanedArtist =
        (artist != null && artist.isNotEmpty) ? cleanArtist(artist) : null;
    final primaryArtist =
        cleanedArtist != null ? extractPrimaryArtist(cleanedArtist) : null;

    final cacheKey =
        '${cleanedArtist?.toLowerCase() ?? ''}|${cleanedTitle.toLowerCase()}';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // 1. TIER 1: Exact matches via LRCLIB /api/get
    final exactCandidates = <MapEntry<String, String>>[];
    if (primaryArtist != null && primaryArtist.isNotEmpty) {
      exactCandidates.add(MapEntry(primaryArtist, cleanedTitle));
    }
    if (cleanedArtist != null &&
        cleanedArtist.isNotEmpty &&
        cleanedArtist != primaryArtist) {
      exactCandidates.add(MapEntry(cleanedArtist, cleanedTitle));
    }

    for (final pair in exactCandidates) {
      // Try with duration first if available
      if (durationSeconds != null && durationSeconds > 0) {
        final resp = await _getWithRetry(
          '/get',
          queryParameters: {
            'artist_name': pair.key,
            'track_name': pair.value,
            'duration': durationSeconds,
          },
        );
        if (resp != null && resp.statusCode == 200 && resp.data is Map) {
          final res = _parseLrcLibResponse(resp.data as Map<String, dynamic>);
          if (res != null) {
            _cache[cacheKey] = res;
            debugPrint('[LRCLIB] Exact match with duration for "${pair.key} - ${pair.value}"');
            return res;
          }
        }
      }

      // Try /get without duration
      final respNoDur = await _getWithRetry(
        '/get',
        queryParameters: {
          'artist_name': pair.key,
          'track_name': pair.value,
        },
      );
      if (respNoDur != null && respNoDur.statusCode == 200 && respNoDur.data is Map) {
        final res = _parseLrcLibResponse(respNoDur.data as Map<String, dynamic>);
        if (res != null) {
          _cache[cacheKey] = res;
          debugPrint('[LRCLIB] Exact match for "${pair.key} - ${pair.value}"');
          return res;
        }
      }
    }

    // 2. TIER 2: LRCLIB /api/search with structured fields (artist_name & track_name)
    if (primaryArtist != null && primaryArtist.isNotEmpty) {
      final searchParams = <Map<String, dynamic>>[
        {'artist_name': primaryArtist, 'track_name': cleanedTitle},
      ];
      if (cleanedArtist != null && cleanedArtist != primaryArtist) {
        searchParams.add({'artist_name': cleanedArtist, 'track_name': cleanedTitle});
      }

      for (final params in searchParams) {
        final resp = await _getWithRetry('/search', queryParameters: params);
        if (resp != null && resp.statusCode == 200 && resp.data is List) {
          final list = resp.data as List;
          if (list.isNotEmpty) {
            final parsed = _findBestInList(list);
            if (parsed != null) {
              _cache[cacheKey] = parsed;
              debugPrint('[LRCLIB] Structured search match for $params');
              return parsed;
            }
          }
        }
      }
    }

    // 3. TIER 3: LRCLIB /api/search with query string
    final searchQueries = <String>[];
    if (primaryArtist != null && primaryArtist.isNotEmpty) {
      searchQueries.add('$primaryArtist $cleanedTitle'.trim());
    }
    if (cleanedArtist != null &&
        cleanedArtist.isNotEmpty &&
        cleanedArtist != primaryArtist) {
      searchQueries.add('$cleanedArtist $cleanedTitle'.trim());
    }
    if (!searchQueries.contains(cleanedTitle)) {
      searchQueries.add(cleanedTitle);
    }

    // Add unaccented query if diacritics are present
    final unaccentedTitle = stripAccents(cleanedTitle);
    final unaccentedArtist = primaryArtist != null ? stripAccents(primaryArtist) : null;
    if (unaccentedArtist != null &&
        (unaccentedTitle != cleanedTitle || unaccentedArtist != primaryArtist)) {
      searchQueries.add('$unaccentedArtist $unaccentedTitle'.trim());
    }

    for (final q in searchQueries) {
      if (q.isEmpty) continue;
      final resp = await _getWithRetry('/search', queryParameters: {'q': q});
      if (resp != null && resp.statusCode == 200 && resp.data is List) {
        final list = resp.data as List;
        if (list.isNotEmpty) {
          final parsed = _findBestInList(list);
          if (parsed != null) {
            _cache[cacheKey] = parsed;
            debugPrint('[LRCLIB] Query match found for "$q"');
            return parsed;
          }
        }
      }
    }

    // 4. TIER 4: Ultimate Multi-Source Fallback via Genius Lyrics
    final geniusArtist = primaryArtist ?? cleanedArtist ?? '';
    if (geniusArtist.isNotEmpty || cleanedTitle.isNotEmpty) {
      try {
        final geniusLyrics = await GeniusLyricsService().searchAndGetLyrics(
          artist: geniusArtist,
          title: cleanedTitle,
        );
        if (geniusLyrics != null && geniusLyrics.trim().isNotEmpty) {
          final res = {'value': geniusLyrics};
          _cache[cacheKey] = res;
          debugPrint('[Genius] Fallback lyrics captured for "$geniusArtist - $cleanedTitle"');
          return res;
        }
      } catch (e) {
        debugPrint('[Genius] Fallback failed: $e');
      }
    }

    return null;
  }

  Map<String, dynamic>? _findBestInList(List list) {
    Map<String, dynamic>? bestMatch;
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final synced = item['syncedLyrics'] as String?;
        final plain = item['plainLyrics'] as String?;
        if (synced != null && synced.trim().isNotEmpty) {
          bestMatch = item;
          break;
        } else if (plain != null &&
            plain.trim().isNotEmpty &&
            bestMatch == null) {
          bestMatch = item;
        }
      }
    }
    bestMatch ??= (list.first is Map<String, dynamic>)
        ? list.first as Map<String, dynamic>
        : null;

    if (bestMatch != null) {
      return _parseLrcLibResponse(bestMatch);
    }
    return null;
  }

  Map<String, dynamic>? _parseLrcLibResponse(Map<String, dynamic> data) {
    final synced = data['syncedLyrics'] as String?;
    if (synced != null && synced.isNotEmpty) {
      return _buildStructuredLyrics(synced);
    }

    final plain = data['plainLyrics'] as String?;
    if (plain != null && plain.isNotEmpty) {
      return {'value': plain};
    }

    return null;
  }

  Map<String, dynamic> _buildStructuredLyrics(String lrcText) {
    final lines = <Map<String, dynamic>>[];
    for (final raw in LineSplitter.split(lrcText)) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final match =
          RegExp(r'\[(\d+):(\d{2})\.(\d{2,3})\](.*)').firstMatch(line);
      if (match == null) continue;

      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fracStr = match.group(3)!;
      final text = match.group(4)!.trim();
      if (text.isEmpty) continue;

      final fracMs =
          fracStr.length == 2 ? int.parse(fracStr) * 10 : int.parse(fracStr);

      final startMs = (minutes * 60 + seconds) * 1000 + fracMs.clamp(0, 999);

      lines.add({
        'start': startMs,
        'value': text,
      });
    }

    if (lines.isEmpty) {
      return {'value': lrcText};
    }

    return {
      'value': lrcText,
      'structuredLyrics': [
        {
          'synced': true,
          'line': lines,
        },
      ],
    };
  }
}
