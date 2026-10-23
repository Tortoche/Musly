import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

class CrossfadeService {
  static const String _keyCrossfadeSeconds = 'crossfade_seconds';
  static const String _keySmartDj = 'crossfade_smart_dj';

  static final CrossfadeService _instance = CrossfadeService._internal();
  factory CrossfadeService() => _instance;
  CrossfadeService._internal();

  SharedPreferences? _prefs;

  final ValueNotifier<int> crossfadeSecondsNotifier = ValueNotifier<int>(5);
  final ValueNotifier<bool> smartDjNotifier = ValueNotifier<bool>(true);

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    crossfadeSecondsNotifier.value = getCrossfadeSeconds();
    smartDjNotifier.value = isSmartDjEnabled;
  }

  int getCrossfadeSeconds() {
    return _prefs?.getInt(_keyCrossfadeSeconds) ?? 5;
  }

  bool get isSmartDjEnabled {
    return _prefs?.getBool(_keySmartDj) ?? true;
  }

  Future<void> setCrossfadeSeconds(int seconds) async {
    await initialize();
    final clamped = seconds.clamp(0, 12);
    await _prefs!.setInt(_keyCrossfadeSeconds, clamped);
    crossfadeSecondsNotifier.value = clamped;
  }

  Future<void> setSmartDjEnabled(bool enabled) async {
    await initialize();
    await _prefs!.setBool(_keySmartDj, enabled);
    smartDjNotifier.value = enabled;
  }

  bool get isEnabled =>
      crossfadeSecondsNotifier.value > 0 || smartDjNotifier.value;

  /// Calculates the optimal DJ transition duration in seconds based on genre, tempo, lyrics, and track characteristics
  int calculateTransitionSeconds({
    Song? currentSong,
    Song? nextSong,
    double? lastLyricSeconds,
    Duration? duration,
  }) {
    final userPref = getCrossfadeSeconds();
    if (!isSmartDjEnabled) {
      return userPref;
    }

    int recommended = userPref > 0 ? userPref : 5;

    // 1. If we have lyrics, check remaining outro duration after vocals finish
    if (lastLyricSeconds != null && duration != null && duration.inSeconds > 0) {
      final remainingAfterLyrics = duration.inSeconds - lastLyricSeconds;
      if (remainingAfterLyrics >= 8) {
        // Generous outro: allow a grand, smooth festival DJ transition
        recommended = 8;
      } else if (remainingAfterLyrics >= 5) {
        recommended = 6;
      } else if (remainingAfterLyrics >= 3) {
        recommended = 4;
      } else {
        // Vocals go almost to the end: punchy 3s transition to avoid overlapping voices
        recommended = 3;
      }
    } else if (currentSong != null) {
      // 2. Instrumental / No-Lyrics fallback: genre & duration phrasing
      final genre = (currentSong.genre ?? '').toLowerCase();
      final songDuration = currentSong.duration ?? 0;

      if (genre.contains('electro') ||
          genre.contains('house') ||
          genre.contains('techno') ||
          genre.contains('dance') ||
          genre.contains('edm') ||
          genre.contains('club') ||
          genre.contains('trance')) {
        // Electronic music thrives on 8-second 16-bar / 32-bar builds
        recommended = 8;
      } else if (genre.contains('hip') ||
          genre.contains('rap') ||
          genre.contains('trap') ||
          genre.contains('r&b') ||
          genre.contains('pop')) {
        recommended = 5;
      } else if (genre.contains('rock') ||
          genre.contains('metal') ||
          genre.contains('punk')) {
        recommended = 4;
      } else if (genre.contains('acoustic') ||
          genre.contains('classical') ||
          genre.contains('jazz') ||
          genre.contains('ambient') ||
          genre.contains('lofi') ||
          genre.contains('lo-fi') ||
          genre.contains('ballad')) {
        recommended = 5;
      }

      if (songDuration > 0 && songDuration < 130) {
        recommended = min(recommended, 3);
      } else if (songDuration > 300) {
        recommended = max(recommended, 6);
      }
    }

    return recommended.clamp(1, 12);
  }

  /// Calculates the exact timestamp to begin the transition
  Duration calculateTriggerThreshold({
    required Duration duration,
    required int crossfadeSec,
    double? lastLyricSeconds,
  }) {
    Duration threshold = duration - Duration(seconds: crossfadeSec);

    if (lastLyricSeconds != null && lastLyricSeconds > 0) {
      final vocalEndDuration = Duration(
        milliseconds: ((lastLyricSeconds + 1.2) * 1000).round(),
      );

      // Only allow vocal end trigger if it's near the end (within 10s of duration)
      // to avoid cutting off long musical outros
      final earliestAllowed = duration - Duration(seconds: crossfadeSec + 5);
      final latestAllowed = duration - const Duration(seconds: 2);

      if (vocalEndDuration >= earliestAllowed && vocalEndDuration <= latestAllowed) {
        if (vocalEndDuration < threshold) {
          threshold = vocalEndDuration;
        }
      }
    }

    return threshold;
  }

  /// Parses the timestamp in seconds of the final lyric line in synced LRC format
  static double? parseLastLyricTimestamp(String syncedLyrics) {
    try {
      final regExp = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
      final matches = regExp.allMatches(syncedLyrics).toList();
      if (matches.isEmpty) return null;

      final last = matches.last;
      final mins = int.tryParse(last.group(1) ?? '0') ?? 0;
      final secs = int.tryParse(last.group(2) ?? '0') ?? 0;
      final msStr = last.group(3) ?? '0';
      final ms = int.tryParse(msStr) ?? 0;
      final msVal = msStr.length == 3 ? ms / 1000.0 : ms / 100.0;

      return (mins * 60) + secs + msVal;
    } catch (_) {
      return null;
    }
  }

  /// DJ Power Drop: Keeps outgoing track at full power for the first 25%, then plunges dynamically
  static double djPowerDropFadeOut(double progress) {
    final p = progress.clamp(0.0, 1.0);
    if (p < 0.25) {
      return 1.0;
    }
    final plunge = (p - 0.25) / 0.75;
    return (1.0 - pow(plunge, 1.5)).clamp(0.0, 1.0).toDouble();
  }

  /// DJ Power Drop: Drops the incoming track with instant presence (~35% vol) and fast power surge
  static double djPowerDropFadeIn(double progress) {
    final p = progress.clamp(0.0, 1.0);
    if (p <= 0.0) return 0.0;
    return (0.35 + 0.65 * pow(p, 0.6)).clamp(0.0, 1.0).toDouble();
  }

  /// Equal-Power crossfade curve: cos(t * pi / 2) maintains perceived loudness (no 3dB volume drop)
  static double equalPowerFadeOut(double progress) {
    final p = progress.clamp(0.0, 1.0);
    return cos(p * (pi / 2.0));
  }

  static double equalPowerFadeIn(double progress) {
    final p = progress.clamp(0.0, 1.0);
    return sin(p * (pi / 2.0));
  }
}
