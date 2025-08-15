import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snaphunt/screens/find_game_screen.dart';
import 'package:snaphunt/screens/lobby_screen.dart';

void main() {
  testWidgets('enter code, join game, navigate to lobby', (tester) async {
    final fake = FakeFirebaseFirestore();

    // Seed a fake game and code mapping
    final gameRef = await fake.collection('games').add({
      'joinCode': 'ABC123',
      'status': 'waiting',
      'createdAt': DateTime.now(), // fake sets timestamps as DateTime
      'players': <String>[],
    });
    await fake.collection('codes').doc('ABC123').set({
      'status': 'reserved',
      'gameId': gameRef.id,
      'createdAt': DateTime.now(),
    });

    await tester.pumpWidget(MaterialApp(
      home: JoinGameScreen(db: fake),
    ));

    // Enter code and tap Join
    await tester.enterText(find.byType(TextField), 'abc123');
    await tester.tap(find.text('Find a Game'));
    await tester.pumpAndSettle();

    // Arrived at lobby
    expect(find.byType(CreateGameLobbyScreen), findsOneWidget);

    // Players array updated
    final snap = await fake.collection('games').doc(gameRef.id).get();
    final players = (snap.data()!['players'] as List).cast<String>();
    expect(players.isNotEmpty, true);
  });
}
