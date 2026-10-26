import '../../services/subsonic_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/library_provider.dart';
import '../../services/offline_service.dart';
import '../../widgets/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../detail/album_screen.dart';
import '../../utils/navigation_helper.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Song> _downloadedSongs = [];
  List<Album> _downloadedAlbums = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    setState(() => _isLoading = true);

    try {
      final offlineService = OfflineService();
      final libraryProvider =
          Provider.of<LibraryProvider>(context, listen: false);
      final subsonic =
          Provider.of<SubsonicService>(context, listen: false);

      await offlineService.initialize();
      final downloadedSongs = await offlineService.getDownloadedSongs(
        subsonicService: subsonic,
        fallbackSongs: libraryProvider.cachedAllSongs,
      );

      _downloadedSongs = downloadedSongs;

      final albumIdsWithDownloads = _downloadedSongs
          .map((s) => s.albumId)
          .where((id) => id != null)
          .toSet();

      final albumsMap = <String, Album>{};
      for (final a in libraryProvider.recentAlbums) {
        if (albumIdsWithDownloads.contains(a.id)) {
          albumsMap[a.id] = a;
        }
      }
      for (final s in _downloadedSongs) {
        if (s.albumId != null && !albumsMap.containsKey(s.albumId)) {
          albumsMap[s.albumId!] = Album(
            id: s.albumId!,
            name: s.album ?? 'Album téléchargé',
            artist: s.artist,
            artistId: s.artistId,
            coverArt: s.coverArt,
            year: s.year,
            songCount: _downloadedSongs
                .where((sub) => sub.albumId == s.albumId)
                .length,
          );
        }
      }
      _downloadedAlbums = albumsMap.values.toList();
    } catch (e) {
      debugPrint('Error loading downloads: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.downloads),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: PillTabBar(
            tabs: [l10n.songs, l10n.albums],
            selectedIndex: _selectedTab,
            onTabSelected: (idx) => setState(() => _selectedTab = idx),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedTab == 0
              ? _buildSongsList()
              : _buildAlbumsList(),
    );
  }

  Widget _buildSongsList() {
    final l10n = AppLocalizations.of(context)!;
    if (_downloadedSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.download_done_rounded,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(l10n.noDownloadedSongsYet),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 150),
      itemExtent: 68.0,
      itemCount: _downloadedSongs.length,
      itemBuilder: (context, index) {
        final song = _downloadedSongs[index];
        return SongTile(
          song: song,
          playlist: _downloadedSongs,
          index: index,
          showAlbum: true,
        );
      },
    );
  }

  Widget _buildAlbumsList() {
    final l10n = AppLocalizations.of(context)!;
    if (_downloadedAlbums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.album_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(l10n.noDownloadedAlbumsYet),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth > 900) {
          crossAxisCount = 5;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _downloadedAlbums.length,
          itemBuilder: (context, index) {
            final album = _downloadedAlbums[index];
            return AlbumCard(
              album: album,
              size: double.infinity,
              onTap: () => NavigationHelper.push(
                context,
                AlbumScreen(albumId: album.id),
              ),
            );
          },
        );
      },
    );
  }
}
