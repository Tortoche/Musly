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
        'User-Agent': 'Musly/2.0.4 (https://github.com/dddevid/Musly)',
      },
    ),
  );

  final Map<String, Map<String, dynamic>> _cache = {};
  static const int _maxCacheSize = 150;

  void _setCache(String key, Map<String, dynamic> value) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

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

  /// Checks alphanumeric normalized similarity (case, accents and punctuation insensitive)
  static String normalizeAlphaNumeric(String s) {
    return stripAccents(s)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool isTitleMatch(String? candidate, String expected) {
    if (candidate == null || candidate.isEmpty) return false;
    final c = normalizeAlphaNumeric(cleanTitle(candidate));
    final e = normalizeAlphaNumeric(cleanTitle(expected));
    if (c.isEmpty || e.isEmpty) return false;
    if (c == e) return true;
    if (c.contains(e) || e.contains(c)) {
      final minLen = e.length < c.length ? e.length : c.length;
      return minLen >= 3;
    }
    return false;
  }

  static bool isArtistMatch(String? candidate, String? expected) {
    if (expected == null || expected.trim().isEmpty) return true;
    if (candidate == null || candidate.trim().isEmpty) return false;

    final c = normalizeAlphaNumeric(cleanArtist(candidate));
    final e = normalizeAlphaNumeric(cleanArtist(expected));
    if (c.isEmpty || e.isEmpty) return false;
    if (c == e) return true;
    if (c.contains(e) || e.contains(c)) return true;

    final ep = normalizeAlphaNumeric(extractPrimaryArtist(expected));
    final cp = normalizeAlphaNumeric(extractPrimaryArtist(candidate));
    if (ep.isNotEmpty && cp.isNotEmpty && (ep == cp || cp.contains(ep) || ep.contains(cp))) {
      return true;
    }

    return false;
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

  /// ÉTAPE 2 : LRCLIB Recherche exacte avec durée (Tier 1)
  Future<Map<String, dynamic>?> getExactLyrics({
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
        'exact|${cleanedArtist?.toLowerCase() ?? ''}|${cleanedTitle.toLowerCase()}|$durationSeconds';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

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
      // 1. Try with duration first if available
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
          final data = resp.data as Map<String, dynamic>;
          final trackName = data['trackName'] as String? ?? data['name'] as String?;
          final artistName = data['artistName'] as String?;
          if (isTitleMatch(trackName, cleanedTitle) && isArtistMatch(artistName, pair.key)) {
            final res = _parseLrcLibResponse(data);
            if (res != null) {
              _setCache(cacheKey, res);
              debugPrint('[LRCLIB] Exact match with duration for "${pair.key} - ${pair.value}"');
              return res;
            }
          }
        }
      }

      // 2. Try /get without duration
      final respNoDur = await _getWithRetry(
        '/get',
        queryParameters: {
          'artist_name': pair.key,
          'track_name': pair.value,
        },
      );
      if (respNoDur != null && respNoDur.statusCode == 200 && respNoDur.data is Map) {
        final data = respNoDur.data as Map<String, dynamic>;
        final trackName = data['trackName'] as String? ?? data['name'] as String?;
        final artistName = data['artistName'] as String?;
        if (isTitleMatch(trackName, cleanedTitle) && isArtistMatch(artistName, pair.key)) {
          final res = _parseLrcLibResponse(data);
          if (res != null) {
            _setCache(cacheKey, res);
            debugPrint('[LRCLIB] Exact match for "${pair.key} - ${pair.value}"');
            return res;
          }
        }
      }
    }
    return null;
  }

  /// ÉTAPE 3 & 4 : LRCLIB Recherche floue / nettoyage + Secours Genius (Tier 2, 3, 4)
  Future<Map<String, dynamic>?> searchLyricsFuzzy({
    String? artist,
    required String title,
    int? durationSeconds,
    bool fallbackToGenius = true,
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
        'fuzzy|${cleanedArtist?.toLowerCase() ?? ''}|${cleanedTitle.toLowerCase()}';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // TIER 2: LRCLIB /api/search with structured fields (artist_name & track_name)
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
            final parsed = _findBestInList(
              list,
              expectedTitle: cleanedTitle,
              expectedArtist: cleanedArtist ?? primaryArtist,
              targetDuration: durationSeconds,
            );
            if (parsed != null) {
              _setCache(cacheKey, parsed);
              debugPrint('[LRCLIB] Structured search match for $params');
              return parsed;
            }
          }
        }
      }
    }

    // TIER 3: LRCLIB /api/search with query string (Always pair with artist to avoid mismatch)
    final searchQueries = <String>[];
    if (primaryArtist != null && primaryArtist.isNotEmpty) {
      searchQueries.add('$primaryArtist $cleanedTitle'.trim());
    }
    if (cleanedArtist != null &&
        cleanedArtist.isNotEmpty &&
        cleanedArtist != primaryArtist) {
      searchQueries.add('$cleanedArtist $cleanedTitle'.trim());
    }

    // Add unaccented query if diacritics are present
    final unaccentedTitle = stripAccents(cleanedTitle);
    final unaccentedArtist = primaryArtist != null ? stripAccents(primaryArtist) : null;
    if (unaccentedArtist != null &&
        (unaccentedTitle != cleanedTitle || unaccentedArtist != primaryArtist)) {
      searchQueries.add('$unaccentedArtist $unaccentedTitle'.trim());
    }

    // ONLY search title alone IF the artist is completely unknown!
    if ((primaryArtist == null || primaryArtist.isEmpty) &&
        (cleanedArtist == null || cleanedArtist.isEmpty)) {
      searchQueries.add(cleanedTitle);
    }

    for (final q in searchQueries) {
      if (q.isEmpty) continue;
      final resp = await _getWithRetry('/search', queryParameters: {'q': q});
      if (resp != null && resp.statusCode == 200 && resp.data is List) {
        final list = resp.data as List;
        if (list.isNotEmpty) {
          final parsed = _findBestInList(
            list,
            expectedTitle: cleanedTitle,
            expectedArtist: cleanedArtist ?? primaryArtist,
            targetDuration: durationSeconds,
          );
          if (parsed != null) {
            _setCache(cacheKey, parsed);
            debugPrint('[LRCLIB] Query match found for "$q"');
            return parsed;
          }
        }
      }
    }

    // TIER 4: Ultimate Multi-Source Fallback via Genius Lyrics
    if (fallbackToGenius) {
      final geniusArtist = primaryArtist ?? cleanedArtist ?? '';
      if (geniusArtist.isNotEmpty || cleanedTitle.isNotEmpty) {
        try {
          final geniusLyrics = await GeniusLyricsService().searchAndGetLyrics(
            artist: geniusArtist,
            title: cleanedTitle,
          );
          if (geniusLyrics != null && geniusLyrics.trim().isNotEmpty) {
            final res = {'value': geniusLyrics};
            _setCache(cacheKey, res);
            debugPrint('[Genius] Fallback lyrics captured for "$geniusArtist - $cleanedTitle"');
            return res;
          }
        } catch (e) {
          debugPrint('[Genius] Fallback failed: $e');
        }
      }
    }

    return null;
  }

  /// Recherche complète (exacte puis élargie)
  Future<Map<String, dynamic>?> searchLyrics({
    String? artist,
    required String title,
    int? durationSeconds,
  }) async {
    final exact = await getExactLyrics(
      artist: artist,
      title: title,
      durationSeconds: durationSeconds,
    );
    if (exact != null) return exact;

    return searchLyricsFuzzy(
      artist: artist,
      title: title,
      durationSeconds: durationSeconds,
    );
  }

  Map<String, dynamic>? _findBestInList(
    List list, {
    required String expectedTitle,
    String? expectedArtist,
    int? targetDuration,
  }) {
    if (list.isEmpty) return null;

    Map<String, dynamic>? bestMatch;
    int bestScore = -999999;

    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;

      final trackName = item['trackName'] as String? ?? item['name'] as String?;
      final artistName = item['artistName'] as String?;

      // 1. STRICT TITLE MATCH
      if (!isTitleMatch(trackName, expectedTitle)) {
        continue;
      }

      // 2. STRICT ARTIST MATCH (if expectedArtist is known)
      if (expectedArtist != null && expectedArtist.trim().isNotEmpty) {
        if (!isArtistMatch(artistName, expectedArtist)) {
          continue;
        }
      }

      final synced = item['syncedLyrics'] as String?;
      final plain = item['plainLyrics'] as String?;
      final isInstrumental = item['instrumental'] == true;

      if (isInstrumental) continue;

      final hasSynced = synced != null && synced.trim().isNotEmpty;
      final hasPlain = plain != null && plain.trim().isNotEmpty;

      if (!hasSynced && !hasPlain) continue;

      // 3. DURATION VALIDATION (if target duration is available)
      final itemDuration = (item['duration'] as num?)?.round();
      if (targetDuration != null && targetDuration > 0 && itemDuration != null) {
        final diff = (itemDuration - targetDuration).abs();
        if (diff > 18) {
          // Reject cuts with incompatible duration
          continue;
        }
      }

      int score = 0;
      if (hasSynced) {
        score += 10000;
      }

      if (targetDuration != null && targetDuration > 0 && itemDuration != null) {
        final diff = (itemDuration - targetDuration).abs();
        if (diff <= 2) {
          score += 5000;
        } else if (diff <= 5) {
          score += 2000;
        } else if (diff <= 10) {
          score += 500;
        } else {
          score -= diff * 15;
        }
      }

      if (expectedArtist != null && artistName != null) {
        if (normalizeAlphaNumeric(artistName) == normalizeAlphaNumeric(expectedArtist)) {
          score += 3000;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = item;
      }
    }

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
