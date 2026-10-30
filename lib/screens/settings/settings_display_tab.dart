import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:musly/services/recommendation_service.dart';
import 'package:musly/services/player_ui_settings_service.dart';
import 'package:musly/services/theme_service.dart';
import 'package:musly/services/haptics_service.dart';
import 'package:musly/services/locale_service.dart';
import 'package:musly/providers/player_provider.dart';
import 'package:musly/theme/app_theme.dart';
import 'package:musly/l10n/app_localizations.dart';
import 'package:musly/services/subsonic_service.dart';
import 'package:musly/widgets/settings/settings_section_card.dart';
import 'package:musly/widgets/settings/settings_list_tile.dart';
import 'package:musly/widgets/settings/settings_switch_tile.dart';
import 'package:musly/widgets/settings/settings_icon_badge.dart';
import 'package:musly/utils/context_extensions.dart';
import 'package:musly/services/storage_service.dart';
import 'package:musly/widgets/common/album_artwork.dart';
import 'package:window_manager/window_manager.dart';

class SettingsDisplayTab extends StatefulWidget {
  const SettingsDisplayTab({super.key});

  @override
  State<SettingsDisplayTab> createState() => _SettingsDisplayTabState();
}

class _SettingsDisplayTabState extends State<SettingsDisplayTab> {
  final _playerUiSettings = PlayerUiSettingsService();
  bool _showVolumeSlider = true;
  bool _showStarRatings = false;
  bool _showMiniPlayerHeart = false;
  bool _showMiniPlayerRepeat = false;
  bool _showMiniPlayerShuffle = false;
  bool _showLiveLyricUnderArtwork = false;
  bool _liveSearch = true;
  bool _showFavoritePlaylistsOnHome = false;
  bool _lyricsBlurUnfocused = false;
  String _lyricsAlignment = 'left';
  bool _lyricsGlowEffect = true;
  bool _lyricsKeepScreenOn = true;
  bool _hideWindowTitlebar = false;
  String _artworkResolution = 'normal';
  double _albumArtCornerRadius = 8.0;
  String _artworkShape = 'circle';
  String _artworkShadow = 'soft';
  String _artworkShadowColor = 'black';

  ThemeMode _themeMode = ThemeMode.system;
  AccentColor _accentColor = AccentColor.red;
  bool _liquidGlass = false;
  bool _pureOled = false;
  bool _hapticsEnabled = true;
  HapticMode _hapticsMode = HapticMode.subtle;

  bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _playerUiSettings.initialize();

    if (!mounted) return;
    final themeService = Provider.of<ThemeService>(context, listen: false);

    setState(() {
      _showVolumeSlider = _playerUiSettings.getShowVolumeSlider();
      _showStarRatings = _playerUiSettings.getShowStarRatings();
      _showMiniPlayerHeart = _playerUiSettings.getShowMiniPlayerHeart();
      _showMiniPlayerRepeat = _playerUiSettings.getShowMiniPlayerRepeat();
      _showMiniPlayerShuffle = _playerUiSettings.getShowMiniPlayerShuffle();
      _showLiveLyricUnderArtwork =
          _playerUiSettings.getShowLiveLyricUnderArtwork();
      _liveSearch = _playerUiSettings.getLiveSearch();
      _showFavoritePlaylistsOnHome =
          _playerUiSettings.getShowFavoritePlaylistsOnHome();
      _lyricsBlurUnfocused = _playerUiSettings.getLyricsBlurUnfocused();
      _lyricsAlignment = _playerUiSettings.getLyricsAlignment();
      _lyricsGlowEffect = _playerUiSettings.getLyricsGlowEffect();
      _lyricsKeepScreenOn = _playerUiSettings.getLyricsKeepScreenOn();
      _artworkResolution = _playerUiSettings.getArtworkResolution();
      _albumArtCornerRadius = _playerUiSettings.getAlbumArtCornerRadius();
      _artworkShape = _playerUiSettings.getArtworkShape();
      _artworkShadow = _playerUiSettings.getArtworkShadow();
      _artworkShadowColor = _playerUiSettings.getArtworkShadowColor();
      _themeMode = themeService.themeMode;
      _accentColor = themeService.accentColor;
      _liquidGlass = themeService.liquidGlass;
      _pureOled = themeService.pureOled;
      _hapticsEnabled = HapticsService().isEnabled;
      _hapticsMode = HapticsService().mode;
    });

