// test/services/join_code_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/services/join_code.dart';

void main() {
  test('generate() returns 6-char uppercase A–Z/0–9 by default', () {
    final code = JoinCode.generate();
    expect(code.length, 6);
    // Accept any A–Z0–9; we happened to exclude I/O/0/1 internally, which still matches this regex.
    expect(RegExp(r'^[A-Z0-9]{6}$').hasMatch(code), isTrue);
  });

  test('generate() supports custom length', () {
    final code = JoinCode.generate(length: 8);
    expect(code.length, 8);
    expect(RegExp(r'^[A-Z0-9]{8}$').hasMatch(code), isTrue);
  });

  test('low collision rate across many generations', () {
    final seen = <String>{};
    for (var i = 0; i < 2000; i++) {
      seen.add(JoinCode.generate());
    }
    // Not a proof, just a sanity check for variety.
    expect(seen.length, greaterThan(1950));
  });

  test('validator checks expected length', () {
    final c6 = JoinCode.generate();
    final c8 = JoinCode.generate(length: 8);
    expect(JoinCode.isValid(c6), isTrue);
    expect(JoinCode.isValid(c8, length: 8), isTrue);
    expect(JoinCode.isValid(c8, length: 6), isFalse);
  });
}
