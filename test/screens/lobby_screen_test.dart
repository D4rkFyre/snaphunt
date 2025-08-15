import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/screens/lobby_screen.dart';

void main() {
  testWidgets('Lobby shows live players and can Start Game', (tester) async {
    final fake = FakeFirebaseFirestore();

    // Seed game
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
      ),
    ));

    // First frame
    await tester.pump();

    // Players render
    expect(find.text('PlayerOne'), findsOneWidget);
    expect(find.text('PlayerTwo'), findsOneWidget);

    // Tap Start Game
    await tester.tap(find.text('Start Game'));
    await tester.pump();

    // Verify status updated
    final snap = await fake.collection('games').doc(gameRef.id).get();
    expect(snap.data()?['status'], 'active');
  });
}
