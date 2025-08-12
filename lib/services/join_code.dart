// lib/services/join_code.dart
import 'dart:math';

/// Generates short, human-friendly join codes for SnapHunt.
/// Default: 6 characters, uppercase, excluding visually ambiguous chars.
class JoinCode {
  // Excludes: I, O, 1, 0
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final Random _rng = Random.secure();

  /// Generate a random code of [length] characters (default: 6).
  static String generate({int length = 6}) {
    assert(length > 0);
    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      sb.write(_alphabet[_rng.nextInt(_alphabet.length)]);
    }
    return sb.toString();
  }

  /// Simple validator for a code of an expected length.
  static bool isValid(String code, {int length = 6}) {
    final re = RegExp('^[A-Z0-9]{$length}\$');
    return re.hasMatch(code);
  }
}
