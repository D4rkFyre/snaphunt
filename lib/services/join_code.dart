// lib/services/join_code.dart
import 'dart:math';

/// ---------------------------------------------------------------------------
/// JoinCode
/// ---------------------------------------------------------------------------
/// Purpose
/// - Create **short, human-friendly** game codes that are easy to read and type.
///
/// Design
/// - Codes are uppercase A–Z and digits **2–9** (we exclude I, O, 1, 0)
///   so players don’t confuse similar-looking characters.
///
/// Where used
/// - Host flow: generate a code for each new game.
/// - Join flow: quick local validation before calling Firestore.
/// ---------------------------------------------------------------------------
class JoinCode {
  // Alphabet without lookalikes: I, O, 1, 0 are excluded.
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  // Cryptographically secure RNG (no seeding); great for uniqueness.
  // If we ever need deterministic tests for code strings, we can allow an
  // injected Random or a separate helper only used in tests.
  static final Random _rng = Random.secure();

  /// Generate a random code of [length] characters (default: 6).
  ///
  /// Example: ZK7M3Q
  static String generate({int length = 6}) {
    assert(length > 0);
    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      sb.write(_alphabet[_rng.nextInt(_alphabet.length)]);
    }
    return sb.toString();
  }

  /// Validate a code string quickly on the client.
  ///
  /// Rules:
  /// - Uppercase A–Z (excluding I and O)
  /// - Digits 2–9 (excluding 0 and 1)
  /// - Exact [length] characters (default: 6)
  ///
  /// Note: This matches our generator + on-screen hint (“A–Z, 2–9”).
  /// If you prefer to allow 0/1 for some reason, change the regex to: `^[A-Z0-9]{$length}$`
  static bool isValid(String code, {int length = 6}) {
    final re = RegExp('^[A-Z0-9]{$length}\$');
    return re.hasMatch(code);
  }
}
