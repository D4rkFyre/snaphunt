import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/repositories/game_repository.dart';

void main() {
  test('createGame creates game and reserves a unique code (linked to gameId)', () async {
    final fake = FakeFirebaseFirestore();
    final repo = GameRepository(firestore: fake);

    // Create first game
    final g1 = await repo.createGame();
    expect(g1.joinCode.length, 6);

    // Code reservation exists and links back to the game
    final codeDoc1 = await fake.collection('codes').doc(g1.joinCode).get();
    expect(codeDoc1.exists, true);
    expect(codeDoc1.data()?['status'], 'reserved');
    expect(codeDoc1.data()?['gameId'], g1.id);

    // Create a second game; code should differ
    final g2 = await repo.createGame();
    expect(g2.joinCode, isNot(g1.joinCode));

    // Both games exist
    final games = await fake.collection('games').get();
    expect(games.docs.length, 2);

    // Second code also links back correctly
    final codeDoc2 = await fake.collection('codes').doc(g2.joinCode).get();
    expect(codeDoc2.exists, true);
    expect(codeDoc2.data()?['status'], 'reserved');
    expect(codeDoc2.data()?['gameId'], g2.id);
  });

  test('repository stores expected fields on game doc', () async {
    final fake = FakeFirebaseFirestore();
    final repo = GameRepository(firestore: fake);

    final g = await repo.createGame();
    final snap = await fake.collection('games').doc(g.id).get();
    final data = snap.data()!;

    expect(data['joinCode'], g.joinCode);
    expect(data['status'], 'waiting');

    // players array exists (empty initially)
    expect(data['players'], isA<List<dynamic>>());
    expect((data['players'] as List).length, 0);

    // createdAt is a server timestamp
    expect(data['createdAt'], isA<Timestamp>());
  });

  test('codes/{CODE} contains gameId and createdAt', () async {
    final fake = FakeFirebaseFirestore();
    final repo = GameRepository(firestore: fake);

    final g = await repo.createGame();
    final codeSnap = await fake.collection('codes').doc(g.joinCode).get();
    final codeData = codeSnap.data()!;

    expect(codeData['gameId'], g.id);
    expect(codeData['status'], 'reserved');
    expect(codeData['createdAt'], isA<Timestamp>());
  });
}
