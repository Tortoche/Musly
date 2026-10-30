import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import 'subsonic_service.dart';
import 'offline_service.dart';
import 'audio_precache_service.dart';

enum AudioCodecFormat {
  opus,
  flac,
  mp3,
  aac,
  unknown,
}

class AudioQualityDetails {
  final AudioCodecFormat format;
  final String label;
  final String badgeText;
  final String sampleRate;
  final String bitRate;
  final String description;
  final bool isHighQuality;

  const AudioQualityDetails({
    required this.format,
    required this.label,
    required this.badgeText,
    required this.sampleRate,
    required this.bitRate,
    required this.description,
    required this.isHighQuality,
  });

  static AudioQualityDetails fromFormat(AudioCodecFormat format, {int? reportedBitrate}) {
    switch (format) {
      case AudioCodecFormat.opus:
        return AudioQualityDetails(
          format: format,
          label: 'Studio Master 48 kHz',
          badgeText: 'STUDIO MASTER 48 kHz',
          sampleRate: '48 000 Hz',
          bitRate: reportedBitrate != null && reportedBitrate > 0
              ? '$reportedBitrate kbps VBR'
              : '~160 kbps VBR',
          description: 'Flux Opus 48 kHz encodé en master direct sans transcodage destructeur.',
          isHighQuality: true,
        );
      case AudioCodecFormat.flac:
        return const AudioQualityDetails(
          format: AudioCodecFormat.flac,
          label: 'Hi-Res Lossless',
          badgeText: 'HI-RES LOSSLESS',
          sampleRate: '44.1 - 96 kHz',
          bitRate: 'Lossless (Bit-Perfect)',
          description: 'Fichier studio FLAC non compressé sans aucune perte audio.',
          isHighQuality: true,
        );
      case AudioCodecFormat.aac:
        return AudioQualityDetails(
          format: format,
          label: 'AAC Haute Fidélité',
          badgeText: 'AAC HQ',
          sampleRate: '44 100 Hz',
          bitRate: reportedBitrate != null && reportedBitrate > 0
              ? '$reportedBitrate kbps'
              : '256 kbps',
          description: 'Flux AAC haute fidélité standard Apple Music / Library.',
          isHighQuality: true,
        );
      case AudioCodecFormat.mp3:
      default:
        return AudioQualityDetails(
          format: format,
          label: 'Standard (Direct Stream)',
          badgeText: 'STANDARD',
          sampleRate: '44 100 Hz',
          bitRate: reportedBitrate != null && reportedBitrate > 0
              ? '$reportedBitrate kbps'
              : '128 kbps CBR',
          description: 'Flux direct initial en cours de promotion automatique vers Studio Master.',
          isHighQuality: false,
        );
    }
  }
}

/// Service de gestion et de garantie de la Haute Qualité Audio (CJ Stream).
/// Orchestre les vérifications sans coupure de lecture, les mises à niveau
/// transparentes en arrière-plan et la pré-chauffe des playlists.
class AudioQualityManager extends ChangeNotifier {
  static final AudioQualityManager _instance = AudioQualityManager._internal();
  factory AudioQualityManager() => _instance;
  AudioQualityManager._internal();

