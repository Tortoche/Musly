import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'library_database_service.dart';
import 'subsonic_service.dart';
import 'offline_service.dart';

/// Service centralisé et ultra-fiable pour la gestion des titres favoris (likés).
/// Synchronise de manière transparente :
/// 1. La mémoire vive (ValueNotifier réactif pour toute l'UI)
/// 2. La base de données SQLite locale (persistance hors-connexion absolue)
/// 3. Les SharedPreferences (sauvegarde immédiate de secours)
/// 4. Le serveur Subsonic / Navidrome (avec tolérance aux erreurs pour les flux virtuels Deezer)
class FavoriteSongsService extends ChangeNotifier {
  static const String _prefsKey = 'musly_favorite_song_ids';
  static const String _prefsSongsDataKey = 'musly_favorite_songs_data';

  final ValueNotifier<Set<String>> starredSongIds = ValueNotifier({});
  final Map<String, Song> _fallbackSongsMap = {};
  bool _initialized = false;
  final LibraryDatabaseService _db = LibraryDatabaseService();

  static final FavoriteSongsService _instance =
      FavoriteSongsService._internal();
  factory FavoriteSongsService() => _instance;
  FavoriteSongsService._internal();

  int get count => starredSongIds.value.length;

  bool isStarred(String? songId) {
    if (songId == null || songId.isEmpty) return false;
    return starredSongIds.value.contains(songId);
  }

  Future<void> initialize([SubsonicService? subsonicService]) async {
    if (_initialized) {
      if (subsonicService != null) {
        _syncWithServer(subsonicService);
      }
      return;
    }

    final newIds = <String>{};

    // 1. Chargement instantané depuis SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList(_prefsKey);
      if (savedIds != null) {
        newIds.addAll(savedIds);
      }

      final songsJson = prefs.getString(_prefsSongsDataKey);
      if (songsJson != null) {
        final decoded = json.decode(songsJson) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          try {
            _fallbackSongsMap[key] =
                Song.fromJson(Map<String, dynamic>.from(val as Map));
          } catch (_) {}
        });
      }
    } catch (e) {
      debugPrint('[FavoriteSongsService] SharedPreferences init error: $e');
    }

    // 2. Chargement depuis la base SQLite locale
    try {
      final dbSongs = await _db.getStarredSongs();
      for (final song in dbSongs) {
        newIds.add(song.id);
        _fallbackSongsMap[song.id] = song;
      }
    } catch (e) {
      debugPrint('[FavoriteSongsService] SQLite init error: $e');
    }

    starredSongIds.value = newIds;
    _initialized = true;
    notifyListeners();

    // 3. Synchronisation en tâche de fond avec le serveur
    if (subsonicService != null) {
      _syncWithServer(subsonicService);
    }
  }

  Future<void> _syncWithServer(SubsonicService subsonicService) async {
    try {
      if (!subsonicService.isConfigured) return;
      final starred = await subsonicService.getStarred();
      final updatedIds = Set<String>.from(starredSongIds.value);

      for (final song in starred.songs) {
        updatedIds.add(song.id);
        _fallbackSongsMap[song.id] = song;
        try {
          await _db.insertOrUpdateSong(song.copyWith(starred: true));
          await _db.setSongStarred(song.id, true);
        } catch (_) {}
      }

      starredSongIds.value = updatedIds;
      await _persistToPrefs();
      notifyListeners();
    } catch (e) {
      debugPrint('[FavoriteSongsService] Server sync skipped or error: $e');
    }
  }

  Future<bool> toggleFavorite(
    Song song,
    SubsonicService subsonicService, {
    OfflineService? offlineService,
    dynamic libraryProvider,
  }) async {
    final currentlyStarred = isStarred(song.id);
    final targetStarred = !currentlyStarred;

    // 1. Mise à jour mémoire instantanée (optimiste et réactive)
    final updatedIds = Set<String>.from(starredSongIds.value);
    if (targetStarred) {
      updatedIds.add(song.id);
      _fallbackSongsMap[song.id] = song.copyWith(starred: true);
    } else {
      updatedIds.remove(song.id);
      _fallbackSongsMap.remove(song.id);
    }
    starredSongIds.value = updatedIds;
    notifyListeners();

    // 2. Persistance locale immédiate (SQLite + SharedPreferences)
    try {
      final updatedSong = song.copyWith(starred: targetStarred);
      if (targetStarred) {
        await _db.insertOrUpdateSong(updatedSong);
        await _db.setSongStarred(song.id, true);
      } else {
        await _db.setSongStarred(song.id, false);
      }
      await _persistToPrefs();
    } catch (e) {
      debugPrint('[FavoriteSongsService] Error saving to DB: $e');
    }

    // 3. Envoi au serveur (avec capture douce des erreurs pour les morceaux virtuels Deezer / hors-ligne)
    try {
      if (subsonicService.isConfigured) {
        if (targetStarred) {
          await subsonicService.star(id: song.id);
        } else {
          await subsonicService.unstar(id: song.id);
        }
      }
    } catch (e) {
      // Pour les titres du catalogue étendu Deezer (ext_dz_...), Navidrome ne les possède pas sur disque
      // et retourne une erreur "Item not found". Le titre reste 100% conservé localement dans les favoris Musly.
      debugPrint(
        '[FavoriteSongsService] Server star failed for "${song.title}" (${song.id}): $e. Local favorite preserved.',
      );
    }

    // 4. Auto-téléchargement si activé par l'utilisateur
    if (targetStarred && offlineService != null) {
      try {
        await offlineService.autoDownloadIfEnabled(
          song,
          subsonicService,
          libraryProvider,
        );
      } catch (e) {
        debugPrint('[FavoriteSongsService] Auto download failed: $e');
      }
    }

    return targetStarred;
  }

  Future<List<Song>> getFavoriteSongs(SubsonicService subsonicService) async {
    final Map<String, Song> songsMap = {};

    // 1. Depuis la base locale
    try {
      final dbSongs = await _db.getStarredSongs();
      for (final s in dbSongs) {
        songsMap[s.id] = s.copyWith(starred: true);
      }
    } catch (e) {
      debugPrint('[FavoriteSongsService] Error reading local starred songs: $e');
    }

    // 2. Depuis le fallback SharedPreferences
    _fallbackSongsMap.forEach((id, s) {
      if (starredSongIds.value.contains(id) && !songsMap.containsKey(id)) {
        songsMap[id] = s.copyWith(starred: true);
      }
    });

    // 3. Depuis le serveur Subsonic
    try {
      if (subsonicService.isConfigured) {
        final serverStarred = await subsonicService.getStarred();
        for (final s in serverStarred.songs) {
          songsMap[s.id] = s.copyWith(starred: true);
          starredSongIds.value.add(s.id);
        }
      }
    } catch (e) {
      debugPrint('[FavoriteSongsService] Error fetching server starred: $e');
    }

    // Filtrer et renvoyer uniquement les titres effectivement likés
    final result = songsMap.values
        .where((s) => starredSongIds.value.contains(s.id))
        .toList();

    return result;
  }

  Future<void> _persistToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, starredSongIds.value.toList());

      final songsData = <String, dynamic>{};
      _fallbackSongsMap.forEach((id, song) {
        if (starredSongIds.value.contains(id)) {
          songsData[id] = song.toJson();
        }
      });
      await prefs.setString(_prefsSongsDataKey, json.encode(songsData));
    } catch (e) {
      debugPrint('[FavoriteSongsService] Failed to persist to prefs: $e');
    }
  }
}
