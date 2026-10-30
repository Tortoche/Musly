import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import 'subsonic_service.dart';
import 'offline_service.dart';
import 'lrclib_service.dart';

/// Service de pré-cache audio glissant (Rolling Audio Pre-cache) intelligent.
/// Télécharge en tâche de fond les prochains morceaux de la file d'attente,
/// conserve en mémoire et sur disque les métadonnées de chaque morceau entier
/// pour permettre une écoute hors-ligne fluide et complète lors d'une coupure réseau.
class AudioPrecacheService {
  static final AudioPrecacheService _instance = AudioPrecacheService._internal();
  factory AudioPrecacheService() => _instance;
  AudioPrecacheService._internal();

  static const String _keyPrecachedMetadata = 'musly_precached_songs_meta_v1';

  Directory? _cacheDir;
  bool _isInitialized = false;
  CancelToken? _currentCancelToken;
  int _syncVersion = 0;
  bool _isSyncing = false;

  final Map<String, Song> _cachedSongsMap = {};
  final Map<String, Song> _knownSongs = {};
  SharedPreferences? _prefs;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 45),
      headers: {
        'User-Agent': 'Musly/1.2.0 (AudioPrecache)',
      },
    ),
  );

  Future<void> initialize() async {
    if (_isInitialized && _cacheDir != null) return;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final tempDir = await getTemporaryDirectory();
      _cacheDir = Directory('${tempDir.path}/musly_rolling_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      _loadSavedMetadata();
      _isInitialized = true;
    } catch (e) {
      debugPrint('[AudioPrecache] Erreur initialisation dossier: $e');
    }
  }

  void _loadSavedMetadata() {
    try {
      // 1. Charger les métadonnées de pré-cache persistées
      final raw = _prefs?.getString(_keyPrecachedMetadata);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        decoded.forEach((key, val) {
          try {
            final song = Song.fromJson(Map<String, dynamic>.from(val));
            _cachedSongsMap[key] = song;
            _knownSongs[key] = song;
            _knownSongs[_sanitizeId(song.id)] = song;
          } catch (_) {}
        });
      }

      // 2. Extraire de persistent_queue pour peupler _knownSongs avec les morceaux récents
      final queueRaw = _prefs?.getString('persistent_queue');
      if (queueRaw != null && queueRaw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(queueRaw);
        for (final item in list) {
          try {
            final song = Song.fromJson(Map<String, dynamic>.from(item));
            _knownSongs[song.id] = song;
            _knownSongs[_sanitizeId(song.id)] = song;
          } catch (_) {}
        }
      }

      // 3. Réconcilier les fichiers .mp3 existants dans _cacheDir avec _knownSongs
      if (_cacheDir != null && _cacheDir!.existsSync()) {
        final entities = _cacheDir!.listSync();
        for (final entity in entities) {
          if (entity is File && entity.path.endsWith('.mp3')) {
            final fileName = entity.uri.pathSegments.last;
            final fileId = fileName.substring(0, fileName.length - 4);
            if (entity.lengthSync() > 30000) {
              final song = _knownSongs[fileId];
              if (song != null) {
                _cachedSongsMap[fileId] = song;
                _cachedSongsMap[song.id] = song;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AudioPrecache] Erreur chargement métadonnées: $e');
    }
  }

  Future<void> _saveCachedMetadata() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final map = _cachedSongsMap.map((k, v) => MapEntry(k, v.toJson()));
      await _prefs?.setString(_keyPrecachedMetadata, jsonEncode(map));
    } catch (e) {
      debugPrint('[AudioPrecache] Erreur sauvegarde métadonnées: $e');
    }
  }

  String _sanitizeId(String id) {
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  String _getSongPath(String songId) {
    return '${_cacheDir!.path}/${_sanitizeId(songId)}.mp3';
  }

  String _getSongPartPath(String songId) {
    return '${_cacheDir!.path}/${_sanitizeId(songId)}.part';
  }

  /// Retourne le chemin local si le morceau est complètement pré-mis en cache (> 30 Ko)
  String? getPrecachedAudioPath(String songId) {
    if (_cacheDir == null) return null;
    final path = _getSongPath(songId);
    final file = File(path);
    if (file.existsSync()) {
      final len = file.lengthSync();
      if (len > 30000) {
        return path;
      }
    }
    return null;
  }

  bool hasPrecached(String songId) {
    return getPrecachedAudioPath(songId) != null;
  }

  /// Retourne le chemin cible thorique du fichier audio dans le cache
  String? getTargetAudioPath(String songId) {
    if (_cacheDir == null) return null;
    return _getSongPath(songId);
  }

  void recordPrecachedSong(String songId, Song? song) {
    if (song != null) {
      _cachedSongsMap[songId] = song;
      _cachedSongsMap[_sanitizeId(songId)] = song;
      _knownSongs[songId] = song;
      _knownSongs[_sanitizeId(songId)] = song;
      unawaited(_saveCachedMetadata());
    }
  }

  /// Enregistre les métadonnées d'un morceau pour reconnaissance ultérieure
  void recordSongMetadata(Song song) {
    _knownSongs[song.id] = song;
    _knownSongs[_sanitizeId(song.id)] = song;
    if (hasPrecached(song.id)) {
      _cachedSongsMap[song.id] = song;
      _cachedSongsMap[_sanitizeId(song.id)] = song;
      unawaited(_saveCachedMetadata());
    }
  }

  /// Retourne la liste de tous les morceaux ENTIÈREMENT présents en cache audio (> 30 Ko)
  List<Song> getFullyPrecachedSongs() {
    if (_cacheDir == null) return [];
    final List<Song> list = [];
    final Set<String> seenIds = {};
    final List<String> toRemove = [];

    // Vérifier les morceaux enregistrés dans _cachedSongsMap
    for (final entry in _cachedSongsMap.entries) {
      if (seenIds.contains(entry.value.id)) continue;
      final path = _getSongPath(entry.key);
      final file = File(path);
      if (file.existsSync() && file.lengthSync() > 30000) {
        list.add(entry.value);
        seenIds.add(entry.value.id);
      } else if (!file.existsSync()) {
        toRemove.add(entry.key);
      }
    }

    // Réconcilier les éventuels fichiers .mp3 du dossier avec _knownSongs
    try {
      if (_cacheDir!.existsSync()) {
        final entities = _cacheDir!.listSync();
        for (final entity in entities) {
          if (entity is File && entity.path.endsWith('.mp3')) {
            final fileName = entity.uri.pathSegments.last;
            final fileId = fileName.substring(0, fileName.length - 4);
            if (entity.lengthSync() > 30000) {
              final song = _knownSongs[fileId];
              if (song != null && !seenIds.contains(song.id)) {
                list.add(song);
                seenIds.add(song.id);
                _cachedSongsMap[song.id] = song;
                _cachedSongsMap[fileId] = song;
              }
            }
          }
        }
      }
    } catch (_) {}

    if (toRemove.isNotEmpty) {
      for (final id in toRemove) {
        _cachedSongsMap.remove(id);
      }
      unawaited(_saveCachedMetadata());
    }

    return list;
  }

  /// Synchronise la fenêtre glissante des 5 prochains morceaux de la file.
  Future<void> syncQueueWindow({
    required List<Song> queue,
    required int currentIndex,
    required SubsonicService subsonicService,
  }) async {
    if (queue.isEmpty) return;
    await initialize();
    if (_cacheDir == null) return;

    // Enregistrer les métadonnées de tous les morceaux de la file
    for (final s in queue) {
      _knownSongs[s.id] = s;
      _knownSongs[_sanitizeId(s.id)] = s;
    }

    _syncVersion++;
    final currentVersion = _syncVersion;

    final Set<String> targetSongIds = {};
    final List<Song> downloadQueue = [];

    // 1. Les 5 prochains morceaux (priorité #1 pour écoute hors-ligne immédiate)
    final maxIndex = (currentIndex + 6).clamp(0, queue.length);
    for (int i = currentIndex + 1; i < maxIndex; i++) {
      final nextSong = queue[i];
      targetSongIds.add(nextSong.id);
      if (!_isSongLocallyReady(nextSong)) {
        downloadQueue.add(nextSong);
      }
    }

    // 2. Le morceau actuel
    if (currentIndex >= 0 && currentIndex < queue.length) {
      final currentSong = queue[currentIndex];
      targetSongIds.add(currentSong.id);
      if (!_isSongLocallyReady(currentSong)) {
        downloadQueue.add(currentSong);
      }
    }

    // 3. Le morceau précédent (gardé en cache)
    if (currentIndex > 0 && currentIndex - 1 < queue.length) {
      targetSongIds.add(queue[currentIndex - 1].id);
    }

    // Nettoyage intelligent : suppression des .part obsolètes et gestion quota sans perte agressive
    await _evictExpiredFiles(targetSongIds);

    if (downloadQueue.isEmpty) return;

    if (_isSyncing) {
      _currentCancelToken?.cancel('Nouvelle file reçue');
    }
    _isSyncing = true;

    try {
      for (final song in downloadQueue) {
        if (_syncVersion != currentVersion) {
          debugPrint('[AudioPrecache] Abandon sync v$currentVersion (supplanté par v$_syncVersion)');
          break;
        }

        if (_isSongLocallyReady(song)) continue;

        await _downloadSingleSong(song, subsonicService, currentVersion);
      }
    } finally {
      if (_syncVersion == currentVersion) {
        _isSyncing = false;
      }
    }
  }

  bool _isSongLocallyReady(Song song) {
    if (song.isLocal == true && song.path != null && File(song.path!).existsSync()) {
      return true;
    }
    if (OfflineService().isSongDownloaded(song.id)) {
      return true;
    }
    return hasPrecached(song.id);
  }

  Future<void> _downloadSingleSong(
    Song song,
    SubsonicService subsonicService,
    int version,
  ) async {
    final finalPath = _getSongPath(song.id);
    final partPath = _getSongPartPath(song.id);

    try {
      final streamUrl = song.isLocal == true && song.path != null
          ? Uri.file(song.path!).toString()
          : await subsonicService.resolveStreamUrlAsync(song);

      if (streamUrl.isEmpty) return;

      if (streamUrl.startsWith('file://')) {
        final localFile = File(Uri.parse(streamUrl).toFilePath());
        if (await localFile.exists()) {
          await localFile.copy(finalPath);
          _cachedSongsMap[song.id] = song;
          _cachedSongsMap[_sanitizeId(song.id)] = song;
          unawaited(_saveCachedMetadata());
          debugPrint('[AudioPrecache] ⚡ Morceau local copié en cache: "${song.title}"');
          return;
        }
      }

      _currentCancelToken = CancelToken();

      debugPrint('[AudioPrecache] 📥 Pré-téléchargement glissant: "${song.title}" (${song.id})');

      await _dio.download(
        streamUrl,
        partPath,
        cancelToken: _currentCancelToken,
        options: Options(
          headers: {'Accept': '*/*'},
          responseType: ResponseType.stream,
        ),
      );

      final partFile = File(partPath);
      if (await partFile.exists()) {
        final length = await partFile.length();
        if (length > 30000) {
          // Succès complet : renommage atomique vers .mp3
          await partFile.rename(finalPath);
          _cachedSongsMap[song.id] = song;
          _cachedSongsMap[_sanitizeId(song.id)] = song;
          unawaited(_saveCachedMetadata());

          debugPrint(
            '[AudioPrecache] ⚡ Prêt pour lecture hors-ligne: "${song.title}" (${(length / 1024 / 1024).toStringAsFixed(1)} Mo)',
          );

          // Pré-charger également les paroles en cache local
          if (song.title.isNotEmpty) {
            unawaited(
              LrcLibService().searchLyrics(
                artist: song.artist,
                title: song.title,
                durationSeconds: song.duration,
              ).then((lyrics) {
                if (lyrics != null) {
                  OfflineService().saveLyrics(song.id, lyrics);
                }
              }).catchError((_) {}),
            );
          }
        } else {
          try {
            await partFile.delete();
          } catch (_) {}
        }
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        debugPrint('[AudioPrecache] Téléchargement annulé pour "${song.title}"');
      } else {
        debugPrint('[AudioPrecache] Échec pré-cache pour "${song.title}": $e');
      }
      final partFile = File(partPath);
      if (partFile.existsSync()) {
        try {
          partFile.deleteSync();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[AudioPrecache] Erreur inattendue: $e');
      final partFile = File(partPath);
      if (partFile.existsSync()) {
        try {
          partFile.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// Éviction propre : supprime les .part orphelins et applique un quota souple (40 morceaux / 200 Mo).
  /// Les morceaux complets écoutés ou pré-chargés ne sont JAMAIS supprimés prématurément.
  Future<void> _evictExpiredFiles(Set<String> activeIds) async {
    if (_cacheDir == null) return;
    try {
      final sanitizedActive = activeIds.map(_sanitizeId).toSet();
      final entities = _cacheDir!.listSync();

      // 1. Supprimer les fichiers .part inachevés / orphelins
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.part')) {
          final fileName = entity.uri.pathSegments.last;
          final partId = fileName.substring(0, fileName.length - 5);
          if (!sanitizedActive.contains(partId)) {
            try {
              entity.deleteSync();
            } catch (_) {}
          }
        }
      }

      // 2. Gestion quota souple pour les .mp3 complets (conserver jusqu'à 40 titres / 200 Mo)
      final mp3Files = entities.whereType<File>().where((f) => f.path.endsWith('.mp3')).toList();
      const int maxCacheFiles = 40;
      const int maxCacheBytes = 200 * 1024 * 1024; // 200 Mo

      int totalBytes = 0;
      for (final f in mp3Files) {
        try {
          totalBytes += f.lengthSync();
        } catch (_) {}
      }

      if (mp3Files.length > maxCacheFiles || totalBytes > maxCacheBytes) {
        mp3Files.sort((a, b) {
          try {
            return a.lastModifiedSync().compareTo(b.lastModifiedSync());
          } catch (_) {
            return 0;
          }
        });

        for (final file in mp3Files) {
          if (mp3Files.length <= maxCacheFiles && totalBytes <= maxCacheBytes) break;
          final fileName = file.uri.pathSegments.last;
          final fileId = fileName.substring(0, fileName.length - 4);
          if (!sanitizedActive.contains(fileId)) {
            try {
              final len = file.lengthSync();
              file.deleteSync();
              totalBytes -= len;
              _cachedSongsMap.remove(fileId);
              debugPrint('[AudioPrecache] 🗑️ Purge quota cache: $fileName');
            } catch (_) {}
          }
        }
        unawaited(_saveCachedMetadata());
      }
    } catch (e) {
      debugPrint('[AudioPrecache] Erreur gestion cache: $e');
    }
  }

  void cancelPending() {
    _currentCancelToken?.cancel('Réseau interrompu');
    _isSyncing = false;
  }

  Future<void> clearAll() async {
    if (_cacheDir == null) return;
    try {
      cancelPending();
      _cachedSongsMap.clear();
      unawaited(_saveCachedMetadata());
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }
    } catch (_) {}
  }
}
