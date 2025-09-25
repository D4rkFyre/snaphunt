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
  test('Game.toMap produces Firestore-friendly map with enum-backed status', () {
    final ts = Timestamp.fromMillisecondsSinceEpoch(1711111111111);

    final g = Game(
      id: 'doc123',
      joinCode: 'Z9Y8X7',
      status: GameStatus.waiting,
      createdAt: ts,
      players: const [],
    );

    final map = g.toMap();

    expect(map['joinCode'], 'Z9Y8X7');
    expect(map['status'], GameStatus.waiting.asString);
    expect(map['createdAt'], ts);
    expect(map['players'], isA<List>());
    expect((map['players'] as List), isEmpty);
  });

  test('Game.fromMap parses map (legacy baseline)', () {
    final ts = Timestamp.fromMillisecondsSinceEpoch(1712222222222);
    final map = <String, dynamic>{
      'joinCode': 'Z9Y8X7',
      'status': 'waiting',
      'createdAt': ts,
      // legacy players format
      'players': <String>[],
    };

    final g = Game.fromMap('doc123', map);

    expect(g.id, 'doc123');
    expect(g.joinCode, 'Z9Y8X7');
    expect(g.status, GameStatus.waiting);
    expect(g.createdAt, ts);
    expect(g.players, isEmpty);
  });
}
