import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HapticMode {
  subtle, // Apple Taptic style: light ticks & crisp micro-haptics
  medium, // Standard crisp haptics
  off,    // Disabled
}

/// Centralized, calibrated haptic feedback service for Musly.
/// Calibrated to deliver Apple-grade tactile sensations on supported devices.
class HapticsService {
  static const String _keyEnabled = 'haptics_enabled';
  static const String _keyMode = 'haptics_mode';

  static final HapticsService _instance = HapticsService._internal();
  factory HapticsService() => _instance;
  HapticsService._internal();

  SharedPreferences? _prefs;
  bool _enabled = true;
  HapticMode _mode = HapticMode.subtle;

  bool get isEnabled => _enabled;
  HapticMode get mode => _mode;

  static bool get _canVibrate {
    final s = _instance;
    if (!s._enabled) return false;
    if (s._mode == HapticMode.off) return false;
    if (kIsWeb) return false;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return false;
    return true;
  }

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    _enabled = _prefs?.getBool(_keyEnabled) ?? true;
    final savedMode = _prefs?.getString(_keyMode);
    if (savedMode != null) {
      _mode = HapticMode.values.firstWhere(
        (e) => e.name == savedMode,
        orElse: () => HapticMode.subtle,
      );
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(_keyEnabled, enabled);
    if (enabled) {
      light();
    }
  }

  Future<void> setMode(HapticMode mode) async {
    _mode = mode;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_keyMode, mode.name);
    if (mode != HapticMode.off) {
      selection();
    }
  }

  /// Ultra-subtle selection tick (Apple style): bottom navigation tabs, switches, scrubbers, list items
  static void selection() {
    if (!_canVibrate) return;
    try {
      if (_instance._mode == HapticMode.subtle) {
        HapticFeedback.selectionClick();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  /// Light impact: quick access cards, dialog buttons, playlist cards, secondary controls
  static void light() {
    if (!_canVibrate) return;
    try {
      if (_instance._mode == HapticMode.subtle) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }

  /// Medium impact: play/pause, heart/favorite toggle, long press
  static void medium() {
    if (!_canVibrate) return;
    try {
      if (_instance._mode == HapticMode.subtle) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }

  /// Heavy impact: milestones, deletion confirm
  static void heavy() {
    if (!_canVibrate) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}