    if (_isDesktop) {
      final hide = await StorageService().getHideWindowTitlebar();
      if (mounted) setState(() => _hideWindowTitlebar = hide);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isYoutube =
        Provider.of<SubsonicService>(context, listen: false).isYoutube;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        SettingsSectionCard(
          title: AppLocalizations.of(context)!.appearanceSection.toUpperCase(),
          children: [_buildAppearanceEditor()],
        ),
        const SizedBox(height: 24),
        SettingsSectionCard(
          title: AppLocalizations.of(context)!.language.toUpperCase(),
          children: [
            _buildLanguageSelector(),
          ],
        ),
        const SizedBox(height: 24),
        SettingsSectionCard(
          title: AppLocalizations.of(context)!.playerInterface.toUpperCase(),
          children: [
            _buildVolumeSliderToggle(),
            if (!isYoutube) ...[
              const SettingsDivider(),
              _buildStarRatingsToggle(),
            ],
            const SettingsDivider(),
            _buildLiveLyricUnderArtworkToggle(),
            const SettingsDivider(),
            _buildMiniPlayerHeartToggle(),
            const SettingsDivider(),
            _buildMiniPlayerRepeatToggle(),
            const SettingsDivider(),
            _buildMiniPlayerShuffleToggle(),
            if (_isDesktop) ...[
              const SettingsDivider(),
              _buildDiscordRpcToggle(),
              const SettingsDivider(),
              _buildDiscordRpcStateStyleSelector(),
              const SettingsDivider(),
              _buildWindowTitlebarToggle(),
            ],
          ],
        ),
        if (_isDesktop) ...[
          const SizedBox(height: 24),
          _buildSpotverlaySection(),
        ] else ...[
          const SizedBox(height: 24),
          _buildHapticsSection(),
        ],
        const SizedBox(height: 24),
        SettingsSectionCard(
          title: AppLocalizations.of(context)!.homeSection.toUpperCase(),
          children: [
            _buildFavoritePlaylistsOnHomeToggle(),
          ],
        ),
        const SizedBox(height: 24),
        SettingsSectionCard(
          title: AppLocalizations.of(context)!.liveSearchSection.toUpperCase(),
          children: [
            _buildLiveSearchToggle(),
          ],
        ),
        const SizedBox(height: 24),
        SettingsSectionCard(
          title: 'STYLE DES POCHETTES & DESIGN',
          children: [
            _buildArtworkStyleEditor(),
            const SettingsDivider(),
            _buildArtworkResolutionSelector(),
          ],
        ),
        const SizedBox(height: 24),
        SettingsSectionCard(
          title:
              AppLocalizations.of(context)!.lyricsDisplaySection.toUpperCase(),
          children: [
            _buildLyricsBlurToggle(),
            const SettingsDivider(),
            _buildLyricsAlignmentSelector(),
            const SettingsDivider(),
            _buildLyricsGlowToggle(),
            const SettingsDivider(),
            _buildLyricsKeepScreenOnToggle(),
          ],
        ),
        const SizedBox(height: 24),
        SettingsSectionCard(
          title: AppLocalizations.of(
            context,
          )!
              .smartRecommendations
              .toUpperCase(),
          children: [
            _buildRecommendationsToggle(),
            const SettingsDivider(),
            _buildRecommendationsStats(),
            const SettingsDivider(),
            _buildClearRecommendationsButton(),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildAppearanceEditor() {
    final theme = Theme.of(context);
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDark = context.isDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEditorRow(
            icon: CupertinoIcons.moon_stars_fill,
            iconColor: const Color(0xFF5856D6),
            label: AppLocalizations.of(context)!.themeLabel,
            child: _ThemeModeSelector(
              value: _themeMode,
              isDark: isDark,
              onChanged: (mode) async {
                setState(() => _themeMode = mode);
                await themeService.setThemeMode(mode);
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildEditorRow(
            icon: Icons.palette_rounded,
            iconColor: const Color(0xFFFF9500),
            label: AppLocalizations.of(context)!.accentColorLabel,
            child: _AccentColorPicker(
              selected: _accentColor,
              onChanged: (color) async {
                setState(() => _accentColor = color);
                await themeService.setAccentColor(color);
              },
            ),
          ),
          if (!_isDesktop) ...[
            const SizedBox(height: 20),
            _buildEditorRow(
              icon: CupertinoIcons.sparkles,
              iconColor: const Color(0xFF64D2FF),
              label: AppLocalizations.of(context)!.circularDesignLabel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.circularDesignSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkSecondaryText
                          : AppTheme.lightSecondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Spacer(),
                      CupertinoSwitch(
                        value: _liquidGlass,
                        activeTrackColor: const Color(0xFF64D2FF),
                        onChanged: (value) async {
                          setState(() => _liquidGlass = value);
                          await themeService.setLiquidGlass(value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildEditorRow(
            icon: CupertinoIcons.circle_lefthalf_fill,
            iconColor: const Color(0xFF8E8E93),
            label: 'Pure OLED (#000000)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Noir absolu (#000000) et bordures fines pour les écrans OLED',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.oledSecondaryText
                        : AppTheme.lightSecondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Spacer(),
                    CupertinoSwitch(
                      value: _pureOled,
                      activeTrackColor: theme.colorScheme.primary,
                      onChanged: (value) async {
                        setState(() => _pureOled = value);
                        await themeService.setPureOled(value);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeSliderToggle() {
    return SettingsSwitchTile(
      gradientColors: const [Color(0xFF007AFF), Color(0xFF5AC8FA)],
      icon: CupertinoIcons.speaker_2,
      title: AppLocalizations.of(context)!.showVolumeSlider,
      subtitle: AppLocalizations.of(context)!.showVolumeSliderSubtitle,
      value: _showVolumeSlider,
      onChanged: (value) async {
        setState(() => _showVolumeSlider = value);
        await _playerUiSettings.setShowVolumeSlider(value);
      },
    );
  }

  Widget _buildStarRatingsToggle() {
    return SettingsSwitchTile(
      gradientColors: const [Color(0xFFFFD700), Color(0xFFFFA500)],
      icon: CupertinoIcons.star_fill,
      title: AppLocalizations.of(context)!.showStarRatings,
      subtitle: AppLocalizations.of(context)!.showStarRatingsSubtitle,
      value: _showStarRatings,
      onChanged: (value) async {
        setState(() => _showStarRatings = value);
        await _playerUiSettings.setShowStarRatings(value);
      },
    );
  }

  Widget _buildMiniPlayerHeartToggle() {
    return SettingsSwitchTile(
      gradientColors: const [Color(0xFFFF2D55), Color(0xFFFF6B6B)],
      icon: CupertinoIcons.heart_fill,
      title: AppLocalizations.of(context)!.showMiniPlayerHeart,
      subtitle: AppLocalizations.of(context)!.showMiniPlayerHeartSubtitle,
      value: _showMiniPlayerHeart,
      onChanged: (value) async {
        setState(() => _showMiniPlayerHeart = value);
        await _playerUiSettings.setShowMiniPlayerHeart(value);
      },
    );
  }

  Widget _buildMiniPlayerRepeatToggle() {
    return SettingsSwitchTile(
      gradientColors: const [Color(0xFF34C759), Color(0xFF30D158)],
      icon: CupertinoIcons.repeat,
      title: AppLocalizations.of(context)!.showMiniPlayerRepeat,
      subtitle: AppLocalizations.of(context)!.showMiniPlayerRepeatSubtitle,
      value: _showMiniPlayerRepeat,
      onChanged: (value) async {
        setState(() => _showMiniPlayerRepeat = value);
        await _playerUiSettings.setShowMiniPlayerRepeat(value);
      },
    );
  }

  Widget _buildMiniPlayerShuffleToggle() {
    return SettingsSwitchTile(
      gradientColors: const [Color(0xFF5856D6), Color(0xFF7B68EE)],
      icon: CupertinoIcons.shuffle,
      title: AppLocalizations.of(context)!.showMiniPlayerShuffle,
      subtitle: AppLocalizations.of(context)!.showMiniPlayerShuffleSubtitle,
      value: _showMiniPlayerShuffle,
      onChanged: (value) async {
        setState(() => _showMiniPlayerShuffle = value);
        await _playerUiSettings.setShowMiniPlayerShuffle(value);
      },
    );
  }

  Widget _buildLiveLyricUnderArtworkToggle() {
    final l10n = AppLocalizations.of(context)!;
    return SettingsSwitchTile(
      gradientColors: const [Color(0xFF5856D6), Color(0xFFAF52DE)],
      icon: CupertinoIcons.quote_bubble_fill,
      title: l10n.lyricsUnderArtwork,
      subtitle: l10n.lyricsUnderArtworkSubtitle,
      value: _showLiveLyricUnderArtwork,
      onChanged: (value) async {
        setState(() => _showLiveLyricUnderArtwork = value);
        await _playerUiSettings.setShowLiveLyricUnderArtwork(value);
      },
    );
  }

  Widget _buildLiveSearchToggle() {
    return SettingsSwitchTile(
      gradientColors: const [Color(0xFFFF9500), Color(0xFFFFCC00)],
      icon: CupertinoIcons.search,
      title: AppLocalizations.of(context)!.liveSearch,
      subtitle: AppLocalizations.of(context)!.liveSearchSubtitle,
      value: _liveSearch,
      onChanged: (value) async {
        setState(() => _liveSearch = value);
        await _playerUiSettings.setLiveSearch(value);
      },
    );
  }

  Widget _buildFavoritePlaylistsOnHomeToggle() {
    return SettingsSwitchTile(
      gradientColors: const [Color(0xFFFA243C), Color(0xFFFF2D55)],
      icon: CupertinoIcons.heart_fill,
      title: AppLocalizations.of(context)!.showFavoritePlaylistsOnHome,
      subtitle:
          AppLocalizations.of(context)!.showFavoritePlaylistsOnHomeSubtitle,
      value: _showFavoritePlaylistsOnHome,
      onChanged: (value) async {
        setState(() => _showFavoritePlaylistsOnHome = value);
        await _playerUiSettings.setShowFavoritePlaylistsOnHome(value);
      },
    );
  }

  Widget _buildEditorRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Widget child,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) ...[const Spacer(), trailing],
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildRecommendationsToggle() {
    return Consumer<RecommendationService>(
      builder: (context, service, _) {
        return SettingsSwitchTile(
          gradientColors: const [Color(0xFFFF2D55), Color(0xFFFF6B6B)],
          icon: CupertinoIcons.sparkles,
          title: AppLocalizations.of(context)!.enableRecommendations,
          subtitle: AppLocalizations.of(context)!.enableRecommendationsSubtitle,
          value: service.enabled,
          onChanged: (value) => service.setEnabled(value),
        );
      },
    );
  }

  Widget _buildRecommendationsStats() {
    return Consumer<RecommendationService>(
      builder: (context, service, _) {
        final stats = service.getListeningStats();
        final uniqueSongs = stats['uniqueSongs'] ?? 0;
        final totalPlays = stats['totalPlays'] ?? 0;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          title: Text(
            AppLocalizations.of(context)!.listeningData,
            style: const TextStyle(fontSize: 16),
          ),
          subtitle: Text(
            AppLocalizations.of(context)!.totalPlays(totalPlays),
            style: TextStyle(
              fontSize: 13,
              color: context.isDark
                  ? AppTheme.darkSecondaryText
                  : AppTheme.lightSecondaryText,
            ),
          ),
          trailing: Text(
            AppLocalizations.of(context)!.songsCount(uniqueSongs),
            style: TextStyle(
              fontSize: 14,
              color: context.isDark
                  ? AppTheme.darkSecondaryText
                  : AppTheme.lightSecondaryText,
            ),
          ),
        );
      },
    );
  }

  Widget _buildClearRecommendationsButton() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        AppLocalizations.of(context)!.clearListeningHistory,
        style: const TextStyle(fontSize: 16, color: Color(0xFFFF3B30)),
      ),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.clearListeningHistory),
            content: Text(AppLocalizations.of(context)!.confirmClearHistory),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Provider.of<RecommendationService>(
                    context,
                    listen: false,
                  ).clearData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.historyCleared,
                      ),
                    ),
                  );
                },
                child: Text(
                  AppLocalizations.of(context)!.delete,
                  style: const TextStyle(color: Color(0xFFFF3B30)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiscordRpcToggle() {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF5865F2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              CupertinoIcons.game_controller,
              color: Colors.white,
              size: 18,
            ),
          ),
          title: Text(
            AppLocalizations.of(context)!.discordStatus,
            style: const TextStyle(fontSize: 16),
          ),
          subtitle: Text(
            AppLocalizations.of(context)!.discordStatusSubtitle,
            style: TextStyle(
              fontSize: 13,
              color: context.isDark
                  ? AppTheme.darkSecondaryText
                  : AppTheme.lightSecondaryText,
            ),
          ),
          trailing: CupertinoSwitch(
            value: player.discordRpcEnabled,
            activeTrackColor: Theme.of(context).colorScheme.primary,
            onChanged: (value) async {
              await player.setDiscordRpcEnabled(value);

              setState(() {});
            },
          ),
        );
      },
    );
  }

  Widget _buildDiscordRpcStateStyleSelector() {
    final l10n = AppLocalizations.of(context)!;
    final styles = [
      ('artist', l10n.discordRpcStyleArtist),
      ('song_title', l10n.discordRpcStyleSong),
      ('app_name', l10n.discordRpcStyleApp),
    ];
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF5865F2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              CupertinoIcons.text_bubble,
              color: Colors.white,
              size: 18,
            ),
          ),
          title: Text(l10n.discordStatusText,
              style: const TextStyle(fontSize: 16)),
          subtitle: Text(
            l10n.discordStatusTextSubtitle,
            style: TextStyle(
              fontSize: 13,
              color: context.isDark
                  ? AppTheme.darkSecondaryText
                  : AppTheme.lightSecondaryText,
            ),
          ),
          trailing: DropdownButton<String>(
            value: player.discordRpcStateStyle,
            underline: const SizedBox.shrink(),
            items: styles
                .map(
                  (s) => DropdownMenuItem(
                    value: s.$1,
                    child: Text(s.$2, style: const TextStyle(fontSize: 14)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) player.setDiscordRpcStateStyle(value);
            },
          ),
        );
      },
    );
  }

