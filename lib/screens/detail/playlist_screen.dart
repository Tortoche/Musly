import 'package:musly/screens/player/now_playing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:musly/models/models.dart';
import 'package:musly/providers/providers.dart';
import 'package:musly/services/subsonic_service.dart';
import 'package:musly/services/offline_service.dart';
import 'package:musly/services/tv_detection_service.dart';
import 'package:musly/services/favorite_playlists_service.dart';
import 'package:musly/services/playlist_cover_service.dart';
import 'package:musly/services/haptics_service.dart';
import 'package:musly/services/discovery_service.dart';
import 'package:musly/theme/app_theme.dart';
import 'package:musly/widgets/widgets.dart';
import 'package:musly/l10n/app_localizations.dart';
import 'package:musly/utils/screen_helper.dart';
import 'package:musly/utils/navigation_helper.dart';

class PlaylistScreen extends StatefulWidget {
  final String playlistId;
  final String? playlistName;
  final Playlist? initialPlaylist;

  const PlaylistScreen({
    super.key,
    required this.playlistId,
    this.playlistName,
    this.initialPlaylist,
  });

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  Playlist? _playlist;
  bool _isLoading = true;
  bool _isSelecting = false;
  bool _isReordering = false;
  bool _showSearch = false;
  String _searchQuery = '';
  final Set<int> _selectedIndices = {};

