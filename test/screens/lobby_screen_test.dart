// test/screens/lobby_screen_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/screens/lobby_screen.dart';

void main() {
  testWidgets('Host sees Start Game and can set status active', (tester) async {
    final fake = FakeFirebaseFirestore();

    // Seed a waiting game with a couple of players
    final gameRef = await fake.collection('games').add({
      'joinCode': 'ABC123',
      'status': 'waiting',
      'createdAt': DateTime.now(),
      'players': <String>['PlayerOne', 'PlayerTwo'],
    });

    await tester.pumpWidget(MaterialApp(
      home: CreateGameLobbyScreen(
        db: fake,
        gameId: gameRef.id,
        joinCode: 'ABC123',
        isHost: true, // <-- required now
      ),
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Players render
    expect(find.text('PlayerOne'), findsOneWidget);
    expect(find.text('PlayerTwo'), findsOneWidget);

    // Host sees Start Game
    expect(find.text('Start Game'), findsOneWidget);

    // Tap Start Game
    await tester.tap(find.text('Start Game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Verify status flipped to active
    final snap = await fake.collection('games').doc(gameRef.id).get();
    expect(snap.data()?['status'], 'active');
  });

  testWidgets('Non-host cannot see Start Game button', (tester) async {
    final fake = FakeFirebaseFirestore();

    final gameRef = await fake.collection('games').add({
      'joinCode': 'ABC123',
      'status': 'waiting',
      'createdAt': DateTime.now(),
      'players': <String>['PlayerOne'],
    });

    await tester.pumpWidget(MaterialApp(
      home: CreateGameLobbyScreen(
        db: fake,
        gameId: gameRef.id,
        joinCode: 'ABC123',
        isHost: false, // <-- explicitly non-host
      ),
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // No Start Game for non-hosts
    expect(find.text('Start Game'), findsNothing);
  });
}
