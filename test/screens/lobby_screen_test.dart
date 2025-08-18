// test/screens/lobby_screen_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/screens/lobby_screen.dart';

/// ---------------------------------------------------------------------------
/// LobbyScreen tests
/// ---------------------------------------------------------------------------
/// Purpose
/// - Verify live lobby behavior:
///   1) Host sees a **Start Game** button and can flip status to "active"
///   2) Non-host users must NOT see the Start button
///
/// Test strategy
/// - Use `FakeFirebaseFirestore` so the Lobby’s StreamBuilder reads seeded docs
///   instantly without hitting the network.
/// - Pump `CreateGameLobbyScreen` with `db: fake` and appropriate `isHost`.
/// - Assert on UI and on Firestore side-effects (status change).
/// ---------------------------------------------------------------------------
void main() {
  testWidgets('Host sees Start Game and can set status active', (tester) async {
    final fake = FakeFirebaseFirestore();

    // Seed a WAITING game with some players for the lobby to render.
    final gameRef = await fake.collection('games').add({
      'joinCode': 'ABC123',
      'status': 'waiting',           // ← must be waiting; enables Start button
      'createdAt': DateTime.now(),
      'players': <String>['PlayerOne', 'PlayerTwo'],
    });

    // Pump the Lobby as HOST (isHost: true) using the same fake DB.
    await tester.pumpWidget(MaterialApp(
      home: CreateGameLobbyScreen(
        db: fake,
        gameId: gameRef.id,
        joinCode: 'ABC123',
        isHost: true,   // ← host view shows Start Game
      ),
    ));

    // Let the first stream tick render.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Players render in the grid (live from stream).
    expect(find.text('PlayerOne'), findsOneWidget);
    expect(find.text('PlayerTwo'), findsOneWidget);

    // Host sees Start Game.
    expect(find.text('Start Game'), findsOneWidget);

    // Tap Start Game → should flip status to "active".
    await tester.tap(find.text('Start Game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Verify the Firestore doc updated.
    final snap = await fake.collection('games').doc(gameRef.id).get();
    expect(snap.data()?['status'], 'active');
  });

  testWidgets('Non-host cannot see Start Game button', (tester) async {
    final fake = FakeFirebaseFirestore();

    // Seed a WAITING game with one player.
    final gameRef = await fake.collection('games').add({
      'joinCode': 'ABC123',
      'status': 'waiting',
      'createdAt': DateTime.now(),
      'players': <String>['PlayerOne'],
    });

    // Pump the Lobby as a PLAYER (isHost: false).
    await tester.pumpWidget(MaterialApp(
      home: CreateGameLobbyScreen(
        db: fake,
        gameId: gameRef.id,
        joinCode: 'ABC123',
        isHost: false,   // ← player view should NOT show Start Game
      ),
    ));

    // Let the first stream tick render.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Non-hosts must not see the Start Game button.
    expect(find.text('Start Game'), findsNothing);
  });
}
