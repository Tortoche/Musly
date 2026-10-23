import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/services/theme_service.dart';
import 'package:musly/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccentColor Tests', () {
    test('AccentColor enum includes dynamicColor and handles serialization',
        () {
      expect(AccentColor.dynamicColor.persistKey, 'dynamic');
      expect(AccentColor.dynamicColor.isDynamic, isTrue);
      expect(AccentColor.red.isDynamic, isFalse);

      expect(AccentColorExt.fromKey('dynamic'), AccentColor.dynamicColor);
      expect(AccentColorExt.fromKey('red'), AccentColor.red);
      expect(AccentColorExt.fromKey('pink'), AccentColor.pink);
      expect(AccentColorExt.fromKey('orange'), AccentColor.orange);
      expect(AccentColorExt.fromKey('yellow'), AccentColor.yellow);
      expect(AccentColorExt.fromKey('green'), AccentColor.green);
      expect(AccentColorExt.fromKey('blue'), AccentColor.blue);
      expect(AccentColorExt.fromKey('purple'), AccentColor.purple);
      expect(AccentColorExt.fromKey('unknown'), AccentColor.red);
    });

    test('ThemeService initializes and persists dynamicColor', () async {
      SharedPreferences.setMockInitialValues({
        'app_accent_color': 'dynamic',
      });
      final themeService = ThemeService();
      await themeService.initialize();

      expect(themeService.accentColor, AccentColor.dynamicColor);

      await themeService.setAccentColor(AccentColor.blue);
      expect(themeService.accentColor, AccentColor.blue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_accent_color'), 'blue');

      await themeService.setAccentColor(AccentColor.dynamicColor);
      expect(themeService.accentColor, AccentColor.dynamicColor);
      expect(prefs.getString('app_accent_color'), 'dynamic');
    });

    test('ThemeService initializes pureOled as true by default and persists',
        () async {
      SharedPreferences.setMockInitialValues({});
      final themeService = ThemeService();
      await themeService.initialize();

      expect(themeService.pureOled, isTrue);

      await themeService.setPureOled(false);
      expect(themeService.pureOled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('app_pure_oled'), isFalse);

      await themeService.setPureOled(true);
      expect(themeService.pureOled, isTrue);
      expect(prefs.getBool('app_pure_oled'), isTrue);
    });
  });

  group('AppTheme OLED Tests', () {
    test('AppTheme OLED constants are properly defined', () {
      expect(AppTheme.oledBackground.toARGB32(), 0xFF000000);
      expect(AppTheme.oledSurface.toARGB32(), 0xFF09090B);
      expect(AppTheme.oledCard.toARGB32(), 0xFF0C0C0E);
      expect(AppTheme.oledCardHover.toARGB32(), 0xFF141417);
      expect(AppTheme.oledDivider.toARGB32(), 0x14FFFFFF);
      expect(AppTheme.oledBorder.toARGB32(), 0x1AFFFFFF);
      expect(AppTheme.oledSecondaryText.toARGB32(), 0xFF8E8E93);
      expect(AppTheme.oledTertiaryText.toARGB32(), 0xFF636366);
    });

    test(
        'AppTheme.oledThemeWith builds theme with pure black scaffold and OLED tokens',
        () {
      final theme = AppTheme.oledThemeWith(const Color(0xFFFA243C));
      expect(theme.scaffoldBackgroundColor, AppTheme.oledBackground);
      expect(theme.brightness, Brightness.dark);
      expect(theme.cardTheme.color, AppTheme.oledCard);
      expect(theme.bottomNavigationBarTheme.backgroundColor,
          AppTheme.oledBackground);
      expect(theme.dividerTheme.color, AppTheme.oledDivider);
      expect(theme.bottomSheetTheme.backgroundColor, AppTheme.oledSurface);
      expect(theme.dialogTheme.backgroundColor, AppTheme.oledCard);
      expect(theme.popupMenuTheme.color, AppTheme.oledCard);
    });
  });
}
