import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:musly/providers/providers.dart';
import 'package:musly/services/local_music_service.dart';
import '../../widgets/navigation/tv_remote_scope.dart';
import '../../services/tv_detection_service.dart';
import 'package:musly/services/recommendation_service.dart';
import 'package:musly/services/theme_service.dart';
import 'package:musly/services/usage_time_service.dart';
import 'package:musly/theme/app_theme.dart';
import 'package:musly/utils/navigation_helper.dart';
import 'package:musly/widgets/widgets.dart';
import 'package:musly/l10n/app_localizations.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'tv_main_screen.dart';
import 'package:musly/screens/media/fantasy_screen.dart';
import 'package:musly/services/haptics_service.dart';
import 'package:musly/services/deep_link_service.dart';

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class _PlayPauseAction extends Action<PlayPauseIntent> {
  final BuildContext context;
  _PlayPauseAction(this.context);

  @override
  bool isEnabled(PlayPauseIntent intent) {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null) {
      final focusedContext = primaryFocus.context;
      if (focusedContext != null &&
          focusedContext.findAncestorWidgetOfExactType<EditableText>() !=
              null) {
        return false;
      }
    }
    return true;
  }

  @override
  Object? invoke(PlayPauseIntent intent) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    playerProvider.togglePlayPause();
    return null;
  }
}

class MainScreen extends StatefulWidget {
  final bool isOfflineMode;

