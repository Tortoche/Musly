import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:musly/models/lyric_line.dart';
import 'package:musly/providers/player_provider.dart';
import 'package:musly/services/lrc_ttml_parser.dart';
import 'package:musly/services/services.dart';
import 'package:musly/widgets/common/album_artwork.dart';
import 'package:musly/utils/navigation_helper.dart';

class DesktopLyricsPanel extends StatefulWidget {
  final VoidCallback? onClose;

  const DesktopLyricsPanel({super.key, this.onClose});

  @override
  State<DesktopLyricsPanel> createState() => _DesktopLyricsPanelState();
}

class _DesktopLyricsPanelState extends State<DesktopLyricsPanel> {
  final ScrollController _scrollController = ScrollController();
  List<LyricLine> _lines = [];
  String? _plainText;
  bool _isSynced = false;
  bool _isLoading = false;
  String? _currentSongId;
  int _activeIndex = -1;
  final Map<int, GlobalKey> _lineKeys = {};
  bool _userIsScrolling = false;
  Timer? _resumeAutoScrollTimer;

  @override
  void initState() {
    super.initState();
    _syncDesktopWakelock();
    PlayerUiSettingsService()
        .lyricsKeepScreenOnNotifier
        .addListener(_syncDesktopWakelock);
    _loadLyricsForCurrentSong();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentSong = Provider.of<PlayerProvider>(context).currentSong;
    if (currentSong?.id != _currentSongId) {
      _loadLyricsForCurrentSong();
    }
  }

