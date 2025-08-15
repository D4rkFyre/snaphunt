// test/models/game_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/models/game_model.dart';

/// ---------------------------------------------------------------------------
/// Game model tests
/// ---------------------------------------------------------------------------
/// Purpose
/// - Make sure our `Game` model converts to/from Firestore maps correctly.
/// - These tests do **not** hit the network; we just use Firestore types like
///   `Timestamp` to simulate what real docs look like.
/// ---------------------------------------------------------------------------
void main() {
  test('Game.toJson produces Firestore-friendly map', () {
    // Given a Game instance in memory
    final now = DateTime.now();
    final g = Game(
      id: 'abc123',          // doc id (not included in toJson)
      joinCode: 'A1B2C3',
      status: 'waiting',
      createdAt: now,        // will be converted to Timestamp
      players: const [],
    );

    // When we serialize it for Firestore writes
    final json = g.toJson();

    // Then the shape and types should match what Firestore expects
    expect(json['joinCode'], 'A1B2C3');
    expect(json['status'], 'waiting');
    expect(json['players'], isA<List<dynamic>>());
    expect(json['createdAt'], isA<Timestamp>());

    // Allow small clock drift between DateTime.now() and conversion
    expect(
      (json['createdAt'] as Timestamp).toDate().millisecondsSinceEpoch,
      closeTo(now.millisecondsSinceEpoch, 1000),  // within 1s
    );
  });

  test('Game.fromMap parses fields correctly', () {
    // Given a map that looks like a Firestore document
    final ts = Timestamp.fromDate(DateTime.utc(2025, 1, 2, 3, 4, 5));
    final map = {
      'joinCode': 'Z9Y8X7',
      'status': 'waiting',
      'createdAt': ts,         // Firestore stores timestamps as `Timestamp`
      'players': <String>[],
    };

    // When we build a Game from it (and supply a known id)
    final g = Game.fromMap('doc123', map);

    // Then all fields should be parsed and typed properly
    expect(g.id, 'doc123');
    expect(g.joinCode, 'Z9Y8X7');
    expect(g.status, 'waiting');
    expect(g.createdAt, ts.toDate());   // converted back to DateTime
    expect(g.players, isEmpty);
  });
}