  bool _allDownloaded = false;
  bool _isQueued = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPlaylist != null) {
      _playlist = widget.initialPlaylist;
      if (widget.initialPlaylist!.songs != null && widget.initialPlaylist!.songs!.isNotEmpty) {
        _isLoading = false;
      }
    }
    if (widget.playlistId == DiscoveryService.kDiscoveryPlaylistId ||
        widget.playlistId.startsWith('pl_discovery_')) {
      _playlist = DiscoveryService().currentDiscoveryPlaylist;
      if (_playlist != null && _playlist!.songs != null && _playlist!.songs!.isNotEmpty) {
        _isLoading = false;
      }
    } else {
      final lib = Provider.of<LibraryProvider>(context, listen: false);
      final existingIndex =
          lib.playlists.indexWhere((p) => p.id == widget.playlistId);
      if (existingIndex != -1) {
        final existing = lib.playlists[existingIndex];
        _playlist = existing;
        if (existing.songs != null && existing.songs!.isNotEmpty) {
          _isLoading = false;
        }
      }
    }
    _loadPlaylist();
    OfflineService().downloadedPlaylistIds.addListener(_updateDownloadState);
    OfflineService().queuedPlaylistIds.addListener(_updateDownloadState);
  }

  @override
  void dispose() {
    OfflineService().downloadedPlaylistIds.removeListener(_updateDownloadState);
    OfflineService().queuedPlaylistIds.removeListener(_updateDownloadState);
    super.dispose();
  }

  void _updateDownloadState() {
    if (!mounted) return;
    final offline = OfflineService();
    final allDown =
        offline.downloadedPlaylistIds.value.contains(widget.playlistId);
    final queued = offline.queuedPlaylistIds.value.contains(widget.playlistId);
    if (allDown != _allDownloaded || queued != _isQueued) {
      setState(() {
        _allDownloaded = allDown;
        _isQueued = queued;
      });
    }
  }

  Future<void> _loadPlaylist() async {
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );
    final subsonicService = Provider.of<SubsonicService>(
      context,
      listen: false,
    );

    try {
      if (widget.playlistId == DiscoveryService.kDiscoveryPlaylistId ||
          widget.playlistId.startsWith('pl_discovery_')) {
        var disc = DiscoveryService().currentDiscoveryPlaylist;
        if (disc == null) {
          final topArtists = libraryProvider.artists.map((a) => a.name).take(10).toList();
          final libSongs = libraryProvider.cachedAllSongs.isNotEmpty
              ? libraryProvider.cachedAllSongs
              : libraryProvider.randomSongs;
          disc = await DiscoveryService().generateDailyDiscovery(
            userTopArtists: topArtists,
            userLibrarySongs: libSongs,
            subsonicService: subsonicService,
          );
        }
        if (mounted) {
          setState(() {
            _playlist = disc;
            _isLoading = false;
          });
          _updateDownloadState();
          return;
        }
      }
      final playlist = await libraryProvider.getPlaylist(widget.playlistId);
      if (mounted) {
        setState(() {
          _playlist = playlist;
          _isLoading = false;
        });
        _updateDownloadState();
      }
      if ((playlist.coverArt == null || playlist.coverArt!.isEmpty) &&
          playlist.songs != null &&
          playlist.songs!.isNotEmpty) {
        PlaylistCoverService().checkAndGenerateCover(
          playlistId: widget.playlistId,
          songs: playlist.songs!,
          subsonicService: subsonicService,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _playAll({bool shuffle = false}) {
    if (_playlist?.songs == null || _playlist!.songs!.isEmpty) return;

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    var songs = List.from(_playlist!.songs!);
    if (shuffle) {
      songs.shuffle();
    }

    NowPlayingScreen.open(context, song: songs.first);
    playerProvider.playSong(songs.first, playlist: songs.cast(), startIndex: 0);
  }

  Future<void> _removeSongFromPlaylist(int index) async {
    final subsonicService = Provider.of<SubsonicService>(
      context,
      listen: false,
    );
    try {
      final updatedSongs = List<Song>.from(_playlist!.songs!)..removeAt(index);
      final updatedPl = _playlist!.copyWith(
        songCount: updatedSongs.length,
        songs: updatedSongs,
      );
      setState(() {
        _playlist = updatedPl;
      });

      final libProvider = Provider.of<LibraryProvider>(context, listen: false);
      await libProvider.updatePlaylistInMemoryAndDb(updatedPl);

      try {
        await subsonicService.updatePlaylist(
          playlistId: widget.playlistId,
          songIndexesToRemove: [index],
        );
      } catch (e) {
        debugPrint('[PlaylistScreen] Subsonic server remove failed (virtual/local): ');
      }

      if ((_playlist?.coverArt == null || _playlist!.coverArt!.isEmpty) &&
          updatedSongs.isNotEmpty) {
        PlaylistCoverService().checkAndGenerateCover(
          playlistId: widget.playlistId,
          songs: updatedSongs,
          subsonicService: subsonicService,
        );
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.songRemovedFromPlaylist),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorRemovingSong(e.toString())),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelecting = !_isSelecting;
      _isReordering = false;
      _selectedIndices.clear();
    });
  }

  void _toggleReorderMode() {
    setState(() {
      _isReordering = !_isReordering;
      _isSelecting = false;
      _selectedIndices.clear();
    });
  }

  Future<void> _onSongReorderedItem(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    final subsonicService = Provider.of<SubsonicService>(
      context,
      listen: false,
    );

    final updatedSongs = List<Song>.from(_playlist!.songs!);
    final song = updatedSongs.removeAt(oldIndex);
    updatedSongs.insert(newIndex, song);

    final updatedPl = _playlist!.copyWith(songs: updatedSongs);
    setState(() {
      _playlist = updatedPl;
    });

    final libProvider = Provider.of<LibraryProvider>(context, listen: false);
    await libProvider.updatePlaylistInMemoryAndDb(updatedPl);

    if ((_playlist?.coverArt == null || _playlist!.coverArt!.isEmpty) &&
        updatedSongs.isNotEmpty) {
      PlaylistCoverService().checkAndGenerateCover(
        playlistId: widget.playlistId,
        songs: updatedSongs,
        subsonicService: subsonicService,
      );
    }

    try {
      await subsonicService.updatePlaylist(
        playlistId: widget.playlistId,
        songIndexesToRemove: [oldIndex],
        songIdsToAdd: [
          _playlist!.songs![newIndex].id,
        ],
      );
    } catch (e) {
      debugPrint('[PlaylistScreen] Subsonic server reorder failed (virtual/local): ');
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _toggleSelectAll() {
    final songCount = _playlist?.songs?.length ?? 0;
    setState(() {
      if (_selectedIndices.length == songCount) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.addAll(List.generate(songCount, (i) => i));
      }
    });
  }

  Future<void> _removeSelected() async {
    if (_selectedIndices.isEmpty) return;
    final count = _selectedIndices.length;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeSongsTitle),
        content: Text(
          l10n.removePlaylistSongsConfirm(count, _playlist!.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.remove, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final sortedIndices = List<int>.from(_selectedIndices)
      ..sort((a, b) => b.compareTo(a));

    final subsonicService = Provider.of<SubsonicService>(
      context,
      listen: false,
    );
    final updatedSongs = List<Song>.from(_playlist!.songs!);
    for (final index in sortedIndices) {
      if (index < updatedSongs.length) {
        updatedSongs.removeAt(index);
      }
    }

    try {
      await subsonicService.updatePlaylist(
        playlistId: widget.playlistId,
        songIndexesToRemove: sortedIndices,
      );

      setState(() {
        _playlist = _playlist!.copyWith(
          songs: updatedSongs,
        );
        _selectedIndices.clear();
        _isSelecting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.removedSongsFromPlaylist(count),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorRemovingSong(e.toString())),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_playlist == null) return;
    await FavoritePlaylistsService().toggleFavorite(widget.playlistId);
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            FavoritePlaylistsService().isFavorite(widget.playlistId)
                ? l10n.addedToFavorites
                : l10n.removedFromFavorites,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deletePlaylist() async {
    final playlist = _playlist ??
        Playlist(
          id: widget.playlistId,
          name: widget.playlistName ?? '',
        );
    final deleted =
        await PlaylistOptionsModal.confirmAndDelete(context, playlist);
    if (deleted && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _downloadPlaylist() async {
    final songs = _playlist?.songs;
    if (songs == null || songs.isEmpty) return;
    final offlineService = OfflineService();
    final subsonicService =
        Provider.of<SubsonicService>(context, listen: false);
    final libraryProvider =
        Provider.of<LibraryProvider>(context, listen: false);
    libraryProvider.cacheSongsLocally(songs);
    await offlineService.initialize();
    offlineService.queuePlaylistDownload(
        widget.playlistId, songs, subsonicService);
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.queuedSongsForDownload(songs.length)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _cancelDownload() async {
    await OfflineService().cancelPlaylistDownload(widget.playlistId);
  }

  Future<void> _removeDownloads() async {
    final songs = _playlist?.songs ?? [];
    if (songs.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeDownloadsTitle),
        content: Text(
            l10n.removePlaylistDownloadsConfirm(songs.length, _playlist!.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.remove, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await OfflineService().cancelPlaylistDownload(widget.playlistId);
      await OfflineService().deletePlaylistDownloads(songs);
    }
  }

  Widget _buildDownloadButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_allDownloaded) {
      return IconButton(
        tooltip: l10n.downloadedTapToRemove,
        onPressed: _removeDownloads,
        icon: const Icon(Icons.cloud_done, color: Colors.green),
      );
    }
    if (_isQueued) {
      return IconButton(
        tooltip: l10n.downloadingTapToCancel,
        onPressed: _cancelDownload,
        icon: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      tooltip: l10n.downloadPlaylist,
      onPressed: _downloadPlaylist,
      icon: const Icon(CupertinoIcons.cloud_download),
    );
  }

  void _showAddToMyPlaylistsModal() {
    if (_playlist == null) return;
    final songs = _playlist!.songs ?? [];
    if (songs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cette playlist ne contient aucun morceau à ajouter.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticsService.light();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141416) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: isDark ? const Color(0x1AFFFFFF) : Colors.black12,
              width: 0.5,
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bottomSheetContext).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    PlaylistArtwork(
                      playlist: _playlist,
                      size: 48,
                      borderRadius: 6,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _playlist!.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${songs.length} titres • ${_playlist!.formattedDuration}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.plus,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Enregistrer comme nouvelle playlist',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Ajoute la liste complète à votre bibliothèque'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _promptSaveAsNewPlaylist();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.black12,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.square_stack_3d_down_right,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Ajouter à une playlist existante...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text("Fusionner ces morceaux dans l'une de vos listes"),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _showSelectTargetPlaylistModal();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _promptSaveAsNewPlaylist() async {
    final textController = TextEditingController(text: _playlist!.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgContext) {
        return AlertDialog(
          title: const Text('Enregistrer dans mes listes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Donnez un nom à votre playlist :',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Nom de la playlist',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dlgContext, true),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final name = textController.text.trim().isNotEmpty
          ? textController.text.trim()
          : _playlist!.name;
      final lib = Provider.of<LibraryProvider>(context, listen: false);
      try {
        await lib.savePlaylistToLibrary(
          name: name,
          songs: _playlist!.songs ?? [],
          coverArt: _playlist!.coverArt,
        );
        HapticsService.medium();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Playlist "$name" enregistrée dans vos listes !'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erreur lors de l'enregistrement : $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showSelectTargetPlaylistModal() {
    final lib = Provider.of<LibraryProvider>(context, listen: false);
    final myPlaylists = lib.playlists.where((p) => p.id != widget.playlistId).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141416) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Choisir une liste existante',
                      style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (myPlaylists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    "Aucune liste de lecture disponible.\nCréez-en une nouvelle d'abord !",
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: myPlaylists.length,
                    itemBuilder: (ctx, i) {
                      final target = myPlaylists[i];
                      return ListTile(
                        leading: PlaylistArtwork(
                          playlist: target,
                          size: 42,
                          borderRadius: 6,
                        ),
                        title: Text(target.name),
                        subtitle: Text('${target.songCount ?? 0} titres'),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          final songsToAdd = _playlist!.songs ?? [];
                          await lib.addSongsToPlaylist(target.id, songsToAdd);
                          HapticsService.medium();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${songsToAdd.length} titres ajoutés à "${target.name}" !',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget? _buildBottomPlayer(BuildContext context) {
    final isInner =
        Navigator.of(context) == NavigationHelper.appNavigatorKey.currentState;
    if (isInner) return null;
    return const SafeArea(
      top: false,
      child: MiniPlayer(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title:
              widget.playlistName != null ? Text(widget.playlistName!) : null,
        ),
        bottomNavigationBar: _buildBottomPlayer(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_playlist == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.playlistName ?? 'Playlist'),
        ),
        bottomNavigationBar: _buildBottomPlayer(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.music_note_list, size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.playlistNotFound,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.playlistId.contains('sp')
                      ? 'Cette playlist Spotify semble privée ou introuvable. Vérifiez qu\'elle est bien en mode Public sur Spotify.'
                      : 'Impossible de charger les titres de cette playlist. Vérifiez votre connexion internet.',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isOffline = Provider.of<AuthProvider>(context, listen: false).state ==
        AuthState.offlineMode;

    if (_isReordering) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.reorderSongs),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.xmark),
            onPressed: _toggleReorderMode,
          ),
          actions: [
            IconButton(
              tooltip: AppLocalizations.of(context)!.doneReordering,
              icon: const Icon(CupertinoIcons.checkmark),
              onPressed: _toggleReorderMode,
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomPlayer(context),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: OfflineService().downloadedPlaylistIds,
                    builder: (context, downloaded, _) {
                      final allDownloaded =
                          downloaded.contains(widget.playlistId);
                      return Stack(
                        children: [
                          PlaylistArtwork(
                            playlist: _playlist,
                            songs: _playlist?.songs,
                            size: 150,
                            borderRadius: 12,
                          ),
                          if (allDownloaded)
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 24,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _playlist!.name,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppLocalizations.of(context)!.songsCount(_playlist!.songs?.length ?? 0)}${_playlist!.formattedDuration.isNotEmpty ? ' • ${_playlist!.formattedDuration}' : ''}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _PlayButton(
                          icon: CupertinoIcons.play_fill,
                          label: AppLocalizations.of(context)!.play,
                          onTap: () => _playAll(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PlayButton(
                          icon: CupertinoIcons.shuffle,
                          label: AppLocalizations.of(context)!.shuffle,
                          onTap: () => _playAll(shuffle: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _showAddToMyPlaylistsModal,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161618) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0x1AFFFFFF) : Colors.black12,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.plus_rectangle_on_rectangle,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ajouter à mes listes de lecture',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: 150),
                itemCount: _playlist!.songs!.length,
                buildDefaultDragHandles: false,
                onReorder: _onSongReorderedItem,
                itemBuilder: (context, index) {
                  final song = _playlist!.songs![index];
                  return ListTile(
                    key: ValueKey('reorder_${song.id}_$index'),
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        CupertinoIcons.line_horizontal_3,
                        color: isDark
                            ? AppTheme.darkSecondaryText
                            : AppTheme.lightSecondaryText,
                      ),
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      song.artist ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      bottomNavigationBar: _buildBottomPlayer(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: ScreenHelper.isSmallScreen(context) ? 280 : 360,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.back,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: LayoutBuilder(
                builder: (context, constraints) {
                  final topPadding = MediaQuery.of(context).padding.top;
                  final isSmall = ScreenHelper.isSmallScreen(context);
                  final minHeight = kToolbarHeight + topPadding;
                  final maxHeight = isSmall ? 280.0 : 360.0;
                  final currentHeight = constraints.maxHeight;
                  final delta = (maxHeight - minHeight).clamp(1.0, 999.0);
                  final progress =
                      ((currentHeight - minHeight) / delta).clamp(0.0, 1.0);

                  final maxArtSize = isSmall ? 190.0 : 240.0;
                  final availableHeight =
                      (currentHeight - topPadding - (isSmall ? 16.0 : 24.0))
                          .clamp(0.0, maxHeight);
                  final artDimension =
                      (maxArtSize * progress).clamp(0.0, availableHeight);
                  final opacity = (progress * 1.3 - 0.1).clamp(0.0, 1.0);

                  if (artDimension <= 10.0 || opacity <= 0.0) {
                    return const SizedBox.shrink();
                  }

                  return Center(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: topPadding + (isSmall ? 8.0 : 12.0) * progress,
                        bottom: (isSmall ? 10.0 : 16.0) * progress,
                      ),
                      child: Opacity(
                        opacity: opacity,
                        child: SizedBox.square(
                          dimension: artDimension,
                          child: PlaylistArtwork(
                            playlist: _playlist,
                            songs: _playlist?.songs,
                            size: artDimension,
                            borderRadius: (14.0 * progress).clamp(4.0, 14.0),
                            shadow: progress > 0.3
                                ? BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: (isDark ? 0.35 : 0.2) * progress,
                                    ),
                                    blurRadius: 16.0 * progress,
                                    offset: Offset(0, 8.0 * progress),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              if (_isSelecting) ...[
                IconButton(
                  tooltip:
                      _selectedIndices.length == (_playlist?.songs?.length ?? 0)
                          ? 'Deselect all'
                          : 'Select all',
                  icon: Icon(
                    _selectedIndices.length == (_playlist?.songs?.length ?? 0)
                        ? CupertinoIcons.checkmark_square
                        : CupertinoIcons.square,
                  ),
                  onPressed: _toggleSelectAll,
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.removeSelected,
                  icon: const Icon(CupertinoIcons.trash),
                  color: _selectedIndices.isNotEmpty ? Colors.red : null,
                  onPressed:
                      _selectedIndices.isNotEmpty ? _removeSelected : null,
                ),
              ] else ...[
                IconButton(
                  tooltip: 'Ajouter à mes listes de lecture',
                  icon: const Icon(CupertinoIcons.plus_rectangle_on_rectangle),
                  onPressed: _showAddToMyPlaylistsModal,
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.searchInPlaylist,
                  icon: Icon(_showSearch
                      ? CupertinoIcons.search_circle_fill
                      : CupertinoIcons.search),
                  onPressed: () {
                    setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) _searchQuery = '';
                    });
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(CupertinoIcons.ellipsis_circle),
                  tooltip: AppLocalizations.of(context)!.moreOptions,
                  onSelected: (value) {
                    if (value == 'add_to_my_playlists') {
                      _showAddToMyPlaylistsModal();
                    } else if (value == 'queue_all') {
                      final songs = _playlist?.songs ?? [];
                      final playerProvider =
                          Provider.of<PlayerProvider>(context, listen: false);
                      for (final s in songs) {
                        playerProvider.addToQueue(s);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(AppLocalizations.of(context)!
                                .songsAddedToQueue(songs.length))),
                      );
                    } else if (value == 'delete_playlist') {
                      _deletePlaylist();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'add_to_my_playlists',
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.plus_rectangle_on_rectangle, size: 18),
                          const SizedBox(width: 12),
                          const Text('Ajouter à mes playlists'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'queue_all',
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.text_badge_plus, size: 18),
                          const SizedBox(width: 12),
                          Text(AppLocalizations.of(context)!.addAllToQueue),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete_playlist',
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.trash,
                              size: 18, color: Colors.red),
                          const SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context)!.deletePlaylist,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                AnimatedBuilder(
                  animation: FavoritePlaylistsService(),
                  builder: (context, child) {
                    final isFavorite = FavoritePlaylistsService()
                        .isFavorite(widget.playlistId);
                    return IconButton(
                      tooltip: isFavorite
                          ? AppLocalizations.of(context)!.removeFromFavorites
                          : AppLocalizations.of(context)!.addToFavorites,
                      icon: Icon(
                        isFavorite
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        color: isFavorite ? Colors.red : null,
                      ),
                      onPressed: _toggleFavorite,
                    );
                  },
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.reorderSongs,
                  icon: const Icon(CupertinoIcons.arrow_up_arrow_down),
                  onPressed:
                      _playlist!.songs != null && _playlist!.songs!.length > 1
                          ? _toggleReorderMode
                          : null,
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.selectSongs,
                  icon: const Icon(CupertinoIcons.checkmark_circle),
                  onPressed: _toggleSelectMode,
                ),
                if (!isOffline) _buildDownloadButton(context),
              ],
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _playlist!.name,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppLocalizations.of(context)!.songsCount(_playlist!.songs?.length ?? 0)}${_playlist!.formattedDuration.isNotEmpty ? ' • ${_playlist!.formattedDuration}' : ''}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _PlayButton(
                          icon: CupertinoIcons.play_fill,
                          label: AppLocalizations.of(context)!.play,
                          autofocus: Provider.of<TvDetectionService>(context,
                                  listen: false)
                              .isTvMode,
                          onTap: () => _playAll(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PlayButton(
                          icon: CupertinoIcons.shuffle,
                          label: AppLocalizations.of(context)!.shuffle,
                          onTap: () => _playAll(shuffle: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _showAddToMyPlaylistsModal,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161618) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0x1AFFFFFF) : Colors.black12,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.plus_rectangle_on_rectangle,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ajouter à mes listes de lecture',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showSearch) ...[
                    const SizedBox(height: 16),
                    CupertinoSearchTextField(
                      placeholder: AppLocalizations.of(context)!.filterSongs,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: Divider()),
          if (_playlist!.songs?.isEmpty ?? true)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    'No songs in this playlist',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.lightSecondaryText,
                    ),
                  ),
                ),
              ),
            )
          else if (_isSelecting)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = _playlist!.songs![index];
                  final isSelected = _selectedIndices.contains(index);
                  return CheckboxListTile(
                    key: ValueKey('sel_${song.id}_$index'),
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(index),
                    activeColor: Theme.of(context).colorScheme.primary,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.only(
                      left: 4,
                      right: 16,
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      song.artist ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    secondary: IconButton(
                      icon: const Icon(CupertinoIcons.trash, size: 20),
                      color: Colors.red,
                      tooltip: AppLocalizations.of(context)!.removeFromPlaylist,
                      onPressed: () async {
                        setState(() => _selectedIndices.remove(index));
                        await _removeSongFromPlaylist(index);
                      },
                    ),
                  );
                },
                childCount: _playlist!.songs!.length,
              ),
            )
          else
            Builder(
              builder: (context) {
                final allSongs = _playlist!.songs!;
                final displaySongs = _searchQuery.isEmpty
                    ? allSongs
                    : allSongs
                        .where((s) =>
                            s.title.toLowerCase().contains(_searchQuery) ||
                            (s.artist?.toLowerCase().contains(_searchQuery) ??
                                false))
                        .toList();

                return SliverFixedExtentList(
                  itemExtent: 68.0,
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = displaySongs[index];
                      final tile = SongTile(
                        song: song,
                        playlist: displaySongs,
                        index: index,
                        showArtist: true,
                      );
                      return Dismissible(
                        key: ValueKey('${song.id}_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(
                            CupertinoIcons.trash,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) {
                          final originalIndex = _playlist!.songs!.indexOf(song);
                          if (originalIndex != -1) {
                            _removeSongFromPlaylist(originalIndex);
                          }
                        },
                        child: tile,
                      );
                    },
                    childCount: displaySongs.length,
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool autofocus;

  const _PlayButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        autofocus: autofocus,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
