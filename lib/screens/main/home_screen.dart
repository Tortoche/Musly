import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:musly/models/models.dart';
import 'package:musly/providers/library_provider.dart';
import 'package:musly/providers/player_provider.dart';
import 'package:musly/providers/auth_provider.dart';
import 'package:musly/services/subsonic_service.dart';
import 'package:musly/services/recommendation_service.dart';
import 'package:musly/services/offline_service.dart';
import 'package:musly/services/favorite_playlists_service.dart';
import 'package:musly/services/player_ui_settings_service.dart';
import 'package:musly/theme/app_theme.dart';
import 'package:musly/utils/navigation_helper.dart';
import 'package:musly/widgets/widgets.dart';
import 'package:musly/screens/detail/album_screen.dart';
import 'package:musly/screens/detail/playlist_screen.dart';
import 'package:musly/screens/detail/artist_screen.dart';
import 'package:musly/screens/media/song_collection_screen.dart';
import 'package:musly/screens/media/favorites_screen.dart';
import 'package:musly/screens/settings/settings_screen.dart';
import 'package:musly/screens/wrapped/wrapped_screen.dart';
import 'package:musly/services/wrapped_service.dart';
import 'package:musly/services/deezer_service.dart';
import 'package:musly/services/discovery_service.dart';
import 'package:musly/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, List<Song>> _cachedMixes = const {};
  List<Song> _cachedPersonalized = const [];
  List<Song> _cachedListenAgain = const [];
  List<Song> _cachedTopHits = const [];
  List<Song> _deezerChartTracks = const [];
  bool _isLoadingCharts = false;
  List<Song> _deezerPersonalizedTracks = const [];
  bool _isLoadingPersonalized = false;
  Album? _topDeezerAlbum;
  Artist? _suggestedDiscoveryArtist;

  @override
  void initState() {
    super.initState();
    _loadDeezerCharts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDeezerPersonalized();
        _loadQuickAccessData();
        _triggerDiscoveryGeneration();
      }
    });
  }

  Future<void> _loadQuickAccessData() async {
    try {
      final libraryProvider =
          Provider.of<LibraryProvider>(context, listen: false);
      final recommendationService =
          Provider.of<RecommendationService>(context, listen: false);

      final Set<String> seedArtists = {};
      for (final a in recommendationService.getRecommendedArtists(limit: 5)) {
        if (a.trim().isNotEmpty) seedArtists.add(a.trim());
      }
      for (final alb in libraryProvider.recentAlbums.take(5)) {
        if (alb.artist != null && alb.artist!.trim().isNotEmpty) {
          seedArtists.add(alb.artist!.trim());
        }
      }
      for (final s in (libraryProvider.starred?.songs ?? []).take(8)) {
        if (s.artist != null && s.artist!.trim().isNotEmpty) {
          seedArtists.add(s.artist!.trim());
        }
      }

      final deezerService = DeezerService();
      final topAlb = await deezerService.getChartTopAlbum();
      final artist = await deezerService.getSuggestedDiscoveryArtist(
        seedArtists: seedArtists.toList(),
      );

      if (mounted) {
        setState(() {
          _topDeezerAlbum = topAlb;
          _suggestedDiscoveryArtist = artist;
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] Erreur chargement quick access: $e');
    }
  }

  Future<void> _triggerDiscoveryGeneration({bool force = false}) async {
    try {
      final libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
      final recommendationService = Provider.of<RecommendationService>(context, listen: false);
      
      final Set<String> topArtists = {};
      for (final a in recommendationService.getRecommendedArtists(limit: 6)) {
        if (a.trim().isNotEmpty) topArtists.add(a.trim());
      }
      for (final alb in libraryProvider.recentAlbums.take(6)) {
        if (alb.artist != null && alb.artist!.trim().isNotEmpty) topArtists.add(alb.artist!.trim());
      }
      for (final s in (libraryProvider.starred?.songs ?? []).take(10)) {
        if (s.artist != null && s.artist!.trim().isNotEmpty) topArtists.add(s.artist!.trim());
      }
      for (final art in libraryProvider.artists.take(6)) {
        if (art.name.trim().isNotEmpty) topArtists.add(art.name.trim());
      }

      final librarySongs = libraryProvider.cachedAllSongs.isNotEmpty
          ? libraryProvider.cachedAllSongs
          : libraryProvider.randomSongs;

      final subsonicService = Provider.of<SubsonicService>(context, listen: false);
      await DiscoveryService().generateDailyDiscovery(
        userTopArtists: topArtists.toList(),
        userLibrarySongs: librarySongs,
        subsonicService: subsonicService,
        forceRefresh: force,
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[HomeScreen] Erreur generation decouverte in-app: $e');
    }
  }

  Future<void> _loadDeezerPersonalized() async {
    if (_deezerPersonalizedTracks.isNotEmpty || _isLoadingPersonalized) return;
    _isLoadingPersonalized = true;

    try {
      final libraryProvider =
          Provider.of<LibraryProvider>(context, listen: false);
      final recommendationService =
          Provider.of<RecommendationService>(context, listen: false);

      final Set<String> seedArtists = {};

      // 1. Top artists from recommendation profile
      for (final artist in recommendationService.getRecommendedArtists(limit: 5)) {
        if (artist.trim().isNotEmpty) seedArtists.add(artist.trim());
      }

      // 2. Artists from recent albums
      for (final album in libraryProvider.recentAlbums.take(6)) {
        if (album.artist != null && album.artist!.trim().isNotEmpty) {
          seedArtists.add(album.artist!.trim());
        }
      }

      // 3. Artists from starred songs
      final starredList = libraryProvider.starred?.songs ?? [];
      for (final song in starredList.take(8)) {
        final a = song.artist;
        if (a != null && a.trim().isNotEmpty) {
          seedArtists.add(a.trim());
        }
      }

      // 4. Fallback to library artists
      for (final artist in libraryProvider.artists.take(5)) {
        if (artist.name.trim().isNotEmpty) {
          seedArtists.add(artist.name.trim());
        }
      }

      final filteredSeeds = seedArtists
          .where((name) =>
              name.length >= 2 &&
              !name.toLowerCase().contains('inconnu') &&
              !name.toLowerCase().contains('unknown'))
          .take(3)
          .toList();

      final deezerService = DeezerService();
      final List<Song> recommended = [];
      final Set<String> seenIds = {};

      for (final artistName in filteredSeeds) {
        final dzArtist = await deezerService.searchArtistByName(artistName);
        if (dzArtist != null && dzArtist.id.isNotEmpty) {
          final radioTracks = await deezerService
              .fetchSimilarArtistTracks(dzArtist.id, limit: 8);
          for (final t in radioTracks) {
            if (!seenIds.contains(t.id)) {
              seenIds.add(t.id);
              recommended.add(t);
            }
          }
        }
      }

      // If user has no playback history yet, provide chart tracks as intelligent start
      if (recommended.isEmpty) {
        final chartTracks = await deezerService.getChartTracks(limit: 15);
        recommended.addAll(chartTracks);
      }

      if (mounted) {
        setState(() {
          _deezerPersonalizedTracks = recommended;
          _isLoadingPersonalized = false;
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] Erreur chargement recommandations Deezer: $e');
      if (mounted) setState(() => _isLoadingPersonalized = false);
    }
  }

  Future<void> _loadDeezerCharts() async {
    if (_deezerChartTracks.isNotEmpty || _isLoadingCharts) return;
    setState(() => _isLoadingCharts = true);
    try {
      final tracks = await DeezerService().getChartTracks(limit: 30);
      if (mounted) {
        setState(() {
          _deezerChartTracks = tracks;
          _isLoadingCharts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCharts = false);
    }
  }

  String _selectedCategory = 'All';

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return AppLocalizations.of(context)?.goodMorning ?? 'Good morning';
    }
    if (hour < 17) {
      return AppLocalizations.of(context)?.goodAfternoon ?? 'Good afternoon';
    }
    return AppLocalizations.of(context)?.goodEvening ?? 'Good evening';
  }


  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  void _openAlbum(BuildContext context, String albumId, {Album? album}) async {
    if (album?.songCount == 1) {
      await _playAlbum(context, albumId);
      return;
    }
    if (context.mounted) {
      NavigationHelper.push(
        context,
        AlbumScreen(albumId: albumId),
      );
    }
  }

  void _openPlaylist(BuildContext context, Playlist playlist) {
    NavigationHelper.push(
      context,
      PlaylistScreen(playlistId: playlist.id, playlistName: playlist.name),
    );
  }

  void _openArtist(BuildContext context, String artistId) {
    NavigationHelper.push(
      context,
      ArtistScreen(artistId: artistId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = _isDesktop;
    final hPad = isDesktop ? 32.0 : 16.0;
    final authProvider = Provider.of<AuthProvider>(context);
    final subsonicService = Provider.of<SubsonicService>(context);

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: () async {
          setState(() {
            _cachedMixes = const {};
            _cachedPersonalized = const [];
            _cachedListenAgain = const [];
            _cachedTopHits = const [];
            _deezerChartTracks = const [];
            _deezerPersonalizedTracks = const [];
          });
          _loadDeezerCharts();
          _loadDeezerPersonalized();
          _triggerDiscoveryGeneration(force: true);
          final libraryProvider =
              Provider.of<LibraryProvider>(context, listen: false);
          await libraryProvider.refresh();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: true,
              floating: true,
              expandedHeight: 110,
              backgroundColor:
                  isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(left: hPad, bottom: 48),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getGreeting(),
                      style: TextStyle(
                        fontSize: isDesktop ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    CupertinoIcons.clock,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 22,
                  ),
                  tooltip: AppLocalizations.of(context)!.history,
                  onPressed: () =>
                      NavigationHelper.push(context, const HistoryScreen()),
                ),
                IconButton(
                  icon: Icon(
                    CupertinoIcons.gear_alt,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 22,
                  ),
                  tooltip: AppLocalizations.of(context)!.settings,
                  onPressed: () =>
                      NavigationHelper.push(context, const SettingsScreen()),
                ),
                if (isDesktop) const SizedBox(width: 12),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  height: 48,
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 6),
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildCategoryChip('All', 'All', isDark),
                        const SizedBox(width: 8),
                        _buildCategoryChip('Music', 'Music', isDark),
                        const SizedBox(width: 8),
                        _buildCategoryChip(
                            'MadeForYou', 'Créé pour vous', isDark),
                        const SizedBox(width: 8),
                        _buildCategoryChip('Playlists', 'Playlists', isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Consumer2<LibraryProvider, RecommendationService>(
                builder: (context, libraryProvider, recommendationService, _) {
                  if (libraryProvider.isLoading &&
                      !libraryProvider.isInitialized) {
                    return _buildLoadingState(isDesktop, hPad);
                  }

                  final allSongs = libraryProvider.cachedAllSongs.isNotEmpty
                      ? libraryProvider.cachedAllSongs
                      : libraryProvider.randomSongs;

                  if (recommendationService.enabled && allSongs.isNotEmpty) {
                    // Stabilize recommendations: only generate once or on manual pull-to-refresh
                    if (_cachedPersonalized.isEmpty) {
                      _cachedMixes =
                          recommendationService.generateMixes(allSongs);
                      _cachedPersonalized = recommendationService
                          .getPersonalizedFeed(allSongs, limit: 12);
                      _cachedListenAgain = recommendationService
                          .getListenAgain(allSongs, limit: 10);
                      _cachedTopHits =
                          recommendationService.getTopHits(allSongs, limit: 10);
                    }
                  } else if (!recommendationService.enabled) {
                    _cachedMixes = const {};
                    _cachedPersonalized = const [];
                    _cachedListenAgain = const [];
                    _cachedTopHits = const [];
                  }

                  var mixes = _cachedMixes;
                  var personalizedFeed = _cachedPersonalized;
                  var listenAgain = _cachedListenAgain;
                  var topHits = _cachedTopHits;
                  var recentAlbums = libraryProvider.recentAlbums;
                  var playlists = libraryProvider.playlists;
                  var artists = libraryProvider.artists;

                  // Pinned #1: In-App Discovery Mix autonomously generated
                  final discoveryService = DiscoveryService();
                  Playlist? discoveryPlaylist = discoveryService.currentDiscoveryPlaylist;
                  if (discoveryPlaylist == null) {
                    for (final p in playlists) {
                      if (p.id.startsWith('pl_discovery_') || p.name.contains('DÉCOUVERTES')) {
                        discoveryPlaylist = p;
                        break;
                      }
                    }
                    if (discoveryPlaylist == null && playlists.isNotEmpty) {
                      discoveryPlaylist = playlists.first;
                    }
                  }

                  if (artists.isEmpty && recommendationService.enabled) {
                    final topNames =
                        recommendationService.getRecommendedArtists(limit: 10);
                    if (topNames.isNotEmpty) {
                      artists = topNames
                          .map((name) => Artist(id: 'yt-$name', name: name))
                          .toList();
                    }
                  }

                  final isOffline = authProvider.state == AuthState.offlineMode;
                  final offlineService = OfflineService();

                  if (isOffline) {
                    final downloadedIds =
                        offlineService.getDownloadedSongIds().toSet();
                    final downloadedPlaylistIds =
                        offlineService.downloadedPlaylistIds.value.toSet();
                    final allSongs = libraryProvider.cachedAllSongs;
                    final Set<String> downloadedAlbumIds = {};
                    for (final song in allSongs) {
                      if (downloadedIds.contains(song.id) &&
                          song.albumId != null) {
                        downloadedAlbumIds.add(song.albumId!);
                      }
                    }

                    recentAlbums = recentAlbums
                        .where((a) => downloadedAlbumIds.contains(a.id))
                        .toList();
                    playlists = playlists
                        .where((p) => downloadedPlaylistIds.contains(p.id))
                        .toList();

                    final Map<String, List<Song>> offlineMixes = {};
                    for (final entry in mixes.entries) {
                      final filtered = entry.value
                          .where((s) => downloadedIds.contains(s.id))
                          .toList();
                      if (filtered.isNotEmpty) {
                        offlineMixes[entry.key] = filtered;
                      }
                    }
                    mixes = offlineMixes;

                    personalizedFeed = personalizedFeed
                        .where((s) => downloadedIds.contains(s.id))
                        .toList();
                    listenAgain = listenAgain
                        .where((s) => downloadedIds.contains(s.id))
                        .toList();
                    topHits = topHits
                        .where((s) => downloadedIds.contains(s.id))
                        .toList();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isDesktop && WrappedService.isWrappedSeason()) ...[
                          _buildWrappedBanner(context, hPad, isDesktop),
                          const SizedBox(height: 12),
                        ],
                        // 1. Top Banner « À la une » (Apple Music Hero)
                        if (discoveryPlaylist != null &&
                            (_selectedCategory == 'All' ||
                                _selectedCategory == 'MadeForYou')) ...[
                          _buildDiscoveryHeroBanner(
                            context,
                            discoveryPlaylist: discoveryPlaylist,
                            isDesktop: isDesktop,
                            hPad: hPad,
                          ),
                          const SizedBox(height: 16),
                        ],
                        // 2. Grille des 6 raccourcis essentiels
                        if (_selectedCategory == 'All' ||
                            _selectedCategory == 'Music') ...[
                          _buildSpotifyTopGrid(
                            context,
                            recentAlbums: recentAlbums,
                            playlists: playlists,
                            mixes: mixes,
                            subsonicService: subsonicService,
                            isDesktop: isDesktop,
                            hPad: hPad,
                          ),
                          const SizedBox(height: 24),
                        ],
                        // 3. Écoutés récemment (Recently Played)
                        if ((_selectedCategory == 'All' ||
                                _selectedCategory == 'Music') &&
                            recentAlbums.isNotEmpty) ...[
                          HorizontalScrollSection(
                            title: 'Écoutés récemment',
                            padding: EdgeInsets.symmetric(horizontal: hPad),
                            cardSize: isDesktop ? 180 : 155,
                            children: recentAlbums.take(12).map((album) {
                              return MediaCard(
                                title: album.name,
                                subtitle: album.artist,
                                coverArt: album.coverArt,
                                size: isDesktop ? 180 : 155,
                                onTap: () =>
                                    _openAlbum(context, album.id, album: album),
                                onPlayPressed: () =>
                                    _playAlbum(context, album.id),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 28),
                        ],
                        // 4. Made For You Intelligent Deezer (« Sélectionné pour vous »)
                        if ((_selectedCategory == 'All' ||
                                _selectedCategory == 'MadeForYou') &&
                            _deezerPersonalizedTracks.isNotEmpty) ...[
                          HorizontalScrollSection(
                            title: 'Sélectionné pour vous',
                            padding: EdgeInsets.symmetric(horizontal: hPad),
                            cardSize: isDesktop ? 180 : 155,
                            children:
                                _deezerPersonalizedTracks.take(15).map((song) {
                              final cardSize = isDesktop ? 180.0 : 155.0;
                              return MediaCard(
                                title: song.title,
                                subtitle: song.artist,
                                coverArt: song.coverArt,
                                size: cardSize,
                                onTap: () => _playSong(
                                    context, song, _deezerPersonalizedTracks),
                                onPlayPressed: () => _playSong(
                                    context, song, _deezerPersonalizedTracks),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 28),
                        ],
                        // 5. Tendances & Tops du Jour (Deezer Charts)
                        if ((_selectedCategory == 'All' ||
                                _selectedCategory == 'Music') &&
                            _deezerChartTracks.isNotEmpty) ...[
                          HorizontalScrollSection(
                            title: 'Tendances & Tops du Jour',
                            padding: EdgeInsets.symmetric(horizontal: hPad),
                            cardSize: isDesktop ? 180 : 155,
                            children: _deezerChartTracks.take(15).map((song) {
                              final cardSize = isDesktop ? 180.0 : 155.0;
                              return MediaCard(
                                title: song.title,
                                subtitle: song.artist,
                                coverArt: song.coverArt,
                                size: cardSize,
                                onTap: () => _playSong(
                                    context, song, _deezerChartTracks),
                                onPlayPressed: () => _playSong(
                                    context, song, _deezerChartTracks),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 28),
                        ],
                        // --- Vues Spécialisées par Filtre (Chips) ---
                        // Filtre « Créé pour vous » : Mixs et Découvertes approfondies
                        if (_selectedCategory == 'MadeForYou') ...[
                          if (recommendationService.enabled &&
                              personalizedFeed.isNotEmpty) ...[
                            _buildMixSection(
                              context: context,
                              title: 'Mix Découverte',
                              icon: CupertinoIcons.sparkles,
                              songs: personalizedFeed,
                              isDesktop: isDesktop,
                              hPad: hPad,
                            ),
                            const SizedBox(height: 28),
                          ],
                          if (topHits.isNotEmpty) ...[
                            _buildMixSection(
                              context: context,
                              title: 'Vos plus grands succès',
                              icon: CupertinoIcons.heart_fill,
                              songs: topHits,
                              isDesktop: isDesktop,
                              hPad: hPad,
                            ),
                            const SizedBox(height: 28),
                          ],
                          for (final entry in mixes.entries.take(4))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 28),
                              child: _buildMixSection(
                                context: context,
                                title: entry.key,
                                icon: CupertinoIcons.music_note_list,
                                songs: entry.value,
                                isDesktop: isDesktop,
                                hPad: hPad,
                              ),
                            ),
                        ],
                        // Filtre « Playlists » : Playlists de l'utilisateur
                        if (_selectedCategory == 'Playlists') ...[
                          _buildFavoritePlaylistRows(
                            context,
                            playlists: playlists,
                            isDesktop: isDesktop,
                            hPad: hPad,
                          ),
                          if (playlists.isNotEmpty) ...[
                            HorizontalScrollSection(
                              title: 'Vos playlists',
                              padding: EdgeInsets.symmetric(horizontal: hPad),
                              cardSize: isDesktop ? 180 : 155,
                              children: playlists.take(16).map((playlist) {
                                final cardSize = isDesktop ? 180.0 : 155.0;
                                return MediaCard(
                                  title: playlist.name,
                                  subtitle: 'Playlist • Musly',
                                  coverArt: playlist.coverArt,
                                  artwork: PlaylistArtwork(
                                    playlist: playlist,
                                    size: cardSize - 24,
                                    borderRadius: 4,
                                  ),
                                  size: cardSize,
                                  onTap: () => _openPlaylist(context, playlist),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 28),
                          ],
                        ],
                        // Filtre « Music » : Artistes favoris
                        if (_selectedCategory == 'Music' &&
                            artists.isNotEmpty) ...[
                          HorizontalScrollSection(
                            title: 'Artistes favoris',
                            padding: EdgeInsets.symmetric(horizontal: hPad),
                            cardSize: isDesktop ? 160 : 140,
                            children: artists.take(10).map((artist) {
                              final coverArt = artist.coverArt ??
                                  artist.artistImageUrl ??
                                  (artist.id.isNotEmpty
                                      ? 'ar-${artist.id}'
                                      : null);
                              return MediaCard(
                                title: artist.name,
                                subtitle: 'Artist',
                                coverArt: coverArt,
                                isRound: true,
                                size: isDesktop ? 160 : 140,
                                onTap: () => _openArtist(context, artist.id),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String key, String label, bool isDark) {
    final isSelected = _selectedCategory == key;
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary =
        ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
            ? Colors.white
            : Colors.black;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? primary
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? onPrimary
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildSpotifyTopGrid(
    BuildContext context, {
    required List<Album> recentAlbums,
    required List<Playlist> playlists,
    required Map<String, List<Song>> mixes,
    required SubsonicService subsonicService,
    required bool isDesktop,
    required double hPad,
  }) {
    final cols = isDesktop ? 4 : 2;
    final libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
    final favService = FavoritePlaylistsService();

    // 1. Déterminer la playlist la plus écoutée / favorite de l'utilisateur
    Playlist? topPlaylist;
    final favIds = favService.getFavoriteIds();
    if (favIds.isNotEmpty) {
      for (final p in playlists) {
        if (favIds.contains(p.id)) {
          topPlaylist = p;
          break;
        }
      }
    }
    topPlaylist ??= playlists.isNotEmpty ? playlists.first : null;

    final String playlistName = topPlaylist != null
        ? topPlaylist.name
            .replaceAll(
                RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true),
                '')
            .trim()
        : 'Ma playlist';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = 8.0;
          final totalSpacing = spacing * (cols - 1);
          final cardWidth = (constraints.maxWidth - totalSpacing) / cols;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              // Case 1 : Titres likés
              SizedBox(
                width: cardWidth,
                child: QuickAccessTile(
                  title: 'Titres likés',
                  subtitle: '${libraryProvider.starred?.songs.length ?? 0} titres',
                  customArtwork: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF450AF5), Color(0xFF8E8EE5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(CupertinoIcons.heart_fill,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  onTap: () =>
                      NavigationHelper.push(context, const FavoritesScreen()),
                ),
              ),

              // Case 2 : Playlist la plus écoutée / favorite
              SizedBox(
                width: cardWidth,
                child: QuickAccessTile(
                  title: playlistName.isEmpty ? 'Ma playlist' : playlistName,
                  subtitle: 'Ma playlist',
                  imageUrl: topPlaylist?.coverArt,
                  onTap: () {
                    if (topPlaylist != null) {
                      _openPlaylist(context, topPlaylist);
                    }
                  },
                ),
              ),

              // Case 3 : Top Album du moment d'après Deezer
              SizedBox(
                width: cardWidth,
                child: QuickAccessTile(
                  title: _topDeezerAlbum?.name ??
                      (recentAlbums.isNotEmpty ? recentAlbums.first.name : 'Top Album'),
                  subtitle: _topDeezerAlbum?.artist != null
                      ? '${_topDeezerAlbum!.artist} • Deezer'
                      : 'Top Album Deezer',
                  imageUrl: _topDeezerAlbum?.coverArt ??
                      (recentAlbums.isNotEmpty ? recentAlbums.first.coverArt : null),
                  onTap: () {
                    if (_topDeezerAlbum != null) {
                      _openAlbum(context, _topDeezerAlbum!.id, album: _topDeezerAlbum);
                    } else if (recentAlbums.isNotEmpty) {
                      _openAlbum(context, recentAlbums.first.id, album: recentAlbums.first);
                    }
                  },
                  onPlayPressed: _topDeezerAlbum != null
                      ? () => _playAlbum(context, _topDeezerAlbum!.id)
                      : null,
                ),
              ),

              // Case 4 : Artiste Découverte suggéré selon ce qu'écoute l'utilisateur
              SizedBox(
                width: cardWidth,
                child: QuickAccessTile(
                  title: _suggestedDiscoveryArtist?.name ?? 'Artiste Découverte',
                  subtitle: 'Découverte suggérée',
                  imageUrl: _suggestedDiscoveryArtist?.coverArt,
                  onTap: () {
                    if (_suggestedDiscoveryArtist != null) {
                      _openArtist(context, _suggestedDiscoveryArtist!.id);
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMixSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Song> songs,
    required bool isDesktop,
    required double hPad,
  }) {
    final cardSize = isDesktop ? 180.0 : 155.0;

    return HorizontalScrollSection(
      title: title,
      padding: EdgeInsets.symmetric(horizontal: hPad),
      cardSize: cardSize,
      children: songs.take(12).map((song) {
        return MediaCard(
          title: song.title,
          subtitle: song.artist,
          coverArt: song.coverArt,
          size: cardSize,
          onTap: () => _playSong(context, song, songs),
          onPlayPressed: () => _playSong(context, song, songs),
        );
      }).toList(),
    );
  }

  Widget _buildFavoritePlaylistRows(
    BuildContext context, {
    required List<Playlist> playlists,
    required bool isDesktop,
    required double hPad,
  }) {
    final enabledNotifier =
        PlayerUiSettingsService().showFavoritePlaylistsOnHomeNotifier;
    final favoritesService = FavoritePlaylistsService();

    return ListenableBuilder(
      listenable: Listenable.merge([enabledNotifier, favoritesService]),
      builder: (context, _) {
        if (!enabledNotifier.value || !favoritesService.hasFavorites) {
          return const SizedBox.shrink();
        }

        final favoriteIds = favoritesService.getFavoriteIds().toSet();
        final favorites =
            playlists.where((p) => favoriteIds.contains(p.id)).toList()
              // Most recently updated playlists first.
              ..sort((a, b) => _lastUpdate(b).compareTo(_lastUpdate(a)));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final playlist in favorites)
              _FavoritePlaylistRow(
                key: ValueKey('favorite_playlist_${playlist.id}'),
                playlist: playlist,
                isDesktop: isDesktop,
                hPad: hPad,
                onOpen: () => _openPlaylist(context, playlist),
                onPlaySong: (song, songs) => _playSong(context, song, songs),
              ),
          ],
        );
      },
    );
  }

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  static DateTime _lastUpdate(Playlist playlist) =>
      playlist.changed ?? playlist.created ?? _epoch;

  Future<void> _playSong(
      BuildContext context, Song song, List<Song> queue) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final idx = queue.indexOf(song);
    await playerProvider.playSong(song,
        playlist: queue, startIndex: idx >= 0 ? idx : 0);
  }

  Future<void> _playAlbum(BuildContext context, String albumId) async {
    try {
      final subsonicService =
          Provider.of<SubsonicService>(context, listen: false);
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);
      final songs = await subsonicService.getAlbumSongs(albumId);
      if (songs.isNotEmpty) {
        await playerProvider.playSong(songs.first,
            playlist: songs, startIndex: 0);
      }
    } catch (e) {
      debugPrint('Error playing album: $e');
    }
  }

  Widget _buildLoadingState(bool isDesktop, double hPad) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: 140,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => Container(
                width: 140,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWrappedBanner(
      BuildContext context, double hPad, bool isDesktop) {
    final year = WrappedService.getWrappedYear();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            NavigationHelper.push(context, const WrappedScreen());
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFA243C), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFA243C).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.sparkles,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#MuslyPlayback $year',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)?.yourYearInReviewIsReady ??
                            'Votre rétrospective musicale est prête !',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.chevron_forward,
                    color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoveryHeroBanner(
    BuildContext context, {
    required Playlist discoveryPlaylist,
    required bool isDesktop,
    required double hPad,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    final cleanTitle = discoveryPlaylist.name
        .replaceAll(
            RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true), '')
        .trim();

    final coverArt = discoveryPlaylist.coverArt;
    final bannerHeight = isDesktop ? 190.0 : 165.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPlaylist(context, discoveryPlaylist),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: bannerHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0C0C0F) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? const Color(0x24FFFFFF) : const Color(0x14000000),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: isDark ? 0.22 : 0.12),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // 1. Dégradé de fond riche et vibrant style Apple Music
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                primary.withValues(alpha: 0.28),
                                const Color(0xFF8B5CF6).withValues(alpha: 0.16),
                                const Color(0xFF090A0F),
                              ]
                            : [
                                primary.withValues(alpha: 0.15),
                                const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                                Colors.white,
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),

                // 2. Halo lumineux radial dans l'angle supérieur gauche
                Positioned(
                  top: -40,
                  left: -40,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          primary.withValues(alpha: isDark ? 0.35 : 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Pochette de l'album fondue en douceur (dégradé progressif sans coupure nette)
                if (coverArt != null && coverArt.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: -20,
                    bottom: -20,
                    width: bannerHeight + 60,
                    child: ShaderMask(
                      shaderCallback: (rect) {
                        return const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Color(0x22FFFFFF),
                            Color(0x99FFFFFF),
                            Colors.white,
                          ],
                          stops: [0.0, 0.35, 0.7, 1.0],
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.dstIn,
                      child: Opacity(
                        opacity: isDark ? 0.25 : 0.18,
                        child: AlbumArtwork(
                          coverArt: coverArt,
                          size: bannerHeight + 60,
                        ),
                      ),
                    ),
                  ),

                // 4. Contenu au premier plan
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge supérieur
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: isDark ? 0.25 : 0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: primary.withValues(alpha: 0.35),
                                width: 0.6,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.sparkles, color: primary, size: 12.5),
                                const SizedBox(width: 5),
                                Text(
                                  'À LA UNE • MIX DU JOUR',
                                  style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${discoveryPlaylist.songCount ?? 35} titres',
                              style: TextStyle(
                                color: isDark ? const Color(0xFFC7C7CC) : const Color(0xFF636366),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Titre & Sous-titre & Bouton Play avec artwork miniature
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (coverArt != null && coverArt.isNotEmpty) ...[
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withValues(alpha: 0.40),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AlbumArtwork(
                                  coverArt: coverArt,
                                  size: 58,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cleanTitle.isEmpty ? discoveryPlaylist.name : cleanTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '35 pépites selon vos écoutes',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6B7280),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () async {
                              final libraryProvider =
                                  Provider.of<LibraryProvider>(context, listen: false);
                              final playerProvider =
                                  Provider.of<PlayerProvider>(context, listen: false);
                              final full = await libraryProvider.getPlaylist(discoveryPlaylist.id);
                              final songs = full.songs ?? [];
                              if (songs.isNotEmpty) {
                                await playerProvider.playSong(songs.first, playlist: songs, startIndex: 0);
                              }
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withValues(alpha: 0.45),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 32,
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
          ),
        ),
      ),
    );
  }

}

class _FavoritePlaylistRow extends StatefulWidget {
  final Playlist playlist;
  final bool isDesktop;
  final double hPad;
  final VoidCallback onOpen;
  final void Function(Song song, List<Song> songs) onPlaySong;

  const _FavoritePlaylistRow({
    super.key,
    required this.playlist,
    required this.isDesktop,
    required this.hPad,
    required this.onOpen,
    required this.onPlaySong,
  });

  @override
  State<_FavoritePlaylistRow> createState() => _FavoritePlaylistRowState();
}

class _FavoritePlaylistRowState extends State<_FavoritePlaylistRow> {
  /// Last successfully fetched version of each playlist, shared across rows
  /// so a playlist is fetched once per app session and again only when the
  /// server reports a newer `changed` timestamp.
  static final Map<String, Playlist> _fetched = {};
  static final Set<String> _inFlight = {};

  @override
  void initState() {
    super.initState();
    _refreshSongsIfStale();
  }

  @override
  void didUpdateWidget(covariant _FavoritePlaylistRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshSongsIfStale();
  }

  void _refreshSongsIfStale() {
    final playlist = widget.playlist;
    final fetched = _fetched[playlist.id];
    if (_inFlight.contains(playlist.id) ||
        (fetched != null && fetched.changed == playlist.changed)) {
      return;
    }
    _inFlight.add(playlist.id);

    // Playlists from getPlaylists() carry no entries, and cached entries may
    // be outdated. Fetching stores the songs in the LibraryProvider, which
    // rebuilds this row with them. A failed fetch is retried on next rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        final fetched =
            await Provider.of<LibraryProvider>(context, listen: false)
                .getPlaylist(playlist.id);
        _fetched[playlist.id] = fetched;
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('Error loading favorite playlist: $e');
      } finally {
        _inFlight.remove(playlist.id);
      }
    });
  }

  /// The provider may hand back a summary without entries (e.g. right after a
  /// library refresh); fall back to the fetched songs of the same version.
  List<Song> _songs() {
    final playlist = widget.playlist;
    final songs = playlist.songs;
    if (songs != null && songs.isNotEmpty) return songs;
    final fetched = _fetched[playlist.id];
    if (fetched != null && fetched.changed == playlist.changed) {
      return fetched.songs ?? const <Song>[];
    }
    return const <Song>[];
  }

  @override
  Widget build(BuildContext context) {
    final songs = _songs();
    if (songs.isEmpty) return const SizedBox.shrink();

    final cardSize = widget.isDesktop ? 180.0 : 155.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: HorizontalScrollSection(
        title: widget.playlist.name,
        padding: EdgeInsets.symmetric(horizontal: widget.hPad),
        cardSize: cardSize,
        onSeeAllTap: widget.onOpen,
        children: songs.take(12).map((song) {
          return MediaCard(
            title: song.title,
            subtitle: song.artist,
            coverArt: song.coverArt,
            size: cardSize,
            onTap: () => widget.onPlaySong(song, songs),
            onPlayPressed: () => widget.onPlaySong(song, songs),
          );
        }).toList(),
      ),
    );
  }
}
