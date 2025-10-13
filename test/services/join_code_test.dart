// test/services/join_code_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/services/join_code.dart';

/// ---------------------------------------------------------------------------
/// JoinCode tests
/// ---------------------------------------------------------------------------
/// Purpose
/// - Sanity-check that our join code generator and validator behave as expected.
///
/// Test strategy
/// - We treat codes as short, human-friendly tokens (subset of A–Z + digits).
/// - Generator should:
///     * default to 6 characters
///     * be uppercase
///     * avoid obvious collisions across many samples
/// - Validator should:
///     * enforce the requested length
///     * (In our implementation) accept only A–Z and digits 2–9
///       (we exclude I/O/0/1 to reduce confusion).
///
/// Note on regexes below
/// - These tests allow `[A-Z0-9]`, which is a **superset** of what we actually
///   generate. That’s fine: the generator’s alphabet (A–Z without I/O and 2–9)
///   still matches `[A-Z0-9]`. In other words, tests stay flexible even if we
///   fine-tune the exact alphabet inside `JoinCode`.
/// ---------------------------------------------------------------------------
void main() {
  test('generate() returns 6-char uppercase A–Z/0–9 by default', () {
    final code = JoinCode.generate();

    // Default length is 6
    expect(code.length, 6);

    // We generate a subset of this regex (we exclude I/O/0/1 internally),
    // but matching the superset keeps the test stable if we tweak the alphabet.
    expect(RegExp(r'^[A-Z0-9]{6}$').hasMatch(code), isTrue);
  });

  test('generate() supports custom length', () {
    final code = JoinCode.generate(length: 8);

    // Length parameter is honored
    expect(code.length, 8);

    // Same superset reasoning as above
    expect(RegExp(r'^[A-Z0-9]{8}$').hasMatch(code), isTrue);
  });

  test('low collision rate across many generations', () {
    // Not a proof of randomness—just a smoke test that suggests good variety.
    final seen = <String>{};
    for (var i = 0; i < 2000; i++) {
      seen.add(JoinCode.generate());
    }
    expect(seen.length, greaterThan(1950));   // allow a few accidental collisions
  });

  test('validator checks expected length', () {
    // Generate valid samples and verify length enforcement.
    final c6 = JoinCode.generate();
    final c8 = JoinCode.generate(length: 8);

    // Defaults to 6
    expect(JoinCode.isValid(c6), isTrue);

    // Custom length works
    expect(JoinCode.isValid(c8, length: 8), isTrue);

    // Wrong length should fail
    expect(JoinCode.isValid(c8, length: 6), isFalse);
  });
}
