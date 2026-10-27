import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:musly/l10n/app_localizations.dart';
import 'package:musly/theme/app_theme.dart';
import 'package:musly/widgets/settings/settings_section_card.dart';
import 'package:musly/widgets/settings/settings_list_tile.dart';
import 'package:musly/utils/context_extensions.dart';
import 'package:flutter/services.dart';
import 'package:musly/services/update_service.dart';
import 'package:musly/widgets/dialogs/update_dialog.dart';

class SettingsAboutTab extends StatefulWidget {
  const SettingsAboutTab({super.key});

  @override
  State<SettingsAboutTab> createState() => _SettingsAboutTabState();
}

class _SettingsAboutTabState extends State<SettingsAboutTab> {
  int _versionTapCount = 0;
  bool _isCheckingUpdates = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        SettingsSectionCard(
          title: AppLocalizations.of(context)!.sectionAboutInformation,
          children: [
            _buildInfoTile(
              context,
              icon: CupertinoIcons.info,
              iconColor: Theme.of(context).colorScheme.primary,
              title: AppLocalizations.of(context)!.aboutVersion,
              subtitle: UpdateService.currentVersion,
              onTap: _onVersionTapped,
            ),
            _buildDivider(context),
            _buildInfoTile(
              context,
              icon: CupertinoIcons.device_phone_portrait,
              iconColor: const Color(0xFF007AFF),
              title: AppLocalizations.of(context)!.aboutPlatform,
              subtitle: Theme.of(context).platform.name.toUpperCase(),
            ),
            _buildDivider(context),
            _buildActionTile(
              context,
              icon: CupertinoIcons.arrow_2_circlepath,
              iconColor: const Color(0xFF34C759),
              title: AppLocalizations.of(context)!.checkForUpdates,
              subtitle: _isCheckingUpdates
                  ? AppLocalizations.of(context)!.checkingForUpdates
                  : null,
              trailing: _isCheckingUpdates
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _isCheckingUpdates ? null : _checkForUpdatesManual,
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Container(
        height: 0.5,
        color: context.isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return SettingsListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [iconColor, iconColor.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return SettingsListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [iconColor, iconColor.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      title: title,
      subtitle: subtitle,
      trailing: trailing ??
          (onTap != null
              ? Icon(
                  CupertinoIcons.chevron_forward,
                  size: 18,
                  color: context.isDark
                      ? AppTheme.darkSecondaryText
                      : AppTheme.lightSecondaryText,
                )
              : null),
      onTap: onTap,
    );
  }

  void _onVersionTapped() {
    _versionTapCount++;
    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Musly Developer options activated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _checkForUpdatesManual() async {
    if (_isCheckingUpdates) return;
    setState(() => _isCheckingUpdates = true);

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.checkingForUpdates),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final release = await UpdateService.checkForUpdate(force: true);
      if (!mounted) return;

      if (release != null) {
        await UpdateDialog.show(context, release);
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.appUpToDate),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdates = false);
      }
    }
  }
}
