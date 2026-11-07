import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class GeniusLyricsService {
  static final GeniusLyricsService _instance = GeniusLyricsService._internal();
  factory GeniusLyricsService() => _instance;
  GeniusLyricsService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 7),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7',
      },
    ),
  );

  final Map<String, String> _cache = {};
  static const int _maxCacheSize = 100;

  void _setCache(String key, String value) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  static String _unescapeHtml(String input) {
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
          final code = int.tryParse(match.group(1)!);
          return code != null ? String.fromCharCode(code) : match.group(0)!;
        })
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
          final code = int.tryParse(match.group(1)!, radix: 16);
          return code != null ? String.fromCharCode(code) : match.group(0)!;
        });
  }

  Future<String?> searchAndGetLyrics({
    required String artist,
    required String title,
  }) async {
    final cleanQuery = '$artist $title'.trim();
    if (cleanQuery.isEmpty) return null;

    final cacheKey = '${artist.toLowerCase()}|${title.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final searchUri = Uri.parse(
        'https://genius.com/api/search/multi?q=${Uri.encodeComponent(cleanQuery)}',
      );
      final searchResp = await _dio.getUri(searchUri);

      if (searchResp.statusCode != 200 || searchResp.data is! Map) {
        return null;
      }

      final sections = searchResp.data['response']?['sections'] as List?;
      if (sections == null || sections.isEmpty) return null;

      String? songUrl;
      for (final sec in sections) {
        if (sec is Map && sec['type'] == 'song') {
          final hits = sec['hits'] as List?;
          if (hits != null && hits.isNotEmpty) {
            final firstHit = hits.first;
            if (firstHit is Map && firstHit['result'] is Map) {
              songUrl = firstHit['result']['url'] as String?;
              break;
            }
          }
        }
      }

      if (songUrl == null || songUrl.isEmpty) return null;

      final pageResp = await _dio.get(
        songUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (pageResp.statusCode != 200 || pageResp.data == null) {
        return null;
      }

      final htmlContent = pageResp.data.toString();
      final regex = RegExp(
        r'<div[^>]*data-lyrics-container=["\x27]true["\x27][^>]*>(.*?)</div>',
        dotAll: true,
      );

      final matches = regex.allMatches(htmlContent).toList();
      String rawLyrics = '';

      if (matches.isNotEmpty) {
        rawLyrics = matches.map((m) => m.group(1) ?? '').join('\n');
      } else {
        final legacyMatch = RegExp(
          r'<div[^>]*class=["\x27]lyrics["\x27][^>]*>(.*?)</div>',
          dotAll: true,
        ).firstMatch(htmlContent);
        if (legacyMatch != null) {
          rawLyrics = legacyMatch.group(1) ?? '';
        }
      }

      if (rawLyrics.isEmpty) return null;

      rawLyrics = rawLyrics.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
      rawLyrics = rawLyrics.replaceAll(RegExp(r'<[^>]+>'), '');
      var lyrics = _unescapeHtml(rawLyrics).trim();

      // Clean contributor and translation banner on top
      lyrics = lyrics.replaceAll(
        RegExp(r'^\d+\s*Contributors.*?(?=\n|\[)', multiLine: false),
        '',
      );
      // Clean trailing embed numbers
      lyrics = lyrics.replaceAll(RegExp(r'\d*Embed$'), '');
      lyrics = lyrics.trim();

      if (lyrics.isNotEmpty) {
        _setCache(cacheKey, lyrics);
        debugPrint('[Genius] Lyrics successfully retrieved for "$artist - $title"');
        return lyrics;
      }
    } catch (e) {
      debugPrint('[Genius] Error fetching lyrics for "$artist - $title": $e');
    }

    return null;
  }
}
