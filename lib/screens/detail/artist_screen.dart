import 'package:musly/screens/player/now_playing_screen.dart';
import 'package:flutter/material.dart';
import 'package:musly/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:musly/models/models.dart';
import 'package:musly/providers/providers.dart';
import 'package:musly/widgets/widgets.dart';
import 'album_screen.dart';
import 'package:musly/services/offline_service.dart';
import 'package:musly/services/deezer_service.dart';
import 'package:musly/utils/navigation_helper.dart';

class ArtistScreen extends StatefulWidget {
  final String artistId;
  final String? artistName;
  final Artist? initialArtist;

  const ArtistScreen({
    super.key,
    required this.artistId,
    this.artistName,
    this.initialArtist,
  });

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  Artist? _artist;
  ArtistInfo? _artistInfo;
  List<Song> _officialTopSongs = [];
  List<Song> _allSongs = [];
  List<Album> _albums = [];
  bool _isLoading = true;
  bool _showAllSongs = false;
  bool _showSearch = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialArtist != null) {
      _artist = widget.initialArtist;
    } else if (widget.artistName != null && widget.artistName!.isNotEmpty) {
      _artist = Artist(id: widget.artistId, name: widget.artistName!);
    }
    _loadArtistDetails();
  }

  Future<void> _loadArtistDetails() async {
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );
    final subsonicService = libraryProvider.subsonicService;

    try {
      Artist? artist;
      ArtistInfo? artistInfo;
      List<Song> topSongs = [];
      List<Album> albums = [];
      List<Song> allSongs = [];
      final Set<String> songIds = {};

      if (libraryProvider.isLocalOnlyMode) {
        artist = libraryProvider.artists.firstWhere(
          (a) => a.id == widget.artistId,
          orElse: () => Artist(id: widget.artistId, name: 'Unknown Artist'),
        );
        albums = await libraryProvider.getArtistAlbums(widget.artistId);
        allSongs = libraryProvider.cachedAllSongs
            .where((s) => s.artistId == widget.artistId)
            .toList();
        topSongs = allSongs;
      } else {
        final artistFuture = subsonicService
            .getArtist(widget.artistId)
            .catchError((e) {
              debugPrint(
                  '[ArtistScreen] getArtist failed: $e – trying fallbacks');
              throw e;
            })
            .then<Artist?>((val) => val)
            .catchError((_) => null);

        final infoFuture = subsonicService
            .getArtistInfo(widget.artistId)
            .catchError((_) => null);
        final topSongsFuture = subsonicService
            .getArtistTopSongs(widget.artistId)
            .catchError((_) => <Song>[]);
        final albumsFuture = subsonicService
            .getArtistAlbums(widget.artistId)
            .catchError((_) => <Album>[]);

        final results = await Future.wait([
          artistFuture,
          infoFuture,
          topSongsFuture,
          albumsFuture,
        ]);

        artist = results[0] as Artist?;
        artistInfo = results[1] as ArtistInfo?;
        topSongs = results[2] as List<Song>? ?? [];
        albums = results[3] as List<Album>? ?? [];

        if (artist == null) {
          final cached = libraryProvider.artists.where(
            (a) => a.id == widget.artistId,
          );
          if (cached.isNotEmpty) artist = cached.first;
        }

        if (artist == null) {
          final songMatch = libraryProvider.cachedAllSongs.where(
            (s) => s.artistId == widget.artistId,
          );
          if (songMatch.isNotEmpty) {
            artist = Artist(
              id: widget.artistId,
              name: songMatch.first.artist ?? 'Unknown Artist',
            );
          }
        }

        if (albums.isNotEmpty) {
          artist ??= Artist(
            id: widget.artistId,
            name: albums.first.artist ?? 'Unknown Artist',
          );
        }

        // Ajouter d'abord les top songs de Subsonic
        for (final s in topSongs) {
          if (songIds.add(s.id)) {
            allSongs.add(s);
          }
        }

        // Récupérer les chansons de tous les albums
        if (albums.isNotEmpty) {
          try {
            final albumSongLists = await Future.wait(
              albums.map((album) => subsonicService
                  .getAlbumSongs(album.id)
                  .catchError((_) => <Song>[])),
            );
            for (final list in albumSongLists) {
              for (final s in list) {
                if (songIds.add(s.id)) {
                  allSongs.add(s);
                }
              }
            }
          } catch (e) {
            debugPrint('[ArtistScreen] Error fetching album songs: $e');
          }
        }

        // Enrichissement universel Deezer :
        // 1. Trouver le Deezer artist ID si l'artiste vient de Subsonic ou Deezer
        String? deezerArtistId = widget.artistId.startsWith('ext_dz_')
            ? widget.artistId.replaceAll('ext_dz_', '').replaceAll('ar-', '')
            : (int.tryParse(widget.artistId) != null ? widget.artistId : null);

        if (deezerArtistId == null && (artist?.name != null || widget.artistName != null)) {
          final queryName = artist?.name ?? widget.artistName;
          if (queryName != null && queryName.isNotEmpty) {
            try {
              final matched = await DeezerService().searchArtistByName(queryName);
              if (matched != null) {
                deezerArtistId = matched.id;
                artist ??= matched;
              }
            } catch (_) {}
          }
        }

        if (artist == null && deezerArtistId != null) {
          try {
            final dzArtist = await DeezerService().getArtist(deezerArtistId);
            if (dzArtist != null) {
              artist = dzArtist;
            }
          } catch (e) {
            debugPrint('[ArtistScreen] Error fetching Deezer artist: $e');
          }
        }

        if (artist == null && widget.initialArtist != null) {
          artist = widget.initialArtist;
        }
        if (artist == null && widget.artistName != null && widget.artistName!.isNotEmpty) {
          artist = Artist(id: widget.artistId, name: widget.artistName!);
        }

        // 2. Récupérer les vrais albums officiels studio Deezer
        if (deezerArtistId != null) {
          try {
            final deezerAlbums = await DeezerService().getArtistAlbums(deezerArtistId);
            if (deezerAlbums.isNotEmpty) {
              // Remplacer ou fusionner avec les albums studio officiels complets
              final Set<String> seenAlbumNames = {};
              final List<Album> realAlbums = [];
              for (final alb in deezerAlbums) {
                final norm = alb.name.toLowerCase().trim();
                if (seenAlbumNames.add(norm)) {
                  realAlbums.add(alb);
                }
              }
              albums = realAlbums;
            }

            // Récupérer également le catalogue complet des titres officiels
            final deezerTracks =
                await DeezerService().getArtistTopTracks(deezerArtistId, limit: 50);
            for (final s in deezerTracks) {
              if (songIds.add(s.id)) {
                allSongs.add(s);
              }
            }
            if (topSongs.isEmpty) {
              topSongs = deezerTracks;
            }
          } catch (e) {
            debugPrint('[ArtistScreen] Deezer universal enrichment error: $e');
          }
        }
      }

      // Filtrer et trier pour obtenir les VRAIS morceaux officiels
      bool isReworkOrNoise(String title) {
        final lower = title.toLowerCase();
        return lower.contains('rework') ||
            lower.contains('remix') ||
            lower.contains('edit radio') ||
            lower.contains('radio edit') ||
            lower.contains('club mix') ||
            lower.contains('instrumental') ||
            lower.contains('acapella') ||
            lower.contains('karaoke') ||
            lower.contains('(live') ||
            lower.contains('[live]') ||
            lower.contains('version live');
      }

      String normalizeTitle(String title) {
        return title
            .replaceAll(RegExp(r'\([^)]*\)'), '')
            .replaceAll(RegExp(r'\[[^\]]*\]'), '')
            .replaceAll(RegExp(r'[-–—].*'), '')
            .trim()
            .toLowerCase();
      }

      final cleanTop = <Song>[];
      final seenNormalizedTitles = <String>{};

      // 1. Ajouter les top songs officielles
      final basePool = topSongs.isNotEmpty ? topSongs : allSongs;
      for (final s in basePool) {
        if (!isReworkOrNoise(s.title)) {
          final norm = normalizeTitle(s.title);
          if (seenNormalizedTitles.add(norm)) {
            cleanTop.add(s);
          }
        }
      }

      // 2. Si moins de 5, compléter avec le reste de allSongs
      if (cleanTop.length < 5) {
        for (final s in allSongs) {
          if (!isReworkOrNoise(s.title)) {
            final norm = normalizeTitle(s.title);
            if (seenNormalizedTitles.add(norm)) {
              cleanTop.add(s);
            }
          }
        }
      }

      // 3. Fallback ultime si tout était marqué bruit
      if (cleanTop.isEmpty) {
        cleanTop.addAll(basePool);
      }

      if (mounted) {
        setState(() {
          _artist = artist;
          _artistInfo = artistInfo;
          _officialTopSongs = cleanTop;
          _allSongs = allSongs;
          _albums = albums;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ArtistScreen] Unexpected error loading artist: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addArtistToQueue() async {
    final list = _officialTopSongs.isNotEmpty ? _officialTopSongs : _allSongs;
    if (list.isEmpty) return;

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    playerProvider.addAllToQueue(list);

    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    final addedToQueueMessage =
        loc?.addedArtistToQueue ?? 'Morceaux ajoutés à la file';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(addedToQueueMessage),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _downloadArtistSongs() async {
    final list = _officialTopSongs.isNotEmpty ? _officialTopSongs : _allSongs;
    if (list.isEmpty) return;

    final offlineService = OfflineService();
    final libraryProvider =
        Provider.of<LibraryProvider>(context, listen: false);
    final subsonicService = libraryProvider.subsonicService;

    await offlineService.initialize();
    if (!mounted) return;

    offlineService.queuePlaylistDownload(
        'artist_${widget.artistId}', list, subsonicService);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${list.length} morceaux ajoutés aux téléchargements'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _playSongs({bool shuffle = false}) {
    final list = _officialTopSongs.isNotEmpty ? _officialTopSongs : _allSongs;
    if (list.isEmpty) return;

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    var songs = List<Song>.from(list);
    if (shuffle) {
      songs.shuffle();
    }

    NowPlayingScreen.open(context, song: songs.first);
    playerProvider.playSong(songs.first, playlist: songs, startIndex: 0);
  }

  Future<void> _onAlbumTap(Album album) async {
    // Si l'album ne contient qu'une seule piste (Single) : lecture directe immédiate sans page vide
    if (album.songCount == 1) {
      final libraryProvider =
          Provider.of<LibraryProvider>(context, listen: false);
      final subsonicService = libraryProvider.subsonicService;
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);

      try {
        final songs = libraryProvider.isLocalOnlyMode
            ? libraryProvider.cachedAllSongs
                .where((s) => s.albumId == album.id)
                .toList()
            : await subsonicService.getAlbumSongs(album.id);
        if (songs.isNotEmpty) {
          if (context.mounted) NowPlayingScreen.open(context, song: songs.first);
          playerProvider.playSong(songs.first, playlist: songs, startIndex: 0);
          return;
        }
      } catch (e) {
        debugPrint('[ArtistScreen] Single direct play fallback error: $e');
      }
    }

    if (!mounted) return;
    NavigationHelper.push(
      context,
      AlbumScreen(albumId: album.id),
    );
  }

  Widget? _buildBottomPlayer(BuildContext context) {
    final isInner =
        Navigator.of(context) == NavigationHelper.appNavigatorKey.currentState;
    if (isInner) return null;
    return const _ArtistBottomPlayer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: _buildBottomPlayer(context),
      );
    }

    if (_artist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(l10n.artistDataNotFound),
        ),
        bottomNavigationBar: _buildBottomPlayer(context),
      );
    }

    final pool = _officialTopSongs.isNotEmpty ? _officialTopSongs : _allSongs;
    final displaySongs = _searchQuery.isEmpty
        ? (_showAllSongs ? pool : pool.take(5).toList())
        : pool
            .where((s) =>
                s.title.toLowerCase().contains(_searchQuery) ||
                (s.album?.toLowerCase().contains(_searchQuery) ?? false))
            .toList();

    // Vrais albums studio uniquement (exclure tout ce qui n'a qu'un seul morceau)
    final effectiveAlbums =
        _albums.where((a) => (a.songCount ?? 0) > 1).toList();

    return Scaffold(
      bottomNavigationBar: _buildBottomPlayer(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(_artist!.name),
              background: Builder(
                builder: (context) {
                  final art = _artist!.coverArt ??
                      _artistInfo?.largeImageUrl ??
                      _artistInfo?.mediumImageUrl ??
                      _artist!.artistImageUrl ??
                      (_artist!.id.isNotEmpty ? 'ar-${_artist!.id}' : null);
                  if (art == null) {
                    return Container(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.mic_fill,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  }
                  return ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black, Colors.transparent],
                      ).createShader(
                        Rect.fromLTRB(0, 0, rect.width, rect.height),
                      );
                    },
                    blendMode: BlendMode.dstIn,
                    child: AlbumArtwork(
                      coverArt: art,
                      size: 200,
                    ),
                  );
                },
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(_showSearch
                    ? CupertinoIcons.search_circle_fill
                    : CupertinoIcons.search),
                tooltip: 'Rechercher un titre',
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) _searchQuery = '';
                  });
                },
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.cloud_download),
                tooltip: 'Télécharger les morceaux officiels',
                onPressed: pool.isEmpty ? null : () => _downloadArtistSongs(),
              ),
              IconButton(
                icon: const Icon(Icons.queue_music_rounded),
                tooltip: l10n.addToQueue,
                onPressed: pool.isEmpty ? null : () => _addArtistToQueue(),
              ),
            ],
          ),
          if (pool.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _PlayButton(
                            icon: CupertinoIcons.play_fill,
                            label: l10n.play,
                            onTap: () => _playSongs(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PlayButton(
                            icon: CupertinoIcons.shuffle,
                            label: l10n.shuffle,
                            onTap: () => _playSongs(shuffle: true),
                          ),
                        ),
                      ],
                    ),
                    if (_showSearch) ...[
                      const SizedBox(height: 12),
                      CupertinoSearchTextField(
                        placeholder: 'Filtrer les titres...',
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim().toLowerCase();
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Morceaux populaires',
                          style: theme.textTheme.headlineSmall,
                        ),
                        if (_searchQuery.isNotEmpty)
                          Text(
                            l10n.songsCount(displaySongs.length),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          // Liste des titres populaires
          SliverFixedExtentList(
            itemExtent: 68.0,
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = displaySongs[index];
                return SongTile(
                  song: song,
                  playlist: displaySongs,
                  index: index,
                  showAlbum: true,
                  showArtwork: true,
                  showArtist: false,
                );
              },
              childCount: displaySongs.length,
            ),
          ),
          // Bouton Voir Plus / Voir Moins
          if (_searchQuery.isEmpty && pool.length > 5)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAllSongs = !_showAllSongs;
                    });
                  },
                  icon: Icon(
                    _showAllSongs
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 16,
                  ),
                  label: Text(
                    _showAllSongs
                        ? 'Voir moins'
                        : 'Voir plus (${pool.length - 5} autres titres)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
          // Section Albums directement (sans section Singles)
          if (effectiveAlbums.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                child: Text(
                  AppLocalizations.of(context)!.sectionAlbums,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ),
          if (effectiveAlbums.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  childAspectRatio: 0.78,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final album = effectiveAlbums[index];
                    return AlbumCard(
                      album: album,
                      size: double.infinity,
                      onTap: () => _onAlbumTap(album),
                    );
                  },
                  childCount: effectiveAlbums.length,
                ),
              ),
            ),
          // Section À propos
          if (_artistInfo?.biography != null &&
              _artistInfo!.biography!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'À propos de ${_artist!.name}',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _artistInfo!.biography!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
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

  const _PlayButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
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

class _ArtistBottomPlayer extends StatelessWidget {
  const _ArtistBottomPlayer();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      top: false,
      child: MiniPlayer(),
    );
  }
}
