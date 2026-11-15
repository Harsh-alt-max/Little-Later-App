import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Haptics that work on every Android phone. Flutter's built-in haptics follow
/// the phone's "touch feedback" system setting, which many phones switch off,
/// so we drive the vibration motor directly.
class Haptics {
  static bool enabled = true;
  static bool? _amp;

  static Future<void> _buzz(int ms, int amplitude) async {
    if (!enabled) return;
    try {
      _amp ??= await Vibration.hasAmplitudeControl();
      await Vibration.vibrate(duration: ms, amplitude: _amp == true ? amplitude : -1);
    } catch (_) {
      HapticFeedback.lightImpact();
    }
  }

  /// Selection tick (tabs, chips).
  static void tick() => _buzz(8, 40);

  /// Light tap (buttons).
  static void light() => _buzz(14, 80);

  /// Firm tap (done, save).
  static void medium() => _buzz(22, 150);

  /// Celebration (level up, unlock).
  static void heavy() => _buzz(40, 255);
}
