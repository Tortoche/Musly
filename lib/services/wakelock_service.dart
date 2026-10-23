import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Centralized manager for device wake lock to prevent sleep / screen timeout.
/// Multiple subsystems (e.g. lyrics view, offline downloads) can request
/// the wake lock with unique reason tags without clobbering each other.
class WakelockService {
  static final WakelockService _instance = WakelockService._internal();
  factory WakelockService() => _instance;
  WakelockService._internal();

  final Set<String> _activeReasons = <String>{};

  /// Optional platform handler override for unit / widget testing.
  @visibleForTesting
  Future<void> Function(bool enable)? customHandler;

  /// Returns true if at least one subsystem has requested a wake lock.
  bool get isLocked => _activeReasons.isNotEmpty;

  /// Returns an unmodifiable set of current active reason keys.
  Set<String> get activeReasons => Set.unmodifiable(_activeReasons);

  /// Requests the screen to stay on for [reason].
  Future<void> enable(String reason) async {
    final changed = _activeReasons.add(reason);
    if (changed) {
      await _update();
    }
  }

  /// Releases the screen stay-on request for [reason].
  Future<void> disable(String reason) async {
    final changed = _activeReasons.remove(reason);
    if (changed) {
      await _update();
    }
  }

  /// Releases all active wake lock requests.
  Future<void> clear() async {
    if (_activeReasons.isNotEmpty) {
      _activeReasons.clear();
      await _update();
    }
  }

  Future<void> _update() async {
    final shouldBeLocked = _activeReasons.isNotEmpty;
    if (customHandler != null) {
      try {
        await customHandler!(shouldBeLocked);
      } catch (e) {
        debugPrint('[WakelockService] Error in customHandler: $e');
      }
      return;
    }

    if (kIsWeb) return;

    try {
      if (shouldBeLocked) {
        await WakelockPlus.enable();
        debugPrint(
            '[WakelockService] Screen timeout paused (reasons: $_activeReasons)');
      } else {
        await WakelockPlus.disable();
        debugPrint('[WakelockService] Screen timeout resumed');
      }
    } catch (e) {
      debugPrint('[WakelockService] Error updating wake lock: $e');
    }
  }
}
