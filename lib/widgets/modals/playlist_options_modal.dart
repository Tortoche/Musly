import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/favorite_playlists_service.dart';
import '../../services/offline_service.dart';
import '../../services/playlist_cover_service.dart';
import '../../services/subsonic_service.dart';
import '../../theme/app_theme.dart';
import '../common/playlist_artwork.dart';

class PlaylistOptionsModal extends StatelessWidget {
  final Playlist playlist;

  const PlaylistOptionsModal({super.key, required this.playlist});

  static Future<void> show(BuildContext context, Playlist playlist) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PlaylistOptionsModal(playlist: playlist),
    );
  }

  static Future<bool> confirmAndDelete(
    BuildContext context,
    Playlist playlist,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final libraryProvider =
        Provider.of<LibraryProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deletePlaylist),
        content: Text(l10n.deletePlaylistConfirmation(playlist.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      List<Song> songs = playlist.songs ?? [];
      if (songs.isEmpty) {
        final index =
            libraryProvider.playlists.indexWhere((p) => p.id == playlist.id);
        if (index != -1) {
          songs = libraryProvider.playlists[index].songs ?? [];
        }
      }

      final isDownloaded =
          OfflineService().downloadedPlaylistIds.value.contains(playlist.id) ||
              OfflineService().queuedPlaylistIds.value.contains(playlist.id);
      OfflineService().cancelPlaylistDownload(playlist.id);
      if (isDownloaded && songs.isNotEmpty) {
        try {
          await OfflineService().deletePlaylistDownloads(songs);
        } catch (_) {}
      }
      try {
        await FavoritePlaylistsService().removeFavorite(playlist.id);
      } catch (_) {}
      try {
        await PlaylistCoverService().deleteCover(playlist.id);
      } catch (_) {}

      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.playlistDeleted(playlist.name)),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await libraryProvider.deletePlaylist(playlist.id);
    } catch (_) {}

    return true;
  }

  Future<List<Song>> _fetchSongsIfNeeded(
    SubsonicService subsonic,
    LibraryProvider libraryProvider,
  ) async {
    if (playlist.songs != null && playlist.songs!.isNotEmpty) {
      return playlist.songs!;
    }
    try {
      final fullPlaylist = await subsonic.getPlaylist(playlist.id);
      return fullPlaylist.songs ?? [];
    } catch (_) {
      final index =
          libraryProvider.playlists.indexWhere((p) => p.id == playlist.id);
      if (index != -1) {
        return libraryProvider.playlists[index].songs ?? [];
      }
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final favoriteService = FavoritePlaylistsService();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    PlaylistArtwork(
                      playlist: playlist,
                      size: 54,
                      borderRadius: 8,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.songsCount(playlist.songCount ?? 0),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppTheme.darkSecondaryText
                                  : AppTheme.lightSecondaryText,
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
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _OptionTile(
                        icon: CupertinoIcons.play_circle,
                        title: l10n.play,
                        onTap: () async {
                          final player = Provider.of<PlayerProvider>(
                            context,
                            listen: false,
                          );
                          final subsonic = Provider.of<SubsonicService>(
                            context,
                            listen: false,
                          );
                          final lib = Provider.of<LibraryProvider>(
                            context,
                            listen: false,
                          );
                          Navigator.pop(context);
                          final songs =
                              await _fetchSongsIfNeeded(subsonic, lib);
                          if (songs.isNotEmpty) {
                            player.playSong(
                              songs.first,
                              playlist: songs,
                              startIndex: 0,
                            );
                          }
                        },
                      ),
                      _OptionTile(
                        icon: CupertinoIcons.text_badge_plus,
                        title: l10n.addAllToQueue,
                        onTap: () async {
                          final player = Provider.of<PlayerProvider>(
                            context,
                            listen: false,
                          );
                          final subsonic = Provider.of<SubsonicService>(
                            context,
                            listen: false,
                          );
                          final lib = Provider.of<LibraryProvider>(
                            context,
                            listen: false,
                          );
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);
                          final songs =
                              await _fetchSongsIfNeeded(subsonic, lib);
                          if (songs.isNotEmpty) {
                            for (final song in songs) {
                              player.addToQueue(song);
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                content:
                                    Text(l10n.songsAddedToQueue(songs.length)),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                      AnimatedBuilder(
                        animation: favoriteService,
                        builder: (context, _) {
                          final isFavorite =
                              favoriteService.isFavorite(playlist.id);
                          return _OptionTile(
                            icon: isFavorite
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.heart,
                            title: isFavorite
                                ? l10n.removeFromFavorites
                                : l10n.addToFavorites,
                            iconColor: isFavorite ? Colors.red : null,
                            onTap: () {
                              favoriteService.toggleFavorite(playlist.id);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                      _OptionTile(
                        icon: CupertinoIcons.trash,
                        title: l10n.deletePlaylist,
                        iconColor: Colors.red,
                        titleColor: Colors.red,
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          final deleted =
                              await confirmAndDelete(context, playlist);
                          if (deleted && navigator.canPop()) {
                            navigator.pop();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
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

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontWeight: titleColor != null ? FontWeight.w600 : null,
        ),
      ),
      onTap: onTap,
    );
  }
}