  Widget _buildLanguageSelector() {
    return Consumer<LocaleService>(
      builder: (context, localeService, _) {
        final currentLocale = localeService.currentLocale;
        final String currentLanguageName;

        if (currentLocale == null) {
          final resolvedLocale = Localizations.localeOf(context);
          final systemName =
              LocaleService.supportedLanguages[resolvedLocale.languageCode] ??
                  resolvedLocale.languageCode.toUpperCase();
          final defaultLabel =
              AppLocalizations.of(context)?.systemDefault ?? 'System Default';
          currentLanguageName = '$defaultLabel ($systemName)';
        } else {
          final currentLanguageCode = currentLocale.languageCode;
          currentLanguageName =
              LocaleService.supportedLanguages[currentLanguageCode] ??
                  currentLanguageCode.toUpperCase();
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: SettingsIconBadge(
            gradientColors: const [Color(0xFF34C759), Color(0xFF30D158)],
            icon: CupertinoIcons.globe,
          ),
          title: Text(
            AppLocalizations.of(context)!.language,
            style: const TextStyle(fontSize: 16),
          ),
          subtitle: Text(
            currentLanguageName,
            style: TextStyle(
              fontSize: 13,
              color: context.isDark
                  ? AppTheme.darkSecondaryText
                  : AppTheme.lightSecondaryText,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => _showLanguagePicker(context, localeService),
        );
      },
    );
  }



  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showLanguagePicker(BuildContext context, LocaleService localeService) {
    final resolvedLocale = Localizations.localeOf(context);
    final systemLangName =
        LocaleService.supportedLanguages[resolvedLocale.languageCode] ??
            resolvedLocale.languageCode.toUpperCase();
    final systemPercentage =
        LocaleService.getCompletionPercentage(resolvedLocale.languageCode);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: context.isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.isDark ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.globe, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.selectLanguage,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(context)
                                  ?.communityTranslationsSubtitle ??
                              'Translations are provided by the community on Crowdin',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.isDark
                                ? AppTheme.darkSecondaryText
                                : AppTheme.lightSecondaryText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(CupertinoIcons.device_phone_portrait),
              title: Text(AppLocalizations.of(context)!.systemDefault),
              subtitle: Text(
                '$systemLangName • $systemPercentage%',
                style: TextStyle(
                  fontSize: 12,
                  color: context.isDark
                      ? AppTheme.darkSecondaryText
                      : AppTheme.lightSecondaryText,
                ),
              ),
              trailing: localeService.currentLocale == null
                  ? Icon(Icons.check,
                      color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                localeService.setLocale(null);
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: LocaleService.supportedLanguages.entries.map((entry) {
                  final isSelected =
                      localeService.currentLocale?.languageCode == entry.key;
                  final percentage =
                      LocaleService.getCompletionPercentage(entry.key);
                  return ListTile(
                    leading: Text(
                      _getFlagEmoji(entry.key),
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(entry.value),
                    subtitle: Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: percentage >= 80
                            ? const Color(0xFF34C759)
                            : (percentage >= 40
                                ? const Color(0xFFFF9500)
                                : (context.isDark
                                    ? AppTheme.darkSecondaryText
                                    : AppTheme.lightSecondaryText)),
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      localeService.setLocale(Locale(entry.key));
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFlagEmoji(String languageCode) {
    return LocaleService.getFlagEmoji(languageCode);
  }

  Widget _buildLyricsBlurToggle() {
    final l10n = AppLocalizations.of(context)!;
    return SwitchListTile.adaptive(
      title: Text(l10n.lyricsBlurUnfocused),
      subtitle: Text(l10n.lyricsBlurUnfocusedSubtitle),
      value: _lyricsBlurUnfocused,
      onChanged: (val) async {
        await _playerUiSettings.setLyricsBlurUnfocused(val);
        setState(() => _lyricsBlurUnfocused = val);
      },
    );
  }

  
  double _artworkPreviewRadius() {
    const previewSize = 108.0;
    const referenceSize = 50.0;
    if (_artworkShape == 'circle') return 9999.0;
    if (_artworkShape == 'square') return 0.0;
    return (_albumArtCornerRadius * previewSize / referenceSize)
        .clamp(0.0, previewSize / 2);
  }

  List<BoxShadow>? _artworkPreviewShadow() {
    if (_artworkShadow == 'none') return null;
    const previewSize = 108.0;
    final Color color = _artworkShadowColor == 'accent'
        ? Theme.of(context).colorScheme.primary
        : Colors.black;
    double opacity;
    double blur;
    Offset offset;
    switch (_artworkShadow) {
      case 'medium':
        opacity = context.isDark ? 0.35 : 0.25;
        blur = previewSize / 6;
        offset = Offset(0, previewSize / 20);
        break;
      case 'strong':
        opacity = context.isDark ? 0.55 : 0.40;
        blur = previewSize / 4;
        offset = Offset(0, previewSize / 12);
        break;
      default:
        opacity = context.isDark ? 0.22 : 0.14;
        blur = previewSize / 10;
        offset = Offset(0, previewSize / 30);
    }
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: blur,
        offset: offset,
      ),
    ];
  }

  Widget _buildChips({
    required List<({String value, String label})> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt.value == selected;
        return GestureDetector(
          onTap: () => onSelected(opt.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : (context.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
              ),
            ),
            child: Text(
              opt.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (context.isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildArtworkStyleEditor() {
    const previewSize = 108.0;
    final radius = _artworkPreviewRadius();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  'Aperçu en direct',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.isDark
                        ? AppTheme.darkSecondaryText
                        : AppTheme.lightSecondaryText,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 14),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: previewSize,
                  height: previewSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withAlpha(180),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                      radius.clamp(0.0, previewSize / 2),
                    ),
                    boxShadow: _artworkPreviewShadow(),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildEditorRow(
            icon: Icons.crop_square_rounded,
            iconColor: const Color(0xFF5856D6),
            label: 'Forme des pochettes',
            child: _buildChips(
              options: [
                (value: 'circle', label: 'Cercle (par défaut)'),
                (value: 'rounded', label: 'Arrondi'),
                (value: 'square', label: 'Carré'),
              ],
              selected: _artworkShape,
              onSelected: (v) {
                setState(() => _artworkShape = v);
                _playerUiSettings.setArtworkShape(v);
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: _artworkShape == 'rounded'
                ? Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildEditorRow(
                        icon: Icons.rounded_corner,
                        iconColor: const Color(0xFFFF9500),
                        label: 'Rayon des coins',
                        trailing: Text(
                          _albumArtCornerRadius.round() == 0
                              ? 'Aucun'
                              : '${_albumArtCornerRadius.round()}px',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor:
                                Theme.of(context).colorScheme.primary,
                            inactiveTrackColor: context.isDark
                                ? AppTheme.darkDivider
                                : AppTheme.lightDivider,
                            thumbColor: Theme.of(context).colorScheme.primary,
                            overlayColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                          ),
                          child: Slider(
                            value: _albumArtCornerRadius,
                            min: 0,
                            max: 24,
                            divisions: 24,
                            onChanged: (v) {
                              setState(() => _albumArtCornerRadius = v);
                              _playerUiSettings.setAlbumArtCornerRadius(v);
                            },
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          _buildEditorRow(
            icon: Icons.blur_on_rounded,
            iconColor: const Color(0xFF34AADC),
            label: 'Ombre des pochettes',
            child: _buildChips(
              options: [
                (value: 'none', label: 'Aucune'),
                (value: 'soft', label: 'Légère'),
                (value: 'medium', label: 'Moyenne'),
                (value: 'strong', label: 'Prononcée'),
              ],
              selected: _artworkShadow,
              onSelected: (v) {
                setState(() => _artworkShadow = v);
                _playerUiSettings.setArtworkShadow(v);
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: _artworkShadow != 'none'
                ? Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildEditorRow(
                        icon: Icons.palette_outlined,
                        iconColor: const Color(0xFFFF2D55),
                        label: "Couleur de l'ombre",
                        child: _buildChips(
                          options: [
                            (value: 'black', label: 'Noire'),
                            (value: 'accent', label: "Teinte d'accentuation"),
                          ],
                          selected: _artworkShadowColor,
                          onSelected: (v) {
                            setState(() => _artworkShadowColor = v);
                            _playerUiSettings.setArtworkShadowColor(v);
                          },
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkResolutionSelector() {
    final options = {
      'low': 'Basse (300px)',
      'normal': 'Normale (600px)',
      'high': 'Haute (Originale)',
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: const Text('Résolution des pochettes'),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _artworkResolution,
          items: options.entries.map((e) {
            return DropdownMenuItem(
              value: e.key,
              child: Text(e.value),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _artworkResolution = val);
              _playerUiSettings.setArtworkResolution(val);
              ImageUrlCache.clear();
            }
          },
        ),
      ),
    );
  }

  Widget _buildLyricsAlignmentSelector() {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      title: Text(l10n.lyricsAlignment),
      subtitle: Text(_lyricsAlignment == 'center'
          ? l10n.lyricsAlignmentCentered
          : l10n.lyricsAlignmentLeft),
      trailing: SegmentedButton<String>(
        segments: [
          ButtonSegment(
              value: 'left',
              label: Text(l10n.alignLeft),
              icon: const Icon(Icons.format_align_left, size: 16)),
          ButtonSegment(
              value: 'center',
              label: Text(l10n.alignCenter),
              icon: const Icon(Icons.format_align_center, size: 16)),
        ],
        selected: {_lyricsAlignment},
        onSelectionChanged: (val) async {
          final chosen = val.first;
          await _playerUiSettings.setLyricsAlignment(chosen);
          setState(() => _lyricsAlignment = chosen);
        },
      ),
    );
  }

  Widget _buildLyricsGlowToggle() {
    final l10n = AppLocalizations.of(context)!;
    return SwitchListTile.adaptive(
      title: Text(l10n.lyricsGlowEffect),
      subtitle: Text(l10n.lyricsGlowEffectSubtitle),
      value: _lyricsGlowEffect,
      onChanged: (val) async {
        await _playerUiSettings.setLyricsGlowEffect(val);
        setState(() => _lyricsGlowEffect = val);
      },
    );
  }

  Widget _buildLyricsKeepScreenOnToggle() {
    final l10n = AppLocalizations.of(context)!;
    return SwitchListTile.adaptive(
      title: Text(l10n.lyricsKeepScreenOn),
      subtitle: Text(l10n.lyricsKeepScreenOnSubtitle),
      value: _lyricsKeepScreenOn,
      onChanged: (val) async {
        await _playerUiSettings.setLyricsKeepScreenOn(val);
        setState(() => _lyricsKeepScreenOn = val);
      },
    );
  }

  Widget _buildWindowTitlebarToggle() {
    final l10n = AppLocalizations.of(context)!;
    return SwitchListTile.adaptive(
      title: Text(l10n.hideWindowTitlebar),
      subtitle: Text(l10n.hideWindowTitlebarSubtitle),
      value: _hideWindowTitlebar,
      onChanged: (val) async {
        await StorageService().saveHideWindowTitlebar(val);
        setState(() => _hideWindowTitlebar = val);
        if (_isDesktop) {
          try {
            await windowManager.setTitleBarStyle(
                val ? TitleBarStyle.hidden : TitleBarStyle.normal);
          } catch (_) {}
        }
      },
    );
  }

  Widget _buildSpotverlaySection() {
    final l10n = AppLocalizations.of(context)!;
    return SettingsSectionCard(
      title: l10n.desktopOverlaySection.toUpperCase(),
      children: [
        SettingsListTile(
          gradientColors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          icon: CupertinoIcons.layers_alt_fill,
          title: l10n.spotverlayTitle,
          subtitle: l10n.spotverlayDescription,
          trailing: Icon(
            Icons.open_in_new_rounded,
            size: 18,
            color: context.isDark
                ? AppTheme.darkSecondaryText
                : AppTheme.lightSecondaryText,
          ),
          onTap: () async {
            final uri = Uri.parse('https://github.com/dddevid/Spotverlay');
            try {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            } catch (e) {
              debugPrint('Error launching Spotverlay URL: $e');
            }
          },
        ),
      ],
    );
  }

  Widget _buildHapticsSection() {
    return SettingsSectionCard(
      title: 'RETOURS HAPTIQUES & VIBRATIONS',
      children: [
        SettingsSwitchTile(
          title: 'Vibrations tactiles',
          subtitle:
              'Micro-vibrations calibrées pour les boutons, onglets et contrôles',
          icon: CupertinoIcons.waveform,
          gradientColors: const [Color(0xFFEC4899), Color(0xFFF43F5E)],
          value: _hapticsEnabled,
          onChanged: (val) async {
            await HapticsService().setEnabled(val);
            if (mounted) setState(() => _hapticsEnabled = val);
          },
        ),
        if (_hapticsEnabled) ...[
          const SettingsDivider(),
          SettingsListTile(
            title: 'Intensité du retour',
            subtitle: _hapticsMode == HapticMode.subtle
                ? 'Subtil (Style Apple Taptic)'
                : 'Standard (Vibrations classiques)',
            icon: CupertinoIcons.slider_horizontal_3,
            gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6366F1)],
            onTap: _showHapticsModeDialog,
          ),
          const SettingsDivider(),
          SettingsListTile(
            title: 'Tester le retour haptique',
            subtitle: 'Ressentir la vibration calibrée maintenant',
            icon: CupertinoIcons.hand_draw,
            gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
            onTap: () {
              HapticsService.light();
            },
          ),
        ],
      ],
    );
  }

  void _showHapticsModeDialog() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Intensité des retours haptiques'),
        message: const Text('Choisissez le calibrage des vibrations'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            isDefaultAction: _hapticsMode == HapticMode.subtle,
            onPressed: () async {
              Navigator.pop(context);
              await HapticsService().setMode(HapticMode.subtle);
              if (mounted) setState(() => _hapticsMode = HapticMode.subtle);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_hapticsMode == HapticMode.subtle)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(CupertinoIcons.checkmark_alt, size: 18),
                  ),
                const Text('Subtil (Style Apple Taptic)'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _hapticsMode == HapticMode.medium,
            onPressed: () async {
              Navigator.pop(context);
              await HapticsService().setMode(HapticMode.medium);
              if (mounted) setState(() => _hapticsMode = HapticMode.medium);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_hapticsMode == HapticMode.medium)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(CupertinoIcons.checkmark_alt, size: 18),
                  ),
                const Text('Standard'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  final ThemeMode value;
  final bool isDark;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        mode: ThemeMode.system,
        label: AppLocalizations.of(context)!.themeModeSystem,
        icon: CupertinoIcons.device_phone_portrait
      ),
      (
        mode: ThemeMode.light,
        label: AppLocalizations.of(context)!.themeModeLight,
        icon: CupertinoIcons.sun_max_fill
      ),
      (
        mode: ThemeMode.dark,
        label: AppLocalizations.of(context)!.themeModeDark,
        icon: CupertinoIcons.moon_fill
      ),
    ];

    final accent = Theme.of(context).colorScheme.primary;

    return Row(
      children: options.map((opt) {
        final selected = value == opt.mode;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(opt.mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? accent
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    opt.icon,
                    size: 18,
                    color: selected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AccentColorPicker extends StatelessWidget {
  const _AccentColorPicker({
    required this.selected,
    required this.onChanged,
  });

  final AccentColor selected;
  final ValueChanged<AccentColor> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AccentColor.values.map((color) {
        final isSelected = selected == color;
        final isDynamic = color.isDynamic;

        final decoration = isDynamic
            ? BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFF6750A4),
                    Color(0xFF006C50),
                    Color(0xFF7D5260),
                    Color(0xFF00639B),
                    Color(0xFF6750A4),
                  ],
                ),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              )
            : BoxDecoration(
                color: color.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.color.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              );

        final l10n = AppLocalizations.of(context);
        return Tooltip(
          message: isDynamic
              ? (l10n?.dynamicColor ?? 'Material You (Dynamic Color)')
              : '',
          child: GestureDetector(
            onTap: () => onChanged(color),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 32,
              height: 32,
              decoration: decoration,
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : (isDynamic
                      ? const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 14)
                      : null),
            ),
          ),
        );
      }).toList(),
    );
  }
}
