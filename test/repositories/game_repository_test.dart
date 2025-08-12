// test/repositories/game_repository_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/repositories/game_repository.dart';

void main() {
  test('createGame creates game and reserves a unique code', () async {
    final fake = FakeFirebaseFirestore();
    final repo = GameRepository(firestore: fake);

    final g1 = await repo.createGame();
    expect(g1.joinCode.length, 6);

    // code reservation exists
    final codeDoc1 = await fake.collection('codes').doc(g1.joinCode).get();
    expect(codeDoc1.exists, true);

    // create a second game; code should differ
    final g2 = await repo.createGame();
    expect(g2.joinCode, isNot(g1.joinCode));

    // both games exist
    final games = await fake.collection('games').get();
    expect(games.docs.length, 2);
  });

  test('repository stores expected fields on game doc', () async {
    final fake = FakeFirebaseFirestore();
    final repo = GameRepository(firestore: fake);

    final g = await repo.createGame();
    final snap = await fake.collection('games').doc(g.id).get();
    final data = snap.data()!;

    expect(data['joinCode'], g.joinCode);
    expect(data['status'], 'waiting');
    expect(data['players'], isA<List<dynamic>>());
    expect(data['players'], isEmpty);
    expect(data['createdAt'], isA<Timestamp>());
  });
}