  Future<void> _loadLyricsForCurrentSong() async {
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final song = player.currentSong;
    if (song == null) {
      setState(() {
        _currentSongId = null;
        _lines = [];
        _plainText = null;
        _isSynced = false;
        _isLoading = false;
      });
      return;
    }

    _currentSongId = song.id;
    setState(() {
      _isLoading = true;
      _lines = [];
      _plainText = null;
      _isSynced = false;
      _activeIndex = -1;
      _lineKeys.clear();
    });

    try {
      final subsonic = Provider.of<SubsonicService>(context, listen: false);
      final offlineService = OfflineService();

      Map<String, dynamic>? rawLyrics;

      // Check local cache first (instant 0ms retrieval)
      rawLyrics = await offlineService.getLocalLyrics(song.id);

      if (rawLyrics == null && !offlineService.isOfflineMode) {
        rawLyrics = await subsonic.getLyricsBySongId(song.id) ??
            await subsonic.getLyrics(
              id: song.id,
              artist: song.artist,
              title: song.title,
              duration: song.duration,
            );
        if (rawLyrics != null) {
          offlineService.saveLyrics(song.id, rawLyrics).catchError((_) {});
        }
      }

      if (!mounted || _currentSongId != song.id) return;

      if (rawLyrics != null) {
        final structured = (rawLyrics['structuredLyrics'] ??
            rawLyrics['lyricsList']?['structuredLyrics']) as List?;
        if (structured != null && structured.isNotEmpty) {
          final first = structured.first;
          final isSynced = first['synced'] == true;
          final lines = first['line'] as List?;
          if (lines != null) {
            final parsed = lines
                .map((l) => LyricLine(
                      startTime:
                          Duration(milliseconds: l['start'] as int? ?? 0),
                      text: l['value'] as String? ?? '',
                    ))
                .where((l) => l.text.trim().isNotEmpty)
                .toList();
            if (parsed.isNotEmpty) {
              parsed.sort((a, b) => a.startTime.compareTo(b.startTime));
              for (var i = 0; i < parsed.length - 1; i++) {
                final current = parsed[i];
                final next = parsed[i + 1];
                parsed[i] = LyricLine(
                  text: current.text,
                  startTime: current.startTime,
                  endTime: next.startTime - const Duration(milliseconds: 1),
                  words: current.words,
                );
              }
              final hasTimestamps = LrcParser.hasTimestamps(parsed);
              if (isSynced && hasTimestamps) {
                setState(() {
                  _lines = parsed;
                  _plainText = null;
                  _isSynced = true;
                  _isLoading = false;
                });
                return;
              } else {
                setState(() {
                  _lines = [];
                  _plainText = parsed.map((l) => l.text).join('\n');
                  _isSynced = false;
                  _isLoading = false;
                });
                return;
              }
            }
          }
        }

        final lrcText =
            (rawLyrics['value'] ?? rawLyrics['lyrics']?['value']) as String?;
        if (lrcText != null && lrcText.trim().isNotEmpty) {
          final parsed = LrcParser.parseLrc(lrcText);
          final hasTimestamps = LrcParser.hasTimestamps(parsed);
          if (hasTimestamps) {
            setState(() {
              _lines = parsed;
              _plainText = null;
              _isSynced = true;
              _isLoading = false;
            });
            return;
          } else {
            setState(() {
              _lines = [];
              _plainText = lrcText;
              _isSynced = false;
              _isLoading = false;
            });
            return;
          }
        }
      }

      setState(() {
        _lines = [];
        _plainText = null;
        _isSynced = false;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _lines = [];
          _plainText = null;
          _isSynced = false;
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToActiveLine(int index) {
    if (_userIsScrolling || !_scrollController.hasClients) return;
    final key = _lineKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.45,
      );
    }
  }

  @override
  void dispose() {
    PlayerUiSettingsService()
        .lyricsKeepScreenOnNotifier
        .removeListener(_syncDesktopWakelock);
    WakelockService().disable('desktop_lyrics_panel');
    _scrollController.dispose();
    _resumeAutoScrollTimer?.cancel();
    super.dispose();
  }

  void _syncDesktopWakelock() {
    if (PlayerUiSettingsService().getLyricsKeepScreenOn()) {
      WakelockService().enable('desktop_lyrics_panel');
    } else {
      WakelockService().disable('desktop_lyrics_panel');
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    final currentSong = player.currentSong;

    return Container(
      width: 380,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        border: Border(
          left: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
        ),
      ),
      child: Stack(
        children: [
          if (currentSong?.coverArt != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.35,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                  child: Transform.scale(
                    scale: 1.3,
                    child: AlbumArtwork(
                      coverArt: currentSong!.coverArt,
                      size: 400,
                      borderRadius: 0,
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.65)),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 90,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF080808), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  widget.onClose?.call();
                  NavigationHelper.isDesktopLyricsOpen.value = false;
                },
                borderRadius: BorderRadius.circular(20),
                hoverColor: Colors.white.withValues(alpha: 0.1),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            top: 48,
            bottom: 68,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification) {
                  _userIsScrolling = true;
                  _resumeAutoScrollTimer?.cancel();
                  _resumeAutoScrollTimer =
                      Timer(const Duration(seconds: 4), () {
                    if (mounted) setState(() => _userIsScrolling = false);
                  });
                }
                return false;
              },
              child: _buildLyricsContent(player),
            ),
          ),
          Positioned(
            bottom: 64,
            left: 0,
            right: 0,
            height: 90,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xFF080808)],
                  ),
                ),
              ),
            ),
          ),
          if (currentSong != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 64,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF080808).withValues(alpha: 0.95),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.06),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    AlbumArtwork(
                      coverArt: currentSong.coverArt,
                      size: 40,
                      borderRadius: 6,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentSong.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentSong.artist ?? 'Unknown Artist',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_isSynced)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFA243C).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SYNC',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFA243C),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLyricsContent(PlayerProvider player) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        ),
      );
    }

    if (_isSynced && _lines.isNotEmpty) {
      return StreamBuilder<Duration>(
        stream: player.positionStream,
        initialData: player.position,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;

          int activeIndex = -1;
          if (_lines.any((l) => l.startTime > Duration.zero)) {
            for (int i = 0; i < _lines.length; i++) {
              if (position >= _lines[i].startTime) {
                activeIndex = i;
              } else {
                break;
              }
            }
          }

          if (activeIndex != _activeIndex && activeIndex >= 0) {
            _activeIndex = activeIndex;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToActiveLine(activeIndex);
            });
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(28, 60, 28, 60),
            itemCount: _lines.length,
            itemBuilder: (context, index) {
              final line = _lines[index];
              final distance = index - _activeIndex;
              final isActive = index == _activeIndex;

              double opacity;
              if (isActive) {
                opacity = 1.0;
              } else if (distance.abs() == 1) {
                opacity = 0.40;
              } else if (distance.abs() == 2) {
                opacity = 0.22;
              } else {
                opacity = 0.12;
              }

              final fontSize =
                  isActive ? 26.0 : (distance.abs() == 1 ? 20.0 : 16.0);
              final marginBottom = isActive ? 24.0 : 12.0;

              _lineKeys.putIfAbsent(index, () => GlobalKey());

              return KeyedSubtree(
                key: _lineKeys[index],
                child: Padding(
                  padding: EdgeInsets.only(bottom: marginBottom),
                  child: InkWell(
                    onTap: () {
                      player.seek(line.startTime);
                    },
                    borderRadius: BorderRadius.circular(6),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: fontSize,
                        fontWeight:
                            isActive ? FontWeight.w900 : FontWeight.w700,
                        color: Colors.white.withValues(alpha: opacity),
                        height: 1.25,
                      ),
                      child: Text(line.text),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    final plainLines = _plainText != null && _plainText!.trim().isNotEmpty
        ? _plainText!.split('\n')
        : (_lines.isNotEmpty ? _lines.map((l) => l.text).toList() : null);

    if (plainLines != null && plainLines.isNotEmpty) {
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
        itemCount: plainLines.length,
        itemBuilder: (context, index) {
          final line = plainLines[index];
          final isEmpty = line.trim().isEmpty;
          return Padding(
            padding: EdgeInsets.only(bottom: isEmpty ? 16 : 10),
            child: Text(
              line.isEmpty ? '\u00a0' : line,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: isEmpty ? 0.0 : 0.75),
                height: 1.35,
              ),
            ),
          );
        },
      );
    }

    return Center(
      child: Text(
        'Aucune parole disponible',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
