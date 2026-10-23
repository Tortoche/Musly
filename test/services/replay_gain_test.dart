import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:musly/models/song.dart';
import 'package:musly/services/replay_gain_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReplayGainService', () {
    late ReplayGainService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = ReplayGainService();
      await service.initialize();
    });

    test('mode off returns multiplier 1.0', () async {
      await service.setMode(ReplayGainMode.off);
      final multiplier = service.calculateVolumeMultiplier(
        trackGain: -10.0,
        albumGain: -8.0,
      );
      expect(multiplier, 1.0);
    });

    test('mode track calculates correct volume multiplier with trackGain',
        () async {
      await service.setMode(ReplayGainMode.track);
      await service.setPreampGain(0.0);
      await service.setPreventClipping(false);

      // -6.0206 dB is approximately 0.5 multiplier (20 * log10(0.5) = -6.0206)
      final multiplier = service.calculateVolumeMultiplier(
        trackGain: -6.0206,
      );
      expect(multiplier, closeTo(0.5, 0.01));
    });

    test('mode album uses albumGain when available', () async {
      await service.setMode(ReplayGainMode.album);
      await service.setPreampGain(0.0);
      await service.setPreventClipping(false);

      // Album gain is -6 dB (approx 0.5), track gain is -12 dB (approx 0.25)
      final multiplier = service.calculateVolumeMultiplier(
        trackGain: -12.0,
        albumGain: -6.0206,
      );
      expect(multiplier, closeTo(0.5, 0.01));
    });

    test('fallback gain is used when song has no gain tags', () async {
      await service.setMode(ReplayGainMode.track);
      await service.setPreampGain(0.0);
      await service.setFallbackGain(-6.0206);
      await service.setPreventClipping(false);

      final multiplier = service.calculateVolumeMultiplier(
        trackGain: null,
        albumGain: null,
      );
      expect(multiplier, closeTo(0.5, 0.01));
    });

    test('prevent clipping reduces multiplier if peak would exceed 1.0',
        () async {
      await service.setMode(ReplayGainMode.track);
      await service.setPreampGain(3.0); // positive preamp would amplify
      await service.setPreventClipping(true);

      // Gain = 0 dB, preamp = +3 dB -> raw multiplier > 1.0.
      // But peak is 1.25 -> maxMultiplier = 1 / 1.25 = 0.8
      final multiplier = service.calculateVolumeMultiplier(
        trackGain: 0.0,
        trackPeak: 1.25,
      );
      expect(multiplier, closeTo(0.8, 0.01));
    });

    test('Song model with loudgain tags provides correct fields to service',
        () {
      final song = Song.fromJson({
        'id': 's1',
        'title': 'Track with loudgain',
        'replayGain': {
          'trackGain': '-7.50 dB',
          'trackPeak': '0.990000',
        },
      });

      expect(song.replayGainTrackGain, -7.5);
      expect(song.replayGainTrackPeak, 0.99);
    });
  });
}
