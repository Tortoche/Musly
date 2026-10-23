import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/playlist_import_service.dart';
import '../../screens/detail/playlist_screen.dart';
import '../../utils/navigation_helper.dart';

class ImportPlaylistDialog extends StatefulWidget {
  const ImportPlaylistDialog({super.key});

  static Future<Playlist?> show(BuildContext context) {
    return showDialog<Playlist>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ImportPlaylistDialog(),
    );
  }

  @override
  State<ImportPlaylistDialog> createState() => _ImportPlaylistDialogState();
}

enum _ImportStep {
  input,
  preview,
  importing,
  success,
}

class _ImportPlaylistDialogState extends State<ImportPlaylistDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  _ImportStep _currentStep = _ImportStep.input;
  bool _isLoadingPreview = false;
  String? _errorMessage;

  PlaylistImportPreview? _preview;
  Playlist? _importedPlaylist;

  int _progressCurrent = 0;
  int _progressTotal = 0;
  String _progressStatus = '';

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  PlaylistImportSource get _detectedSource {
    final text = _urlController.text.trim();
    if (text.isEmpty) return PlaylistImportSource.unknown;
    return PlaylistImportService().detectSource(text);
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _urlController.text = data.text!.trim();
        _errorMessage = null;
      });
    }
  }

  Future<void> _fetchPreview() async {
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez entrer un lien ou identifiant de playlist';
      });
      return;
    }

    setState(() {
      _isLoadingPreview = true;
      _errorMessage = null;
    });

    try {
      final preview = await PlaylistImportService().fetchPreview(text);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _nameController.text = preview.title;
        _currentStep = _ImportStep.preview;
        _isLoadingPreview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPreview = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _startImport() async {
    if (_preview == null) return;

    setState(() {
      _currentStep = _ImportStep.importing;
      _progressCurrent = 0;
      _progressTotal = _preview!.totalTracks;
      _progressStatus = 'Démarrage de l\'importation...';
      _errorMessage = null;
    });

    try {
      final libraryProvider =
          Provider.of<LibraryProvider>(context, listen: false);

      final playlist = await libraryProvider.importPlaylistFromPreview(
        preview: _preview!,
        customName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : _preview!.title,
        onProgress: (current, total, status) {
          if (mounted) {
            setState(() {
              _progressCurrent = current;
              _progressTotal = total;
              _progressStatus = status;
            });
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _importedPlaylist = playlist;
        _currentStep = _ImportStep.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentStep = _ImportStep.preview;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _openImportedPlaylist() {
    if (_importedPlaylist != null && mounted) {
      final p = _importedPlaylist!;
      Navigator.of(context).pop(p);
      NavigationHelper.push(
        context,
        PlaylistScreen(
          playlistId: p.id,
          playlistName: p.name,
        ),
      );
    } else {
      Navigator.of(context).pop(_importedPlaylist);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildCurrentStepView(context, isDark, primaryColor),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepView(
      BuildContext context, bool isDark, Color primaryColor) {
    switch (_currentStep) {
      case _ImportStep.input:
        return _buildInputStep(context, isDark, primaryColor);
      case _ImportStep.preview:
        return _buildPreviewStep(context, isDark, primaryColor);
      case _ImportStep.importing:
        return _buildImportingStep(context, isDark, primaryColor);
      case _ImportStep.success:
        return _buildSuccessStep(context, isDark, primaryColor);
    }
  }

  Widget _buildInputStep(
      BuildContext context, bool isDark, Color primaryColor) {
    final detected = _detectedSource;

    return Column(
      key: const ValueKey('step_input'),
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
                CupertinoIcons.square_arrow_down,
                color: primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Importer une playlist',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Spotify ou YouTube Music (sans compte requis)',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Chiudi',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _buildSourceBadge(
              label: 'Spotify',
              color: const Color(0xFF1DB954),
              icon: Icons.music_note_rounded,
              isActive: detected == PlaylistImportSource.spotify,
            ),
            const SizedBox(width: 10),
            _buildSourceBadge(
              label: 'YouTube Music',
              color: const Color(0xFFFF0000),
              icon: Icons.play_circle_fill_rounded,
              isActive: detected == PlaylistImportSource.youtubeMusic,
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _urlController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Coller un lien Spotify ou YouTube Music...',
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_urlController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() {
                      _urlController.clear();
                      _errorMessage = null;
                    }),
                  ),
                IconButton(
                  icon: const Icon(Icons.content_paste_rounded, size: 20),
                  tooltip: 'Coller depuis le presse-papier',
                  onPressed: _pasteClipboard,
                ),
              ],
            ),
          ),
          onChanged: (_) => setState(() => _errorMessage = null),
          onSubmitted: (_) => _fetchPreview(),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isLoadingPreview ? null : _fetchPreview,
          icon: _isLoadingPreview
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(CupertinoIcons.arrow_right_circle),
          label:
              Text(_isLoadingPreview ? 'Chargement...' : 'Charger l\'aperçu'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceBadge({
    required String label,
    required Color color,
    required IconData icon,
    required bool isActive,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.2) : Colors.transparent,
        border: Border.all(
          color: isActive ? color : Colors.grey.withValues(alpha: 0.3),
          width: isActive ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isActive ? color : Colors.grey),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStep(
      BuildContext context, bool isDark, Color primaryColor) {
    if (_preview == null) return const SizedBox.shrink();
    final p = _preview!;
    final isSpotify = p.source == PlaylistImportSource.spotify;

    return Column(
      key: const ValueKey('step_preview'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _currentStep = _ImportStep.input),
              tooltip: 'Indietro',
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Aperçu de la playlist',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Chiudi',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: (p.coverArtUrl != null && p.coverArtUrl!.isNotEmpty)
                    ? Image.network(
                        p.coverArtUrl!,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderCover(),
                      )
                    : _buildPlaceholderCover(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isSpotify
                                    ? const Color(0xFF1DB954)
                                    : const Color(0xFFFF0000))
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isSpotify ? 'Spotify' : 'YouTube Music',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSpotify
                                  ? const Color(0xFF1DB954)
                                  : const Color(0xFFFF0000),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${p.totalTracks} brani',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        border: UnderlineInputBorder(),
                        labelText: 'Nom de la playlist',
                        labelStyle: TextStyle(fontSize: 12),
                      ),
                    ),
                    if (p.author != null && p.author!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Autore: ${p.author}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Titres inclus (${p.totalTracks}) :',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.separated(
              itemCount: p.tracks.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.black12,
              ),
              itemBuilder: (context, index) {
                final track = p.tracks[index];
                return ListTile(
                  dense: true,
                  leading: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  trailing: track.duration != null
                      ? Text(
                          _formatDuration(track.duration!),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: _startImport,
          icon: const Icon(CupertinoIcons.cloud_download),
          label: Text('Importa ${p.totalTracks} brani in Web Stream'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportingStep(
      BuildContext context, bool isDark, Color primaryColor) {
    final progressFraction = _progressTotal > 0
        ? (_progressCurrent / _progressTotal).clamp(0.0, 1.0)
        : null;

    return Column(
      key: const ValueKey('step_importing'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: primaryColor,
                value: progressFraction,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Importation en cours...',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _progressTotal > 0
              ? 'Tracce: $_progressCurrent / $_progressTotal'
              : 'Préparation des morceaux...',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progressFraction,
            minHeight: 8,
            backgroundColor: isDark ? Colors.white12 : Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _progressStatus,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSuccessStep(
      BuildContext context, bool isDark, Color primaryColor) {
    final p = _importedPlaylist;

    return Column(
      key: const ValueKey('step_success'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Playlist importée avec succès !',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          '"${p?.name ?? 'Playlist'}" est prête pour l\'écoute',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(p),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Chiudi'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openImportedPlaylist,
                icon: const Icon(CupertinoIcons.play_circle_fill),
                label: const Text('Ouvrir la playlist'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      width: 70,
      height: 70,
      color: Colors.grey.withValues(alpha: 0.2),
      child: const Icon(Icons.music_note, color: Colors.grey),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
