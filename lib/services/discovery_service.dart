import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'deezer_service.dart';

/// Service gérant la génération autonome du Mix Découverte 100% côté client
/// Analyse les écoutes réelles de l'utilisateur et interroge Deezer pour composer
/// un mix quotidien unique de 30-35 titres en studio FLAC/320k.
class DiscoveryService extends ChangeNotifier {
  static final DiscoveryService _instance = DiscoveryService._internal();
  factory DiscoveryService() => _instance;
  DiscoveryService._internal();

  static const String kDiscoveryPlaylistId = 'app_discovery_daily';
  static const String _kCacheKey = 'app_discovery_playlist_cache_v2';
  static const String _kDateKey = 'app_discovery_date_v2';

  Playlist? _currentDiscoveryPlaylist;
  bool _isGenerating = false;

  Playlist? get currentDiscoveryPlaylist => _currentDiscoveryPlaylist;
  bool get isGenerating => _isGenerating;

  Future<void> initialize() async {
    await _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_kCacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(cachedJson);
        _currentDiscoveryPlaylist = Playlist.fromJson(data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[DiscoveryService] Erreur lecture cache: $e');
    }
  }

  /// Génère le mix découverte client complet (30-35 morceaux)
  Future<Playlist> generateDailyDiscovery({
    required List<String> userTopArtists,
    required List<Song> userLibrarySongs,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10); // Format YYYY-MM-DD
    final lastDate = prefs.getString(_kDateKey);

    // Si déjà généré aujourd'hui et non forcé, renvoyer immédiatement le cache
    if (!forceRefresh &&
        lastDate == today &&
        _currentDiscoveryPlaylist != null &&
        (_currentDiscoveryPlaylist!.songs?.isNotEmpty ?? false)) {
      return _currentDiscoveryPlaylist!;
    }

    if (_isGenerating && _currentDiscoveryPlaylist != null) {
      return _currentDiscoveryPlaylist!;
    }

    _isGenerating = true;
    notifyListeners();

    try {
      final deezerService = DeezerService();
      final List<Song> discoveryTracks = [];
      final Set<String> seenIds = {};
      final Set<String> seenTitles = {};

      void addSongIfNew(Song t) {
        final artistStr = t.artist?.trim().toLowerCase() ?? '';
        final normTitle =
            '${t.title.trim().toLowerCase()}_$artistStr';
        if (!seenIds.contains(t.id) && !seenTitles.contains(normTitle)) {
          seenIds.add(t.id);
          seenTitles.add(normTitle);
          discoveryTracks.add(t);
        }
      }

      // 1. Filtrer les artistes graines (vrais goûts de l'utilisateur)
      final cleanSeeds = userTopArtists
          .map((a) => a.trim())
          .where((a) =>
              a.length >= 2 &&
              !a.toLowerCase().contains('inconnu') &&
              !a.toLowerCase().contains('unknown'))
          .take(5)
          .toList();

      // 2. Interroger Deezer pour chaque artiste phare (Radio d'artistes similaires + Tops)
      for (final artistName in cleanSeeds) {
        final dzArtist = await deezerService.searchArtistByName(artistName);
        if (dzArtist != null && dzArtist.id.isNotEmpty) {
          final radioTracks =
              await deezerService.fetchSimilarArtistTracks(dzArtist.id, limit: 8);
          for (final t in radioTracks) {
            addSongIfNew(t);
          }
          if (radioTracks.length < 4) {
            final topTracks =
                await deezerService.getArtistTopTracks(dzArtist.id, limit: 6);
            for (final t in topTracks) {
              addSongIfNew(t);
            }
          }
        }
      }

      // 3. Intégrer également des pépites de la bibliothèque locale pour redécouverte
      if (userLibrarySongs.isNotEmpty) {
        final shuffledLib = List<Song>.from(userLibrarySongs)..shuffle();
        for (final s in shuffledLib.take(6)) {
          addSongIfNew(s);
        }
      }

      // 4. Si la sélection est courte (ex: nouveau profil), compléter avec les Tops Deezer Charts
      if (discoveryTracks.length < 25) {
        final chartTracks = await deezerService.getChartTracks(limit: 30);
        for (final t in chartTracks) {
          addSongIfNew(t);
          if (discoveryTracks.length >= 35) break;
        }
      }

      // 5. Mélanger harmonieusement et limiter à 35 morceaux
      discoveryTracks.shuffle();
      final finalSelection = discoveryTracks.take(35).toList();

      // Trouver une belle pochette HD
      String? bestCover;
      for (final s in finalSelection) {
        if (s.coverArt != null && s.coverArt!.isNotEmpty) {
          bestCover = s.coverArt;
          break;
        }
      }

      final playlist = Playlist(
        id: kDiscoveryPlaylistId,
        name: 'DÉCOUVERTES - POUR VOUS',
        comment:
            'Mix quotidien généré par Musly • Sélection personnalisée selon vos écoutes',
        songCount: finalSelection.length,
        created: DateTime.now(),
        changed: DateTime.now(),
        coverArt: bestCover,
        songs: finalSelection,
      );

      _currentDiscoveryPlaylist = playlist;
      await prefs.setString(_kCacheKey, jsonEncode(playlist.toJson()));
      await prefs.setString(_kDateKey, today);

      _isGenerating = false;
      notifyListeners();
      return playlist;
    } catch (e) {
      debugPrint('[DiscoveryService] Erreur lors de la génération du mix: $e');
      _isGenerating = false;
      notifyListeners();
      if (_currentDiscoveryPlaylist != null) return _currentDiscoveryPlaylist!;
      rethrow;
    }
  }
}
