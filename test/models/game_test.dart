// test/models/game_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/models/game_model.dart';

void main() {
  test('Game.toJson produces Firestore-friendly map', () {
    final now = DateTime.now();
    final g = Game(
      id: 'abc123',
      joinCode: 'A1B2C3',
      status: 'waiting',
      createdAt: now,
      players: const [],
    );

    final json = g.toJson();
    expect(json['joinCode'], 'A1B2C3');
    expect(json['status'], 'waiting');
    expect(json['players'], isA<List<dynamic>>());
    expect(json['createdAt'], isA<Timestamp>());
    expect(
      (json['createdAt'] as Timestamp).toDate().millisecondsSinceEpoch,
      closeTo(now.millisecondsSinceEpoch, 1000),
    );
  });

  test('Game.fromMap parses fields correctly', () {
    final ts = Timestamp.fromDate(DateTime.utc(2025, 1, 2, 3, 4, 5));
    final map = {
      'joinCode': 'Z9Y8X7',
      'status': 'waiting',
      'createdAt': ts,
      'players': <String>[],
    };

    final g = Game.fromMap('doc123', map);
    expect(g.id, 'doc123');
    expect(g.joinCode, 'Z9Y8X7');
    expect(g.status, 'waiting');
    expect(g.createdAt, ts.toDate());
    expect(g.players, isEmpty);
  });
}
