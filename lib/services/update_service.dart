import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ReleaseAsset {
  final String name;
  final String browserDownloadUrl;
  final int? size;

  const ReleaseAsset({
    required this.name,
    required this.browserDownloadUrl,
    this.size,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) => ReleaseAsset(
        name: json['name'] as String? ?? '',
        browserDownloadUrl: json['browser_download_url'] as String? ?? '',
        size: json['size'] as int?,
      );

  String get formattedSize {
    if (size == null || size! <= 0) return '';
    final mb = size! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class ReleaseInfo {
  final String version;
  final String tagName;
  final String htmlUrl;
  final String body;
  final List<String> releaseNotes;
  final bool mandatory;
  final String? directApkUrl;
  final String? directIpaUrl;
  final String? sidestoreInstallUrl;
  final List<ReleaseAsset> assets;

  const ReleaseInfo({
    required this.version,
    required this.tagName,
    required this.htmlUrl,
    required this.body,
    this.releaseNotes = const [],
    this.mandatory = false,
    this.directApkUrl,
    this.directIpaUrl,
    this.sidestoreInstallUrl,
    required this.assets,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    // Check if custom server version.json format
    if (json.containsKey('android') || json.containsKey('ios') || json.containsKey('release_notes')) {
      final v = (json['version'] as String? ?? '1.0.0').replaceFirst(RegExp(r'^v'), '');
      final notesList = (json['release_notes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final notesBody = notesList.map((e) => '• $e').join('\n');
      
      final androidMap = json['android'] as Map<String, dynamic>?;
      final iosMap = json['ios'] as Map<String, dynamic>?;
      
      final apkUrl = androidMap?['download_url'] as String?;
      final ipaUrl = iosMap?['download_url'] as String?;
      final sidestoreUrl = iosMap?['sidestore_install_url'] as String? ?? 
          (ipaUrl != null ? 'sidestore://install?url=$ipaUrl' : null);

      final assets = <ReleaseAsset>[];
      if (apkUrl != null) {
        assets.add(ReleaseAsset(name: 'Musly.apk', browserDownloadUrl: apkUrl));
      }
      if (ipaUrl != null) {
        assets.add(ReleaseAsset(name: 'Musly.ipa', browserDownloadUrl: ipaUrl));
      }

      return ReleaseInfo(
        version: v,
        tagName: 'v$v',
        htmlUrl: 'https://music.corentinjanin.fr',
        body: notesBody.isNotEmpty ? notesBody : (json['description'] as String? ?? ''),
        releaseNotes: notesList,
        mandatory: json['mandatory'] as bool? ?? false,
        directApkUrl: apkUrl,
        directIpaUrl: ipaUrl,
        sidestoreInstallUrl: sidestoreUrl,
        assets: assets,
      );
    }

    // Fallback: GitHub Releases format
    final tag = json['tag_name'] as String? ?? '';
    final bodyStr = json['body'] as String? ?? '';
    final extractedNotes = bodyStr
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('- ') || l.startsWith('* ') || l.startsWith('• '))
        .map((l) => l.substring(2).trim())
        .toList();

    return ReleaseInfo(
      version: tag.replaceFirst(RegExp(r'^v'), ''),
      tagName: tag,
      htmlUrl: json['html_url'] as String? ?? '',
      body: bodyStr,
      releaseNotes: extractedNotes.isNotEmpty ? extractedNotes : [bodyStr],
      mandatory: false,
      assets: (json['assets'] as List<dynamic>?)
              ?.map((a) => ReleaseAsset.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  ReleaseAsset? get targetAsset {
    if (!kIsWeb && Platform.isAndroid && directApkUrl != null) {
      return ReleaseAsset(name: 'Musly.apk', browserDownloadUrl: directApkUrl!);
    }
    if (!kIsWeb && Platform.isIOS && directIpaUrl != null) {
      return ReleaseAsset(name: 'Musly.ipa', browserDownloadUrl: directIpaUrl!);
    }

    if (assets.isEmpty) return null;

    if (!kIsWeb && Platform.isAndroid) {
      return assets.firstWhere(
        (a) => a.name.endsWith('.apk'),
        orElse: () => assets.first,
      );
    }

    if (!kIsWeb && Platform.isIOS) {
      return assets.firstWhere(
        (a) => a.name.endsWith('.ipa'),
        orElse: () => assets.first,
      );
    }

    if (!kIsWeb && Platform.isWindows) {
      return assets.firstWhere(
        (a) =>
            a.name.toLowerCase().endsWith('-setup.exe') ||
            a.name.toLowerCase().endsWith('.exe'),
        orElse: () => assets.first,
      );
    }

    if (!kIsWeb && Platform.isMacOS) {
      return assets.firstWhere(
        (a) => a.name.endsWith('.dmg'),
        orElse: () => assets.first,
      );
    }

    if (!kIsWeb && Platform.isLinux) {
      return assets.firstWhere(
        (a) =>
            a.name.contains('linux') ||
            a.name.endsWith('.tar.gz') ||
            a.name.endsWith('.AppImage'),
        orElse: () => assets.first,
      );
    }

    return assets.isNotEmpty ? assets.first : null;
  }
}

class UpdateService {
  static String _currentVersion = '2.10.3';
  static String get currentVersion => _currentVersion;

  /// Load real package version dynamically from platform bundle
  static Future<void> initialize() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        _currentVersion = info.version;
        _dio.options.headers['User-Agent'] = 'Musly-App/$_currentVersion';
      }
    } catch (e) {
      debugPrint('[UpdateService] PackageInfo load error: $e');
    }
  }

  // Primary: CJ Music server update endpoint
  static const String _primaryServerUrl =
      'https://music.corentinjanin.fr/updates/version.json';

  // Fallback: GitHub releases
  static const String _fallbackGithubUrl =
      'https://api.github.com/repos/dddevid/Musly/releases/latest';

  static const String _skippedVersionKey = 'skipped_update_version';
  static const String _lastLaterTimestampKey = 'last_update_later_timestamp';
  static const String _lastSeenVersionKey = 'last_seen_app_version';
  static const String _cachedReleaseNotesKey = 'cached_release_notes_for_version_';

  static bool _hasCheckedStartup = false;
  static bool get hasCheckedStartup => _hasCheckedStartup;
  static void markStartupChecked() => _hasCheckedStartup = true;
  static void resetStartupCheck() => _hasCheckedStartup = false;

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Musly-App/$currentVersion',
      },
    ),
  );

  /// Get the dynamic release notes for current version (fetched from server or cached)
  static Future<List<String>> getWhatsNewNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('$_cachedReleaseNotesKey$currentVersion');
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }

      // Try fetching current version notes from server directly if not cached
      final response = await _dio.get<dynamic>(
        _primaryServerUrl,
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200 && response.data != null) {
        Map<String, dynamic> data;
        if (response.data is String) {
          data = jsonDecode(response.data as String) as Map<String, dynamic>;
        } else {
          data = response.data as Map<String, dynamic>;
        }
        final notes = (data['release_notes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        if (notes.isNotEmpty) {
          await prefs.setStringList('$_cachedReleaseNotesKey$currentVersion', notes);
          return notes;
        }
      }
    } catch (_) {}

    // Fallback notes if offline
    return [
      'Améliorations des performances et fluidité accrue',
      'Optimisation de la lecture haute fidélité Opus',
      'Nettoyage et gestion intelligente du stockage',
    ];
  }

  /// Check whether we should show the "What's New" recap dialog on first open after update
  static Future<bool> shouldShowWhatsNew() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getString(_lastSeenVersionKey);
      if (lastSeen == null) {
        // First run ever: mark current version as seen so we don't spam
        await prefs.setString(_lastSeenVersionKey, currentVersion);
        return false;
      }
      if (_isNewer(currentVersion, lastSeen)) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Cache the upcoming release notes when an update is detected or initiated
  static Future<void> saveReleaseNotesForVersion(String version, List<String> notes) async {
    try {
      if (notes.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('$_cachedReleaseNotesKey$version', notes);
    } catch (_) {}
  }

  /// Mark current version as acknowledged in "What's New" dialog, and clean up any leftover installer APK/IPA
  static Future<void> markWhatsNewSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSeenVersionKey, currentVersion);
      // Clean up any remaining installer packages from previous installations
      await cleanupOldInstallers();
    } catch (_) {}
  }

  /// Check for update from primary server, falling back to GitHub
  static Future<ReleaseInfo?> checkForUpdate({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();

    // Check "Plus tard" snooze: if user snoozed within the last 24h and not forced
    if (!force) {
      final lastLater = prefs.getInt(_lastLaterTimestampKey);
      if (lastLater != null) {
        final elapsed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastLater));
        if (elapsed < const Duration(hours: 24)) {
          debugPrint('UpdateService: Snoozed ("Plus tard") for ${24 - elapsed.inHours}h remaining.');
          return null;
        }
      }
    }

    // 1. Try Primary Server (music.corentinjanin.fr/updates/version.json)
    try {
      final response = await _dio.get<dynamic>(
        _primaryServerUrl,
        options: Options(responseType: ResponseType.json),
      );

      if (response.statusCode == 200 && response.data != null) {
        Map<String, dynamic> data;
        if (response.data is String) {
          data = jsonDecode(response.data as String) as Map<String, dynamic>;
        } else {
          data = response.data as Map<String, dynamic>;
        }

        final release = ReleaseInfo.fromJson(data);
        if (_isNewer(release.version, currentVersion)) {
          // Pre-cache release notes for this upcoming version
          if (release.releaseNotes.isNotEmpty) {
            await saveReleaseNotesForVersion(release.version, release.releaseNotes);
          }

          if (!force && !release.mandatory) {
            final skippedVersion = prefs.getString(_skippedVersionKey);
            if (skippedVersion == release.version) {
              return null;
            }
          }
          return release;
        }
      }
    } catch (e) {
      debugPrint('UpdateService: Primary server check failed ($e), trying GitHub...');
    }

    // 2. Fallback to GitHub releases
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _fallbackGithubUrl,
        options: Options(
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        ),
      );
      final data = response.data;
      if (data != null) {
        final release = ReleaseInfo.fromJson(data);
        if (_isNewer(release.version, currentVersion)) {
          if (!force) {
            final skippedVersion = prefs.getString(_skippedVersionKey);
            if (skippedVersion == release.version) {
              return null;
            }
          }
          return release;
        }
      }
    } catch (e) {
      debugPrint('UpdateService: GitHub check failed – $e');
    }

    return null;
  }

  /// User clicked "Plus tard": snooze prompt for 24 hours
  static Future<void> snoozeUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastLaterTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// User chose to ignore/skip this specific version completely
  static Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedVersionKey, version);
  }

  static bool isNewerVersion(String remote, String current) => _isNewer(remote, current);

  static bool _isNewer(String remote, String current) {
    try {
      List<int> parse(String v) =>
          v.split('.').map((p) => int.tryParse(p.split('+').first.replaceAll(RegExp(r'[^\d]'), '')) ?? 0).toList();

      final r = parse(remote);
      final c = parse(current);
      final len = r.length > c.length ? r.length : c.length;
      while (r.length < len) {
        r.add(0);
      }
      while (c.length < len) {
        c.add(0);
      }

      for (int i = 0; i < len; i++) {
        if (r[i] > c[i]) return true;
        if (r[i] < c[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Delete any cached installer packages from previous versions to save disk space
  static Future<void> cleanupOldInstallers({String? currentTargetFile}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!tempDir.existsSync()) return;

      final entities = tempDir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final name = entity.path.split(Platform.pathSeparator).last.toLowerCase();
          // Match any installer or partial update files
          final isInstaller = name.endsWith('.apk') ||
              name.endsWith('.part') ||
              name.endsWith('.ipa') ||
              name.endsWith('.exe') ||
              name.endsWith('.dmg') ||
              name.endsWith('.appimage');

          if (isInstaller) {
            // Keep the current target file if it matches
            if (currentTargetFile != null && entity.path == currentTargetFile) {
              continue;
            }
            try {
              entity.deleteSync();
              debugPrint('UpdateService: Cleaned up old update cache: ${entity.path}');
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('UpdateService: cleanupOldInstallers error: $e');
    }
  }

  /// Check whether the target asset has already been fully downloaded
  static Future<String?> getExistingDownloadedAssetPath(ReleaseAsset asset) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = asset.name.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final filePath = '${tempDir.path}/$sanitizedName';
      final file = File(filePath);

      if (file.existsSync()) {
        final length = file.lengthSync();
        if (asset.size != null && asset.size! > 0) {
          if (length == asset.size) return filePath;
        } else if (length > 1024 * 1024) {
          // If size not known but file > 1MB, considered valid downloaded installer
          return filePath;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Launch update process: on iOS, trigger SideStore url scheme; on Android/Desktop, download file
  static Future<bool> installUpdate(
    ReleaseInfo release, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!kIsWeb && Platform.isIOS) {
      final sidestoreUri = release.sidestoreInstallUrl ??
          (release.directIpaUrl != null ? 'sidestore://install?url=${release.directIpaUrl}' : null);

      if (sidestoreUri != null) {
        final uri = Uri.parse(sidestoreUri);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      // If SideStore scheme cannot be opened, open direct download URL
      if (release.directIpaUrl != null) {
        final uri = Uri.parse(release.directIpaUrl!);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      return false;
    }

    // Android & Desktop: Check if already downloaded first
    final asset = release.targetAsset;
    if (asset == null) {
      return await openReleasePage(release);
    }

    // Check if this specific version is already present and valid
    final existingPath = await getExistingDownloadedAssetPath(asset);
    if (existingPath != null) {
      debugPrint('UpdateService: Installer for v${release.version} already cached at $existingPath. Reusing immediately without re-downloading.');
      onProgress?.call(asset.size ?? 1, asset.size ?? 1);
      return await launchInstallerOrFile(existingPath, release: release);
    }

    // If not, clean up any previous version's old installer files so cache stays at 0 MB extra
    await cleanupOldInstallers();

    final downloadedPath = await downloadAsset(
      asset,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );

    return await launchInstallerOrFile(downloadedPath, release: release);
  }

  static Future<String> downloadAsset(
    ReleaseAsset asset, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final sanitizedName = asset.name.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final filePath = '${tempDir.path}/$sanitizedName';
    final targetFile = File(filePath);

    if (targetFile.existsSync() && asset.size != null && asset.size! > 0) {
      if (targetFile.lengthSync() == asset.size) {
        onProgress?.call(asset.size!, asset.size!);
        return filePath;
      }
    }

    final partPath = '$filePath.part';
    final partFile = File(partPath);

    final downloadDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 15),
        headers: {
          'Accept-Encoding': 'identity',
          'User-Agent': 'Musly-App/$currentVersion',
        },
      ),
    );

    int existingLength = 0;
    if (partFile.existsSync()) {
      existingLength = partFile.lengthSync();
      if (asset.size != null && existingLength >= asset.size!) {
        try {
          partFile.deleteSync();
        } catch (_) {}
        existingLength = 0;
      }
    }

    if (existingLength > 0 && asset.size != null) {
      try {
        final sink = partFile.openSync(mode: FileMode.append);
        final response = await downloadDio.get<ResponseBody>(
          asset.browserDownloadUrl,
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Range': 'bytes=$existingLength-'},
          ),
          cancelToken: cancelToken,
        );

        final statusCode = response.statusCode ?? 200;
        if (statusCode == 206) {
          int received = existingLength;
          final total = asset.size!;
          onProgress?.call(received, total);

          await for (final chunk in response.data!.stream) {
            if (cancelToken?.isCancelled == true) {
              sink.closeSync();
              throw DioException(
                requestOptions: response.requestOptions,
                type: DioExceptionType.cancel,
              );
            }
            sink.writeFromSync(chunk);
            received += chunk.length;
            onProgress?.call(received, total);
          }
          sink.closeSync();

          try {
            if (targetFile.existsSync()) targetFile.deleteSync();
            partFile.renameSync(filePath);
          } catch (_) {
            partFile.copySync(filePath);
            try {
              partFile.deleteSync();
            } catch (_) {}
          }
          return filePath;
        } else {
          sink.closeSync();
          try {
            partFile.deleteSync();
          } catch (_) {}
        }
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
        if (partFile.existsSync()) {
          try {
            partFile.deleteSync();
          } catch (_) {}
        }
      }
    }

    await downloadDio.download(
      asset.browserDownloadUrl,
      partPath,
      onReceiveProgress: (rec, total) {
        onProgress?.call(rec, total > 0 ? total : (asset.size ?? -1));
      },
      cancelToken: cancelToken,
      deleteOnError: true,
    );

    try {
      if (targetFile.existsSync()) targetFile.deleteSync();
      File(partPath).renameSync(filePath);
    } catch (_) {
      File(partPath).copySync(filePath);
      try {
        File(partPath).deleteSync();
      } catch (_) {}
    }

    return filePath;
  }

  static const MethodChannel _apkChannel = MethodChannel('com.devid.musly/apk_installer');

  static Future<bool> launchInstallerOrFile(
    String filePath, {
    ReleaseInfo? release,
  }) async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final success = await _apkChannel.invokeMethod<bool>(
            'installApk',
            {'filePath': filePath},
          );
          if (success == true) return true;
        } catch (e) {
          debugPrint('UpdateService: Android native install error: $e');
        }
        final fileUri = Uri.file(filePath);
        if (await canLaunchUrl(fileUri)) {
          return await launchUrl(fileUri);
        }
        return false;
      }

      if (!kIsWeb && Platform.isWindows) {
        final winPath = filePath.replaceAll('/', '\\');
        await Process.start(winPath, [], runInShell: false);
        return true;
      }

      if (!kIsWeb && Platform.isMacOS) {
        await Process.start('open', [filePath]);
        return true;
      }

      if (!kIsWeb && Platform.isLinux) {
        try {
          await Process.run('chmod', ['+x', filePath]);
        } catch (_) {}
        await Process.start('xdg-open', [filePath]);
        return true;
      }

      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('UpdateService: failed to launch file: $e');
    }
    return false;
  }

  static Future<bool> openReleasePage(ReleaseInfo release) async {
    final uri = Uri.parse(release.htmlUrl);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static String stripMarkdown(String md) {
    return md
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
        .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'\*(.*?)\*'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'`{1,3}(.*?)`{1,3}'), (m) => m.group(1) ?? '')
        .replaceAllMapped(
            RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1) ?? '')
        .replaceAll(RegExp(r'^---+$', multiLine: true), '─────────────')
        .trim();
  }
}
