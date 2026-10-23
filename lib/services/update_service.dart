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
  final List<ReleaseAsset> assets;

  const ReleaseInfo({
    required this.version,
    required this.tagName,
    required this.htmlUrl,
    required this.body,
    required this.assets,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String? ?? '';
    return ReleaseInfo(
      version: tag.replaceFirst(RegExp(r'^v'), ''),
      tagName: tag,
      htmlUrl: json['html_url'] as String? ?? '',
      body: json['body'] as String? ?? '',
      assets: (json['assets'] as List<dynamic>?)
              ?.map((a) => ReleaseAsset.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  ReleaseAsset? get targetAsset {
    if (assets.isEmpty) return null;

    if (!kIsWeb && Platform.isAndroid) {
      final apk = assets.firstWhere(
        (a) => a.name.endsWith('.apk'),
        orElse: () => assets.first,
      );
      return apk;
    }

    if (!kIsWeb && Platform.isWindows) {
      final exe = assets.firstWhere(
        (a) =>
            a.name.toLowerCase().endsWith('-setup.exe') ||
            a.name.toLowerCase().endsWith('.exe'),
        orElse: () => assets.first,
      );
      return exe;
    }

    if (!kIsWeb && Platform.isMacOS) {
      final dmg = assets.firstWhere(
        (a) => a.name.endsWith('.dmg'),
        orElse: () => assets.first,
      );
      return dmg;
    }

    if (!kIsWeb && Platform.isLinux) {
      final linux = assets.firstWhere(
        (a) =>
            a.name.contains('linux') ||
            a.name.endsWith('.tar.gz') ||
            a.name.endsWith('.AppImage'),
        orElse: () => assets.first,
      );
      return linux;
    }

    return assets.isNotEmpty ? assets.first : null;
  }
}

class UpdateService {
  static const String currentVersion = '2.0.3';

  static const String _apiUrl =
      'https://api.github.com/repos/dddevid/Musly/releases/latest';

  static const String _skippedVersionKey = 'skipped_update_version';
  static const String _lastCheckTimestampKey = 'last_update_check_timestamp';

  static bool _hasCheckedStartup = false;
  static bool get hasCheckedStartup => _hasCheckedStartup;
  static void markStartupChecked() => _hasCheckedStartup = true;
  static void resetStartupCheck() => _hasCheckedStartup = false;

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'Musly-App/$currentVersion',
      },
    ),
  );

  static Future<ReleaseInfo?> checkForUpdate({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final response = await _dio.get<Map<String, dynamic>>(_apiUrl);
      final data = response.data;
      if (data == null) return null;

      await prefs.setInt(
          _lastCheckTimestampKey, DateTime.now().millisecondsSinceEpoch);

      final release = ReleaseInfo.fromJson(data);
      if (_isNewer(release.version, currentVersion)) {
        if (!force) {
          final skippedVersion = prefs.getString(_skippedVersionKey);
          if (skippedVersion == release.version) {
            debugPrint(
                'UpdateService: version ${release.version} was skipped by user');
            return null;
          }
        }
        return release;
      }
      return null;
    } catch (e) {
      debugPrint('UpdateService: check failed – $e');
      return null;
    }
  }

  static Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedVersionKey, version);
  }

  static bool isNewerVersion(String remote, String current) =>
      _isNewer(remote, current);

  static bool _isNewer(String remote, String current) {
    try {
      List<int> parse(String v) =>
          v.split('.').map((p) => int.tryParse(p) ?? 0).toList();

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

  static Future<String> downloadAsset(
    ReleaseAsset asset, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final sanitizedName = asset.name.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final filePath = '${tempDir.path}/$sanitizedName';
    final targetFile = File(filePath);

    // If file already exists and is complete, reuse it immediately
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
            if (targetFile.existsSync()) {
              targetFile.deleteSync();
            }
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
        if (e is DioException && e.type == DioExceptionType.cancel) {
          rethrow;
        }
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
      if (targetFile.existsSync()) {
        targetFile.deleteSync();
      }
      File(partPath).renameSync(filePath);
    } catch (_) {
      File(partPath).copySync(filePath);
      try {
        File(partPath).deleteSync();
      } catch (_) {}
    }

    return filePath;
  }

  static const MethodChannel _apkChannel =
      MethodChannel('com.devid.musly/apk_installer');

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

  static Future<bool> openAssetDownloadUrl(ReleaseAsset asset) async {
    final uri = Uri.parse(asset.browserDownloadUrl);
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
