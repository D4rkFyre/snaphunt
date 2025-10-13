// test/models/game_model_persistence_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/models/game_model.dart';

void main() {
  group('Game model persistence fields', () {
    test('fromMap handles legacy string players and missing new fields', () {
      final data = <String, dynamic>{
        'joinCode': 'ABC123',
        'status': 'waiting',
        'createdAt': Timestamp.now(),
        // legacy players shape
        'players': ['Alice', 'Bob'],
        // no hostDeviceId / playerDeviceIds
      };

      final g = Game.fromMap('gid1', data);

      expect(g.id, 'gid1');
      expect(g.joinCode, 'ABC123');
      expect(g.status, GameStatus.waiting);
      expect(g.players.length, 2);
      expect(g.players[0].nickname, 'Alice');
      expect(g.players[1].nickname, 'Bob');
      expect(g.hostDeviceId, isNull);
      expect(g.playerDeviceIds, isEmpty);
    });

    test('fromMap parses new structured players & device fields', () {
      final now = Timestamp.now();
      final data = <String, dynamic>{
        'joinCode': 'ZXCVBN',
        'status': 'started',
        'createdAt': now,
        'hostDeviceId': 'host-123',
        'playerDeviceIds': ['p1', 'p2'],
        'players': const [
          {'deviceId': 'p1', 'nickname': 'Alice'},
          {'deviceId': 'p2', 'nickname': 'Bob'},
        ],
      };

      final g = Game.fromMap('gid2', data);

      expect(g.joinCode, 'ZXCVBN');
      expect(g.status, GameStatus.started);
      expect(g.createdAt, now);
      expect(g.hostDeviceId, 'host-123');
      expect(g.playerDeviceIds, ['p1', 'p2']);
      expect(g.players.map((e) => e.nickname).toList(), ['Alice', 'Bob']);
    });

    test('toMap emits expected Firestore-friendly structure', () {
      final ts = Timestamp.fromMillisecondsSinceEpoch(1720000000000);
      final g = Game(
        id: 'g3',
        joinCode: 'HELLO1',
        status: GameStatus.waiting,
        createdAt: ts,
        hostDeviceId: 'host-xyz',
        playerDeviceIds: const ['dev-a'],
        players: const [PlayerEntry(deviceId: 'dev-a', nickname: 'Nick')],
      );

      final m = g.toMap();
      expect(m['joinCode'], 'HELLO1');
      expect(m['status'], GameStatus.waiting.asString);
      expect(m['createdAt'], ts);
      expect(m['hostDeviceId'], 'host-xyz');
      expect(m['playerDeviceIds'], ['dev-a']);
      expect(m['players'], isA<List>());
      expect(m['players'][0]['deviceId'], 'dev-a');
      expect(m['players'][0]['nickname'], 'Nick');
    });
  });
}
