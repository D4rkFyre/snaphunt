// lib/services/launch_prefs.dart
import 'package:shared_preferences/shared_preferences.dart';

/// Small helper to track whether we've already shown the first-launch Game Info.
/// Version the key so you can re-show after big updates by bumping suffix.
class LaunchPrefs {
  LaunchPrefs._();

  static const _kSeenGameInfoKey = 'seenGameInfo_v1';

  static Future<bool> hasSeenGameInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSeenGameInfoKey) ?? false;
  }

  static Future<void> setSeenGameInfo([bool value = true]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenGameInfoKey, value);
  }

  /// Handy for debugging to force the onboarding on next launch.
  static Future<void> resetSeenGameInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSeenGameInfoKey);
  }
}
