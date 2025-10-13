// test/repositories/game_repository_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/repositories/game_repository.dart';

/// ---------------------------------------------------------------------------
/// GameRepository tests
/// ---------------------------------------------------------------------------
/// Purpose
/// - Verify that creating a game:
///   1) Reserves a unique join code in `/codes/{CODE}`
///   2) Creates a matching `/games/{gameId}`
///   3) Links code → game via `gameId`
///   4) Writes expected fields (status, players[], createdAt)
///
/// Test strategy
/// - Use `FakeFirebaseFirestore` (no network) so we can read back what was
///   written in the transaction and make assertions on the resulting docs.
///
/// Notes
/// - `createGame()` seeds `players` with the host only if `hostName` is passed.
///   In these tests we omit `hostName`, so `players` should start empty.
/// ---------------------------------------------------------------------------
void main() {
  test('createGame creates game and reserves a unique code (linked to gameId)', () async {
    // Arrange: in-memory Firestore + repository using it
    final fake = FakeFirebaseFirestore();
    final repo = GameRepository(firestore: fake);

    // Act: create first game
    final g1 = await repo.createGame();

    // Assert: code shape + reservation exists
    expect(g1.joinCode.length, 6);

    // /codes/{CODE} must exist and link back to /games/{gameId}
    final codeDoc1 = await fake.collection('codes').doc(g1.joinCode).get();
    expect(codeDoc1.exists, true);
    expect(codeDoc1.data()?['status'], 'reserved');
    expect(codeDoc1.data()?['gameId'], g1.id);

    // Act: create a second game
    final g2 = await repo.createGame();

    // Assert: codes should differ (uniqueness)
    expect(g2.joinCode, isNot(g1.joinCode));

    // And both /games docs should exist
    final games = await fake.collection('games').get();
    expect(games.docs.length, 2);

    // Second code should also link back correctly
    final codeDoc2 = await fake.collection('codes').doc(g2.joinCode).get();
    expect(codeDoc2.exists, true);
    expect(codeDoc2.data()?['status'], 'reserved');
    expect(codeDoc2.data()?['gameId'], g2.id);
  });

  test('repository stores expected fields on game doc', () async {
    // Arrange
    final fake = FakeFirebaseFirestore();
    final repo = GameRepository(firestore: fake);

    // Act
    final g = await repo.createGame();

    // Assert: /games/{gameId} has the right shape
    final snap = await fake.collection('games').doc(g.id).get();
    final data = snap.data()!;

    expect(data['joinCode'], g.joinCode);
    expect(data['status'], 'waiting');

    // players[] exists and is empty (no hostName passed in this test)
    expect(data['players'], isA<List<dynamic>>());
    expect((data['players'] as List).length, 0);

    // createdAt is a Firestore Timestamp (FakeFirestore simulates server time)
    expect(data['createdAt'], isA<Timestamp>());
  });

  test('codes/{CODE} contains gameId and createdAt', () async {
    // Arrange
    final fake = FakeFirebaseFirestore();
    final repo = GameRepository(firestore: fake);

    // Act
    final g = await repo.createGame();

    // Assert: /codes/{CODE} mirrors the link + metadata
    final codeSnap = await fake.collection('codes').doc(g.joinCode).get();
    final codeData = codeSnap.data()!;

    expect(codeData['gameId'], g.id);
    expect(codeData['status'], 'reserved');
    expect(codeData['createdAt'], isA<Timestamp>());
  });
}
