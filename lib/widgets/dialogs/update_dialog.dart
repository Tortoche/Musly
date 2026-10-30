import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final ReleaseInfo release;

  const UpdateDialog({
    super.key,
    required this.release,
  });

  static Future<void> show(BuildContext context, ReleaseInfo release) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !release.mandatory,
      builder: (context) => UpdateDialog(release: release),
    );
  }

  static Future<void> checkAndShow(BuildContext context) async {
    if (UpdateService.hasCheckedStartup) return;
    UpdateService.markStartupChecked();

    // 1. First check if a "What's New" dialog should be displayed (first launch after an update)
    final showWhatsNew = await UpdateService.shouldShowWhatsNew();
    if (showWhatsNew && context.mounted) {
      await showWhatsNewDialog(context);
      return;
    }

    // 2. Otherwise check if a new update is available
    try {
      final release = await UpdateService.checkForUpdate();
      if (release != null && context.mounted) {
        await show(context, release);
      }
    } catch (e) {
      debugPrint('UpdateDialog: startup check error – $e');
    }
  }

  /// Single-time "What's New" recap dialog shown after updating the app
  static Future<void> showWhatsNewDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    const highlights = [
      (
        CupertinoIcons.waveform_path_badge_plus,
        'Qualité Studio Master & Hi-Res',
        'Lecture et téléchargements automatiques au format Opus 48 kHz ultra-haute fidélité.'
      ),
      (
        CupertinoIcons.flame_fill,
        'Nouveau Thème Pure OLED',
        'Noir absolu #000000, économie de batterie et contraste pur fidèle au design Apple.'
      ),
      (
        CupertinoIcons.sparkles,
        'Mises à jour fluides en 1 clic',
        'Mises à jour transparentes intégrées pour Android et iOS avec SideStore.'
      ),
    ];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF09090B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: isDark ? const BorderSide(color: Color(0x1FFFFFFF), width: 0.5) : BorderSide.none,
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.sparkles,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Bienvenue dans Musly v${UpdateService.currentVersion}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Voici ce qui a été amélioré pour vous :',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF8E8E93) : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...highlights.map((h) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(h.$1, color: primaryColor, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h.$2,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    h.$3,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? const Color(0xFF8E8E93) : Colors.black54,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        await UpdateService.markWhatsNewSeen();
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'C\'est parti !',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatusText = '';
  CancelToken? _cancelToken;
  String? _errorMessage;
  bool _isAlreadyDownloaded = false;

  @override
  void initState() {
    super.initState();
    _checkExistingDownload();
  }

  Future<void> _checkExistingDownload() async {
    final asset = widget.release.targetAsset;
    if (asset != null) {
      final existing = await UpdateService.getExistingDownloadedAssetPath(asset);
      if (existing != null && mounted) {
        setState(() {
          _isAlreadyDownloaded = true;
          _downloadProgress = 1.0;
          _downloadStatusText = 'Téléchargé et prêt';
        });
      }
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  void _onDownloadProgress(int received, int total) {
    if (!mounted) return;
    if (total > 0) {
      final fraction = (received / total).clamp(0.0, 1.0);
      final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
      final totMb = (total / (1024 * 1024)).toStringAsFixed(1);
      final percent = (fraction * 100).toInt();
      setState(() {
        _downloadProgress = fraction;
        _downloadStatusText = '$percent% ($recMb / $totMb Mo)';
      });
    }
  }

  Future<void> _triggerUpdate() async {
    // On iOS, redirect directly to SideStore or browser
    if (!kIsWeb && Platform.isIOS) {
      await UpdateService.installUpdate(widget.release);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatusText = '0%';
      _errorMessage = null;
      _cancelToken = CancelToken();
    });

    try {
      final success = await UpdateService.installUpdate(
        widget.release,
        onProgress: _onDownloadProgress,
        cancelToken: _cancelToken,
      );

      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Impossible de lancer l\'installateur.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && e.type == DioExceptionType.cancel) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
          _downloadStatusText = '';
        });
        return;
      }
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Erreur de téléchargement : $e';
      });
    }
  }

  Future<void> _onLaterPressed() async {
    await UpdateService.snoozeUpdate();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final l10n = AppLocalizations.of(context);
    final release = widget.release;

    final notes = release.releaseNotes.isNotEmpty
        ? release.releaseNotes
        : (release.body.isNotEmpty ? [release.body] : ['Améliorations générales des performances et de la stabilité.']);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: isDark ? const BorderSide(color: Color(0x1FFFFFFF), width: 0.5) : BorderSide.none,
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      CupertinoIcons.arrow_down_circle_fill,
                      color: primaryColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.updateAvailable ?? 'Mise à jour disponible',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              'v${UpdateService.currentVersion}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF8E8E93) : Colors.black45,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'v${release.version}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Nouveautés :',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141417) : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(14),
                    border: isDark ? Border.all(color: const Color(0x14FFFFFF), width: 0.5) : null,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '•  ',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              notes[index],
                              style: TextStyle(
                                fontSize: 13.5,
                                color: isDark ? const Color(0xFFE5E5EA) : Colors.black87,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_isDownloading) ...[
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    backgroundColor: isDark ? const Color(0xFF242428) : const Color(0xFFE5E5EA),
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _downloadStatusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF8E8E93) : Colors.black54,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  if (!release.mandatory && !_isDownloading)
                    Expanded(
                      child: TextButton(
                        onPressed: _onLaterPressed,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Plus tard',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF8E8E93) : Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (!release.mandatory && !_isDownloading) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isDownloading ? null : _triggerUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isDownloading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              Platform.isIOS
                                  ? 'Installer via SideStore'
                                  : (_isAlreadyDownloaded ? 'Installer' : 'Mettre à jour'),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