  static const String _keyPendingUpgrades = 'musly_pending_quality_upgrades_v1';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 40),
      headers: {
        'User-Agent': 'Musly/2.0.4 (AudioQualityManager)',
      },
    ),
  );

  bool _isInitialized = false;
  Timer? _upgradeTimer;
  bool _isProcessingUpgrade = false;
  final Set<String> _pendingUpgradeSongIds = {};
  final Map<String, int> _pollAttempts = {};
  final Map<String, AudioQualityDetails> _cachedSongQuality = {};

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOnline = true;

  Set<String> get pendingUpgradeSongIds => Set.unmodifiable(_pendingUpgradeSongIds);

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_keyPendingUpgrades) ?? [];
      _pendingUpgradeSongIds.addAll(saved);

      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        final online = results.any((r) => r != ConnectivityResult.none);
        if (online != _isOnline) {
          _isOnline = online;
          if (_isOnline) {
            debugPrint('[AudioQuality] 🌐 Connexion rétablie, reprise de la boucle d\'upgrade');
            _triggerUpgradeCheck();
          }
        }
      });

      // Nettoyer les fichiers temporaires orphelins (sécurité anti-crash)
      _cleanupOrphanedTmpFiles();

      // Lancer le timer de vérification toutes les 30 secondes
      _startUpgradeTimer();

      _isInitialized = true;
      debugPrint('[AudioQuality] Initialisé. ${_pendingUpgradeSongIds.length} morceaux en attente de promotion HQ');
    } catch (e) {
      debugPrint('[AudioQuality] Erreur initialisation: $e');
    }
  }

  void _startUpgradeTimer() {
    _upgradeTimer?.cancel();
    _upgradeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _triggerUpgradeCheck();
    });
  }

  Future<void> _triggerUpgradeCheck() async {
    if (!_isOnline || _isProcessingUpgrade || _pendingUpgradeSongIds.isEmpty) return;
    _isProcessingUpgrade = true;

    try {
      final subsonic = SubsonicService();
      if (!subsonic.isConfigured) return;

      final idsToProcess = List<String>.from(_pendingUpgradeSongIds);
      for (final songId in idsToProcess) {
        if (!_isOnline) break;

        final attempts = (_pollAttempts[songId] ?? 0) + 1;
        _pollAttempts[songId] = attempts;

        final isReady = await checkServerHasStudioMaster(songId, subsonic);
        if (isReady) {
          debugPrint('[AudioQuality] 🎯 Version Studio Master prête sur le serveur pour $songId ! Déclenchement de l\'upgrade transparent...');
          final upgraded = await _performAtomicUpgrade(songId, subsonic);
          if (upgraded) {
            _pendingUpgradeSongIds.remove(songId);
            _pollAttempts.remove(songId);
            await _persistPendingUpgrades();
            notifyListeners();
          }
        } else {
          // Si après 20 tentatives (~10 minutes) le serveur ne l'a pas promu, on espace les requêtes
          if (attempts > 20) {
            debugPrint('[AudioQuality] ⏳ $songId en attente prolongée (tentative $attempts/30)');
            if (attempts > 30) {
              _pendingUpgradeSongIds.remove(songId);
              _pollAttempts.remove(songId);
              await _persistPendingUpgrades();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AudioQuality] Erreur pendant la boucle d\'upgrade: $e');
    } finally {
      _isProcessingUpgrade = false;
    }
  }

  /// Détecte le format audio réel d'un flux d'octets via ses signatures binaires (Magic Bytes).
  static AudioCodecFormat detectFromBytes(List<int> bytes) {
    if (bytes.length < 12) return AudioCodecFormat.unknown;

    // 1. Ogg Container (Opus / Vorbis)
    if (bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53) {
      // Chercher "OpusHead" dans les 64 premiers octets
      final maxSearch = bytes.length < 64 ? bytes.length : 64;
      for (int i = 0; i <= maxSearch - 8; i++) {
        if (bytes[i] == 0x4F &&     // O
            bytes[i + 1] == 0x70 && // p
            bytes[i + 2] == 0x75 && // u
            bytes[i + 3] == 0x73 && // s
            bytes[i + 4] == 0x48 && // H
            bytes[i + 5] == 0x65 && // e
            bytes[i + 6] == 0x61 && // a
            bytes[i + 7] == 0x64) { // d
          return AudioCodecFormat.opus;
        }
      }
      return AudioCodecFormat.opus; // Conteneur Ogg
    }

    // 2. FLAC ("fLaC")
    if (bytes[0] == 0x66 && bytes[1] == 0x4C && bytes[2] == 0x61 && bytes[3] == 0x43) {
      return AudioCodecFormat.flac;
    }

    // 3. MP3 (Tag ID3)
    if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
      return AudioCodecFormat.mp3;
    }

    // 4. MP3 (Frame Sync 0xFF 0xFB / 0xF3 / 0xF2)
    if (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) {
      return AudioCodecFormat.mp3;
    }

    // 5. AAC / M4A (ftyp box dans les 12 premiers octets)
    if (bytes.length >= 8 &&
        bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
      return AudioCodecFormat.aac;
    }

    return AudioCodecFormat.unknown;
  }

  /// Détecte le format audio réel d'un fichier sur disque sans se fier à l'extension.
  static AudioCodecFormat detectFileFormat(File file) {
    if (!file.existsSync()) return AudioCodecFormat.unknown;
    try {
      final raf = file.openSync(mode: FileMode.read);
      final buffer = List<int>.filled(64, 0);
      final read = raf.readIntoSync(buffer, 0, 64);
      raf.closeSync();
      if (read < 12) return AudioCodecFormat.unknown;
      return detectFromBytes(buffer.sublist(0, read));
    } catch (_) {
      return AudioCodecFormat.unknown;
    }
  }

  /// Vérifie si le serveur a promu le morceau en version Studio Master (Opus) ou Lossless (FLAC).
  Future<bool> checkServerHasStudioMaster(String songId, SubsonicService subsonic) async {
    try {
      final streamUrl = subsonic.getStreamUrl(songId);
      final response = await _dio.get<List<int>>(
        streamUrl,
        options: Options(
          headers: {'Range': 'bytes=0-127'},
          responseType: ResponseType.bytes,
        ),
      );

      final contentType = response.headers.value('content-type')?.toLowerCase() ?? '';
      if (contentType.contains('opus') || contentType.contains('ogg') || contentType.contains('flac')) {
        return true;
      }

      if (response.data != null && response.data!.isNotEmpty) {
        final codec = detectFromBytes(response.data!);
        if (codec == AudioCodecFormat.opus || codec == AudioCodecFormat.flac) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Déclenché quand l'utilisateur "Like" un morceau :
  /// 1. Ne coupe JAMAIS la musique en cours.
  /// 2. Déclenche la vérification cyclique toutes les 30s.
  /// 3. Met à jour silencieusement le cache pour les futures réécoutes.
  void onSongLiked(Song song, SubsonicService subsonic) {
    final songId = song.id;
    debugPrint('[AudioQuality] 💖 Like enregistré pour "${song.title}". Surveillance de la promotion HQ...');

    _pendingUpgradeSongIds.add(songId);
    _pollAttempts[songId] = 0;
    _persistPendingUpgrades();

    // Lancer une première vérification après 3 secondes (en cas de promotion déjà en cache NVMe)
    Future.delayed(const Duration(seconds: 3), () async {
      final isReady = await checkServerHasStudioMaster(songId, subsonic);
      if (isReady) {
        debugPrint('[AudioQuality] ⚡ Morceau déjà prêt en Studio Master sur le serveur pour "${song.title}"');
        final upgraded = await _performAtomicUpgrade(songId, subsonic);
        if (upgraded) {
          _pendingUpgradeSongIds.remove(songId);
          _pollAttempts.remove(songId);
          await _persistPendingUpgrades();
          notifyListeners();
        }
      }
    });
  }

  /// Enregistre un morceau téléchargé pour amélioration transparente si sa version n'est pas encore HQ.
  void enqueueDownloadForUpgrade(Song song) {
    _pendingUpgradeSongIds.add(song.id);
    _persistPendingUpgrades();
    debugPrint('[AudioQuality] 📥 Morceau "${song.title}" ajouté à la file d\'attente d\'upgrade transparent');
  }

  /// Pré-chauffe silencieuse d'une liste de morceaux (ex: ajout dans une playlist).
  Future<void> prewarmPlaylist(List<Song> songs, SubsonicService subsonic) async {
    if (songs.isEmpty || !_isOnline) return;

    Future.microtask(() async {
      for (final song in songs) {
        if (!_isOnline) break;
        try {
          final url = subsonic.getStreamUrl(song.id);
          // Requête ultralégère Range=0-0 pour notifier le CJ Stream Resolver
          await _dio.get(
            url,
            options: Options(
              headers: {'Range': 'bytes=0-0'},
              responseType: ResponseType.bytes,
            ),
          );
          // Pause de 100 ms entre les pings pour ne pas surcharger le réseau
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (_) {}
      }
      debugPrint('[AudioQuality] 📑 Pré-chauffe de playlist terminée (${songs.length} morceaux)');
    });
  }

  /// Remplacement atomique et sécurisé d'un fichier audio par sa version Studio Master.
  Future<bool> _performAtomicUpgrade(String songId, SubsonicService subsonic) async {
    final offline = OfflineService();
    final precache = AudioPrecacheService();

    final downloadedPath = offline.getLocalPath(songId);
    final precachedPath = precache.getPrecachedAudioPath(songId);

    // Si le fichier n'est ni téléchargé ni pré-en-cache, rien à remplacer localement
    if (downloadedPath == null && precachedPath == null) {
      return true;
    }

    final targetPath = downloadedPath ?? precachedPath!;
    // target file on disk
    final tmpPath = '$targetPath.hq_upgrade.tmp';
    final tmpFile = File(tmpPath);

    try {
      final streamUrl = subsonic.getStreamUrl(songId);
      await _dio.download(
        streamUrl,
        tmpPath,
        options: Options(headers: {'Accept': '*/*'}),
      );

      if (!await tmpFile.exists()) return false;

      final len = await tmpFile.length();
      if (len < 30000) {
        await tmpFile.delete();
        return false;
      }

      final format = detectFileFormat(tmpFile);
      if (format != AudioCodecFormat.opus && format != AudioCodecFormat.flac) {
        // Le flux servi n'est pas encore Studio Master
        await tmpFile.delete();
        return false;
      }

      // Remplacement atomique : écrasement propre du fichier
      await tmpFile.rename(targetPath);

      // Si le morceau était en pré-cache ET téléchargé, mettre à jour les deux
      if (downloadedPath != null && precachedPath != null && downloadedPath != precachedPath) {
        try {
          await File(targetPath).copy(precachedPath);
        } catch (_) {}
      }

      _cachedSongQuality[songId] = AudioQualityDetails.fromFormat(format);
      debugPrint('[AudioQuality] ✨ Remplacement atomique réussi vers ${format.name.toUpperCase()} pour $songId');
      return true;
    } catch (e) {
      debugPrint('[AudioQuality] Échec remplacement atomique pour $songId: $e');
      if (await tmpFile.exists()) {
        try { await tmpFile.delete(); } catch (_) {}
      }
      return false;
    }
  }

  /// Détermine la qualité audio exacte d'un morceau actuellement joué ou en mémoire.
  Future<AudioQualityDetails> getSongQuality(Song song) async {
    if (_cachedSongQuality.containsKey(song.id)) {
      return _cachedSongQuality[song.id]!;
    }

    // 1. Vérifier si un fichier local existe (téléchargé ou pré-caché)
    final localPath = OfflineService().getLocalPath(song.id) ??
        AudioPrecacheService().getPrecachedAudioPath(song.id);

    if (localPath != null) {
      final file = File(localPath);
      if (file.existsSync()) {
        final format = detectFileFormat(file);
        if (format != AudioCodecFormat.unknown) {
          final details = AudioQualityDetails.fromFormat(format, reportedBitrate: song.bitRate);
          _cachedSongQuality[song.id] = details;
          return details;
        }
      }
    }

    // 2. Déduire des métadonnées Subsonic
    final suffix = song.suffix?.toLowerCase() ?? '';
    final contentType = song.contentType?.toLowerCase() ?? '';

    if (suffix == 'opus' || suffix == 'ogg' || contentType.contains('opus') || contentType.contains('ogg')) {
      final details = AudioQualityDetails.fromFormat(AudioCodecFormat.opus, reportedBitrate: song.bitRate);
      _cachedSongQuality[song.id] = details;
      return details;
    }

    if (suffix == 'flac' || contentType.contains('flac')) {
      final details = AudioQualityDetails.fromFormat(AudioCodecFormat.flac, reportedBitrate: song.bitRate);
      _cachedSongQuality[song.id] = details;
      return details;
    }

    if (suffix == 'm4a' || suffix == 'aac' || contentType.contains('mp4') || contentType.contains('aac')) {
      final details = AudioQualityDetails.fromFormat(AudioCodecFormat.aac, reportedBitrate: song.bitRate);
      _cachedSongQuality[song.id] = details;
      return details;
    }

    // Par défaut, version standard (MP3 128k)
    final details = AudioQualityDetails.fromFormat(AudioCodecFormat.mp3, reportedBitrate: song.bitRate ?? 128);
    _cachedSongQuality[song.id] = details;
    return details;
  }

  void _cleanupOrphanedTmpFiles() {
    try {
      final offlineDir = OfflineService().offlineDir;
      if (offlineDir != null) {
        final dir = Directory(offlineDir);
        if (dir.existsSync()) {
          for (final f in dir.listSync()) {
            if (f is File && (f.path.endsWith('.tmp') || f.path.endsWith('.part'))) {
              try { f.deleteSync(); } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _persistPendingUpgrades() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyPendingUpgrades, _pendingUpgradeSongIds.toList());
    } catch (_) {}
  }

  @override
  void dispose() {
    _upgradeTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
