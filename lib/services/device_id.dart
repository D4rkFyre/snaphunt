// lib/services/device_id.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// App-wide device identity (persisted).
/// - First call will generate a stable UUIDv4 and store it in SharedPreferences.
/// - Subsequent calls return the same value.
class DeviceId {
  static const _kKey = 'snaphunt_device_id';
  static final _uuid = const Uuid();

  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kKey);
    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      await prefs.setString(_kKey, id);
    }
    _cached = id;
    return id;
  }

  /// For tests only (do not call in production code).
  static Future<void> _resetForTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
    _cached = null;
  }
}
