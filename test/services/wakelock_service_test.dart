import 'package:flutter_test/flutter_test.dart';
import 'package:musly/services/wakelock_service.dart';
import 'package:musly/services/player_ui_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WakelockService', () {
    late WakelockService wakelockService;
    final List<bool> lockStateChanges = [];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      wakelockService = WakelockService();
      lockStateChanges.clear();
      wakelockService.customHandler = (bool enable) async {
        lockStateChanges.add(enable);
      };
      await wakelockService.clear();
      lockStateChanges.clear();
    });

    tearDown(() async {
      await wakelockService.clear();
      wakelockService.customHandler = null;
    });

    test('initial state has no active reasons and is not locked', () {
      expect(wakelockService.isLocked, isFalse);
      expect(wakelockService.activeReasons, isEmpty);
    });

    test('enabling a reason locks the screen', () async {
      await wakelockService.enable('lyrics_view');
      expect(wakelockService.isLocked, isTrue);
      expect(wakelockService.activeReasons, contains('lyrics_view'));
      expect(lockStateChanges, [true]);
    });

    test('disabling the reason unlocks the screen', () async {
      await wakelockService.enable('lyrics_view');
      await wakelockService.disable('lyrics_view');
      expect(wakelockService.isLocked, isFalse);
      expect(wakelockService.activeReasons, isEmpty);
      expect(lockStateChanges, [true, false]);
    });

    test('multiple reasons keep screen locked until all reasons are removed',
        () async {
      await wakelockService.enable('lyrics_view');
      await wakelockService.enable('offline_download');
      expect(wakelockService.isLocked, isTrue);
      expect(wakelockService.activeReasons.length, 2);

      // Disabling one reason should keep the screen locked
      await wakelockService.disable('lyrics_view');
      expect(wakelockService.isLocked, isTrue);
      expect(wakelockService.activeReasons, contains('offline_download'));

      // Disabling the remaining reason unlocks the screen
      await wakelockService.disable('offline_download');
      expect(wakelockService.isLocked, isFalse);
      expect(wakelockService.activeReasons, isEmpty);
      expect(lockStateChanges.last, isFalse);
    });

    test('clear removes all reasons and unlocks', () async {
      await wakelockService.enable('reason_a');
      await wakelockService.enable('reason_b');
      expect(wakelockService.isLocked, isTrue);

      await wakelockService.clear();
      expect(wakelockService.isLocked, isFalse);
      expect(wakelockService.activeReasons, isEmpty);
      expect(lockStateChanges.last, isFalse);
    });

    test('duplicate enable call is idempotent', () async {
      await wakelockService.enable('lyrics_view');
      final changesCount = lockStateChanges.length;
      await wakelockService.enable('lyrics_view');
      expect(lockStateChanges.length, changesCount);
      expect(wakelockService.activeReasons.length, 1);
    });

    test('disabling non-existent reason is a safe no-op', () async {
      await wakelockService.disable('non_existent');
      expect(wakelockService.isLocked, isFalse);
    });
  });

  group('PlayerUiSettingsService lyricsKeepScreenOn', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to true', () async {
      final settings = PlayerUiSettingsService();
      await settings.initialize();
      expect(settings.getLyricsKeepScreenOn(), isTrue);
      expect(settings.lyricsKeepScreenOnNotifier.value, isTrue);
    });

    test('persists toggle changes and updates notifier', () async {
      final settings = PlayerUiSettingsService();
      await settings.initialize();

      bool? notifiedValue;
      settings.lyricsKeepScreenOnNotifier.addListener(() {
        notifiedValue = settings.lyricsKeepScreenOnNotifier.value;
      });

      await settings.setLyricsKeepScreenOn(false);
      expect(settings.getLyricsKeepScreenOn(), isFalse);
      expect(notifiedValue, isFalse);

      await settings.setLyricsKeepScreenOn(true);
      expect(settings.getLyricsKeepScreenOn(), isTrue);
      expect(notifiedValue, isTrue);
    });
  });
}
