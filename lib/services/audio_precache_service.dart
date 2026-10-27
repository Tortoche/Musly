import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../models/song.dart';
import 'subsonic_service.dart';
import 'offline_service.dart';
import 'lrclib_service.dart';

/// Service de pré-cache audio glissant (Rolling Audio Pre-cache).
/// Télécharge en tâche de fond les 5 prochains morceaux de la file d'attente
/// et supprime automatiquement du cache les morceaux sortis de la fenêtre d'écoute.
class AudioPrecacheService {
  static final AudioPrecacheService _instance = AudioPrecacheService._internal();
  factory AudioPrecacheService() => _instance;
  AudioPrecacheService._internal();

  Directory? _cacheDir;
  bool _isInitialized = false;
  CancelToken? _currentCancelToken;
  int _syncVersion = 0;
  bool _isSyncing = false;

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
      final tempDir = await getTemporaryDirectory();
      _cacheDir = Directory('${tempDir.path}/musly_rolling_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('[AudioPrecache] Erreur initialisation dossier: $e');
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

  /// Synchronise la fenêtre glissante des 5 prochains morceaux de la file.
  /// 1. Supprime du cache les morceaux qui ne sont plus dans la fenêtre.
  /// 2. Télécharge successivement les 5 prochains morceaux en tâche de fond.
  Future<void> syncQueueWindow({
    required List<Song> queue,
    required int currentIndex,
    required SubsonicService subsonicService,
  }) async {
    if (queue.isEmpty) return;
    await initialize();
    if (_cacheDir == null) return;

    _syncVersion++;
    final currentVersion = _syncVersion;

    // Définir la fenêtre glissante :
    // - Les 5 prochains morceaux en PRIORITÉ ABSOLUE (pour enchaînement immédiat et écoute hors-ligne)
    // - Le morceau actuel
    // - 1 morceau précédent (pour retour arrière fluide hors ligne)
    final Set<String> targetSongIds = {};
    final List<Song> downloadQueue = [];

    // 1. Les 5 prochains morceaux (priorité #1)
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

    // 1. Éviction automatique du cache : suppression des morceaux sortis de la fenêtre
    await _evictExpiredFiles(targetSongIds);

    // 2. Si aucune nouvelle piste à pré-charger, on s'arrête
    if (downloadQueue.isEmpty) return;

    // 3. Télécharger les pistes prioritaires l'une après l'autre
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
      // Résolution du flux audio compatible Subsonic, Deezer CJ Resolver & YouTube
      final streamUrl = song.isLocal == true && song.path != null
          ? Uri.file(song.path!).toString()
          : await subsonicService.resolveStreamUrlAsync(song);

      if (streamUrl.isEmpty) return;

      if (streamUrl.startsWith('file://')) {
        final localFile = File(Uri.parse(streamUrl).toFilePath());
        if (await localFile.exists()) {
          await localFile.copy(finalPath);
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
          // Succès complet : renommage atomique
          await partFile.rename(finalPath);
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

  /// Éviction : supprime du dossier de pré-cache tous les fichiers non ciblés
  Future<void> _evictExpiredFiles(Set<String> activeIds) async {
    if (_cacheDir == null) return;
    try {
      final sanitizedActive = activeIds.map(_sanitizeId).toSet();
      final entities = _cacheDir!.listSync();

      for (final entity in entities) {
        if (entity is File) {
          final fileName = entity.uri.pathSegments.last;
          if (fileName.endsWith('.part')) {
            final partId = fileName.substring(0, fileName.length - 5);
            if (!sanitizedActive.contains(partId)) {
              try {
                await entity.delete();
              } catch (_) {}
            }
            continue;
          }

          if (fileName.endsWith('.mp3')) {
            final fileId = fileName.substring(0, fileName.length - 4);
            if (!sanitizedActive.contains(fileId)) {
              // Ce morceau est sorti de la fenêtre des 5 morceaux : suppression automatique
              try {
                await entity.delete();
              } catch (_) {}
              debugPrint('[AudioPrecache] 🗑️ Sorti du cache glissant: $fileName');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AudioPrecache] Erreur éviction cache: $e');
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
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }
    } catch (_) {}
  }
}
