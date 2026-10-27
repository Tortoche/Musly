import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../l10n/app_localizations.dart';
import '../modals/song_options_modal.dart';
import '../common/album_artwork.dart';

class QueueView extends StatefulWidget {
  const QueueView({super.key});

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  final ScrollController _scrollController = ScrollController();

  /// Only attached to the current song until the initial scroll is done: the
  /// reorder drag proxy rebuilds its item, which would duplicate the key.
  final GlobalKey _currentItemKey = GlobalKey();
  bool _initialScrollDone = false;
  double _headerClearance = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent([int attempt = 0]) {
    if (!mounted) return;
    final provider = Provider.of<PlayerProvider>(context, listen: false);
    if (provider.currentIndex <= 0 ||
        attempt > 3 ||
        !_scrollController.hasClients) {
      setState(() => _initialScrollDone = true);
      return;
    }

    final position = _scrollController.position;
    final itemContext = _currentItemKey.currentContext;
    if (itemContext == null) {
      // The list is lazy: jump close to the current song, using the list's
      // own estimate of its tile extent, so that its tile gets built.
      final extent = (position.maxScrollExtent + position.viewportDimension) /
          provider.queue.length;
      _scrollController.jumpTo((provider.currentIndex * extent)
          .clamp(0.0, position.maxScrollExtent));
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToCurrent(attempt + 1));
      return;
    }

    // Align the current song right below the header overlay.
    Scrollable.ensureVisible(itemContext);
    _scrollController.jumpTo((position.pixels - _headerClearance)
        .clamp(0.0, position.maxScrollExtent));
    setState(() => _initialScrollDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<PlayerProvider>(
      builder: (context, provider, child) {
        final queue = provider.queue;
        final currentIndex = provider.currentIndex;

        if (queue.isEmpty) {
          return Center(
            child: Text(
              l10n.noSongsInQueue,
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
          );
        }

        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        final view = View.of(context);
        final viewPadding = MediaQueryData.fromView(view).padding;
        final mediaQueryPadding = MediaQuery.of(context).padding;
        final topPadding =
            viewPadding.top > 0 ? viewPadding.top : mediaQueryPadding.top;
        final headerClearance = topPadding > 0
            ? topPadding + (isLandscape ? 44.0 : 64.0)
            : (isLandscape ? 48.0 : 56.0);
        _headerClearance = headerClearance;

        return SafeArea(
          top: false,
          child: ReorderableListView.builder(
            scrollController: _scrollController,
            buildDefaultDragHandles: false,
            padding: EdgeInsets.only(
              top: headerClearance,
              bottom: 40,
              left: 24,
              right: 24,
            ),
            header: Padding(
              padding: const EdgeInsets.only(bottom: 20.0, left: 8.0, right: 8.0),
              child: Row(
                children: [
                  Text(
                    l10n.upNext,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _AutoplayInfinityButton(
                    isEnabled: provider.isAutoplayEnabled,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      provider.toggleAutoplay();
                    },
                  ),
                ],
              ),
            ),
            itemCount: queue.length,
            onReorder: (oldIndex, newIndex) {
              provider.reorderQueue(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final song = queue[index];
              final isPlaying = index == currentIndex;
              final isPast = index < currentIndex;

              return ListTile(
                key: ValueKey('queue_item_${song.id}_$index'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: KeyedSubtree(
                  key:
                      isPlaying && !_initialScrollDone ? _currentItemKey : null,
                  child: AlbumArtwork(
                    coverArt: song.coverArt,
                    size: 48,
                    borderRadius: 8,
                  ),
                ),
                title: Text(
                  song.title,
                  style: TextStyle(
                    color: isPlaying
                        ? Theme.of(context).colorScheme.primary
                        : (isPast ? Colors.white38 : Colors.white),
                    fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  song.artist ?? l10n.unknownArtist,
                  style: TextStyle(
                    color: isPlaying
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.8)
                        : (isPast ? Colors.white24 : Colors.white70),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPlaying)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.equalizer_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => SongOptionsModal.show(context, song),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4, right: 2),
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: Colors.white38,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  provider.skipToIndex(index);
                },
                onLongPress: () {
                  SongOptionsModal.show(context, song);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _AutoplayInfinityButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onTap;

  const _AutoplayInfinityButton({
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Semantics(
      label: 'Lecture automatique infinie',
      button: true,
      toggled: isEnabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isEnabled
                  ? primary.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isEnabled
                    ? primary.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.14),
                width: isEnabled ? 1.4 : 0.8,
              ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.all_inclusive_rounded,
                  size: 20,
                  color: isEnabled ? primary : Colors.white70,
                ),
                const SizedBox(width: 6),
                Text(
                  'Auto',
                  style: TextStyle(
                    color: isEnabled ? primary : Colors.white70,
                    fontSize: 12,
                    fontWeight: isEnabled ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.3,
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