  const MainScreen({super.key, this.isOfflineMode = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _searchTapCount = 0;
  DateTime _lastSearchTap = DateTime.fromMillisecondsSinceEpoch(0);

  final List<Widget> _screens = const [
    HomeScreen(),
    LibraryScreen(),
    SearchScreen(),
  ];

  @override
  void dispose() {
    UsageTimeService().disposeService();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    NavigationHelper.registerTabChangeCallback((index) {
      setState(() => _currentIndex = index);
    });

    DeepLinkService().initialize();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final libraryProvider = Provider.of<LibraryProvider>(
        context,
        listen: false,
      );
      final playerProvider = Provider.of<PlayerProvider>(
        context,
        listen: false,
      );
      final recommendationService = Provider.of<RecommendationService>(
        context,
        listen: false,
      );

      playerProvider.setLibraryProvider(libraryProvider);
      playerProvider.setRecommendationService(recommendationService);

      playerProvider.onAudioFocusDenied = () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.audioFocusDenied),
          ),
        );
      };

      if (authProvider.isLocalOnlyMode) {
        final localMusicService = Provider.of<LocalMusicService>(
          context,
          listen: false,
        );

        libraryProvider.setLocalMusicService(localMusicService);

        if (localMusicService.isEmpty && !localMusicService.isScanning) {
          localMusicService.scanForMusic();
        } else if (!localMusicService.isScanning) {
          libraryProvider.initialize();
        }
      } else {
        libraryProvider.setLocalOnlyMode(false);
        libraryProvider.setServerOfflineMode(widget.isOfflineMode);
        libraryProvider.initialize();
      }

      UsageTimeService().initialize();

      _startUsageTimeChecker();

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _checkForUpdate();
      });
    });
  }

  void _startUsageTimeChecker() {
    Future.delayed(const Duration(minutes: 2), () {
      if (!mounted) return;

      final usageService = UsageTimeService();
      if (usageService.shouldShowDialog) {
        _showSupportDialog();
      } else {
        _startUsageTimeChecker();
      }
    });
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => const SupportDialog(),
      barrierDismissible: true,
    );
  }

  Future<void> _checkForUpdate() async {
    if (!mounted) return;
    await UpdateDialog.checkAndShow(context);
  }

  bool _isLargeScreen(BuildContext context) {
    // Only desktop platforms or genuine tablets (shortestSide >= 600)
    // Mobile phones in landscape (shortestSide ~390-430dp) stay on responsive mobile layout
    final isDesktopPlatform =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (isDesktopPlatform) return true;
    final size = MediaQuery.of(context).size;
    return size.shortestSide >= 600;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLocalMode = authProvider.isLocalOnlyMode;
    final isTv = Provider.of<TvDetectionService>(context).isTvMode;

    if (isTv) {
      return TvMainScreen(isOfflineMode: widget.isOfflineMode);
    }

    if (_isLargeScreen(context)) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final content = Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  DesktopNavigationSidebar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                      setState(() => _currentIndex = index);
                      NavigationHelper.appNavigatorKey.currentState
                          ?.popUntil((route) => route.isFirst);
                    },
                    navigatorKey: NavigationHelper.appNavigatorKey,
                  ),
                  Expanded(
                    child: Navigator(
                      key: NavigationHelper.appNavigatorKey,
                      onGenerateRoute: (settings) {
                        return PageRouteBuilder(
                          pageBuilder: (ctx, anim, _) => LazyIndexedStack(
                            index: _currentIndex,
                            children: _screens,
                          ),
                          transitionsBuilder: (ctx, animation, _, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: NavigationHelper.isDesktopLyricsOpen,
                    builder: (context, isLyricsOpen, _) {
                      if (!isLyricsOpen) return const SizedBox.shrink();
                      return Selector<PlayerProvider, bool>(
                        selector: (_, p) =>
                            p.currentSong != null || p.isPlayingRadio,
                        builder: (context, hasCurrentSong, _) {
                          return hasCurrentSong
                              ? DesktopLyricsPanel(
                                  onClose: () => NavigationHelper
                                      .isDesktopLyricsOpen.value = false,
                                )
                              : const SizedBox.shrink();
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: NavigationHelper.isDesktopQueueOpen,
                    builder: (context, isQueueOpen, _) {
                      if (!isQueueOpen) return const SizedBox.shrink();
                      return Selector<PlayerProvider, bool>(
                        selector: (_, p) =>
                            p.currentSong != null || p.isPlayingRadio,
                        builder: (context, hasCurrentSong, _) {
                          return hasCurrentSong
                              ? RightSidebar(
                                  onClose: () => NavigationHelper
                                      .isDesktopQueueOpen.value = false,
                                )
                              : const SizedBox.shrink();
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            Selector<PlayerProvider, bool>(
              selector: (_, p) => p.currentSong != null || p.isPlayingRadio,
              builder: (context, hasCurrentSong, _) {
                return hasCurrentSong
                    ? SafeArea(
                        top: false,
                        child: DesktopPlayerBar(
                          navigatorKey: NavigationHelper.appNavigatorKey,
                        ),
                      )
                    : const SizedBox.shrink();
              },
            ),
          ],
        ),
      );

      return Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.space):
              const PlayPauseIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            PlayPauseIntent: _PlayPauseAction(context),
          },
          child: TvRemoteScope(
            child: Focus(
              autofocus: true,
              child: content,
            ),
          ),
        ),
      );
    }

    final bool liquidGlass = Provider.of<ThemeService>(context).liquidGlass;
    return Selector<PlayerProvider, bool>(
      selector: (_, p) => p.currentSong != null || p.isPlayingRadio,
      builder: (context, hasCurrentSong, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBackButton();
          },
          child: TvRemoteScope(
            child: Scaffold(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkBackground
                  : AppTheme.lightBackground,
              resizeToAvoidBottomInset: false,
              body: Column(
                children: [
                  if (widget.isOfflineMode || isLocalMode)
                    Container(
                      width: double.infinity,
                      color: isLocalMode ? Colors.indigo : Colors.orange,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          children: [
                            Icon(
                              isLocalMode
                                  ? CupertinoIcons.folder_fill
                                  : CupertinoIcons.wifi_slash,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isLocalMode
                                    ? AppLocalizations.of(
                                        context,
                                      )!
                                        .localFilesModeBanner
                                    : AppLocalizations.of(
                                        context,
                                      )!
                                        .offlineModeBanner,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isLocalMode)
                    Selector<LocalMusicService, (bool, double, String)>(
                      selector: (_, s) =>
                          (s.isScanning, s.scanProgress, s.scanStatus),
                      builder: (context, data, _) {
                        final (isScanning, progress, status) = data;
                        if (!isScanning) return const SizedBox.shrink();
                        return Container(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.85),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  status,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (progress > 0)
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  Expanded(
                    child: Navigator(
                      key: NavigationHelper.appNavigatorKey,
                      onGenerateRoute: (settings) {
                        return MaterialPageRoute(
                          builder: (_) => LazyIndexedStack(
                            index: _currentIndex,
                            children: _screens,
                          ),
                        );
                      },
                    ),
                  ),
                  if (MediaQuery.of(context).viewInsets.bottom == 0)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasCurrentSong) const MiniPlayer(),
                        liquidGlass
                            ? _buildGlassBottomNav(context)
                            : _buildBottomNav(context),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleBackButton() {
    final navigatorState = NavigationHelper.appNavigatorKey.currentState;
    if (navigatorState != null && navigatorState.canPop()) {
      navigatorState.pop();
      return;
    }

    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return;
    }

    SystemNavigator.pop();
  }

  Widget _buildGlassBottomNav(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final l10n = AppLocalizations.of(context)!;

    final items = [
      (
        icon: CupertinoIcons.music_house,
        activeIcon: CupertinoIcons.music_house_fill,
        label: l10n.home,
      ),
      (
        icon: CupertinoIcons.collections,
        activeIcon: CupertinoIcons.collections_solid,
        label: l10n.library,
      ),
      (
        icon: CupertinoIcons.search,
        activeIcon: CupertinoIcons.search,
        label: l10n.search,
      ),
    ];

    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isPureOled = isDark && themeService.pureOled;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 4, 12, safeBottom > 0 ? safeBottom : 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: isDark
                    ? (isPureOled
                        ? const Color(0xB3000000)
                        : const Color(0xB30A0A0C))
                    : const Color(0xB3FFFFFF),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isDark
                      ? const Color(0x14FFFFFF)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
              children: List.generate(items.length, (idx) {
                final item = items[idx];
                final isSelected = _currentIndex == idx;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticsService.selection();
                      final navigatorState =
                          NavigationHelper.appNavigatorKey.currentState;
                      navigatorState?.popUntil((route) => route.isFirst);

                      if (idx == 2) {
                        final now = DateTime.now();
                        if (now.difference(_lastSearchTap).inSeconds > 3) {
                          _searchTapCount = 0;
                        }
                        _searchTapCount++;
                        _lastSearchTap = now;
                        if (_searchTapCount >= 11) {
                          _searchTapCount = 0;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FantasyScreen(),
                            ),
                          );
                          return;
                        }
                      } else {
                        _searchTapCount = 0;
                      }

                      setState(() => _currentIndex = idx);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            isSelected ? item.activeIcon : item.icon,
                            key: ValueKey(isSelected),
                            color: isSelected
                                ? accent
                                : (isDark ? Colors.white54 : Colors.black38),
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected
                                ? accent
                                : (isDark ? Colors.white54 : Colors.black38),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildBottomNav(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF000000) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0x14FFFFFF) : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
          currentIndex: _currentIndex,
          onTap: (index) {
            final navigatorState =
                NavigationHelper.appNavigatorKey.currentState;
            navigatorState?.popUntil((route) => route.isFirst);

            if (index == 2) {
              final now = DateTime.now();
              if (now.difference(_lastSearchTap).inSeconds > 3) {
                _searchTapCount = 0;
              }
              _searchTapCount++;
              _lastSearchTap = now;
              if (_searchTapCount >= 11) {
                _searchTapCount = 0;
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FantasyScreen()),
                );
                return;
              }
            } else {
              _searchTapCount = 0;
            }

            setState(() => _currentIndex = index);
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.music_house),
              activeIcon: const Icon(CupertinoIcons.music_house_fill),
              label: l10n.home,
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.collections),
              activeIcon: const Icon(CupertinoIcons.collections_solid),
              label: l10n.library,
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.search),
              activeIcon: const Icon(CupertinoIcons.search),
              label: l10n.search,
            ),
          ],
        ),
      ),
    );
  }
}
