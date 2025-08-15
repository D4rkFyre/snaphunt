import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snaphunt/screens/find_game_screen.dart';
import 'package:snaphunt/screens/lobby_screen.dart';

void main() {
  testWidgets('enter code, join game, navigate to lobby', (tester) async {
    final fake = FakeFirebaseFirestore();

    // Seed a WAITING game and link it from /codes/{CODE}
    final gameRef = await fake.collection('games').add({
      'joinCode': 'ABCD23',
      'status': 'waiting',
      'createdAt': DateTime.now(),
      'players': <String>[],
    });
    await fake.collection('codes').doc('ABCD23').set({
      'status': 'reserved',
      'gameId': gameRef.id,
      'createdAt': DateTime.now(),
    });

    // Pump the Join screen with the same fake DB
    await tester.pumpWidget(MaterialApp(home: JoinGameScreen(db: fake)));
    await tester.pump(); // settle first frame

    // (Optional) enter a nickname in the first TextField
    await tester.enterText(find.byType(TextField).at(0), 'Tester');

    // Enter the CODE in the second TextField (nickname is at index 0)
    await tester.enterText(find.byType(TextField).at(1), 'abcd23'); // lower; widget uppercases
    await tester.tap(find.text('Find a Game'));

    // Let async + navigation + first lobby stream frame settle
    await tester.pump();                 // start async
    await tester.pumpAndSettle();        // finish nav/stream

    // We should now be in the Lobby
    expect(find.byType(CreateGameLobbyScreen), findsOneWidget);
    expect(find.text('ABCD23'), findsOneWidget);

    // Player should have been added to the game
    final snap = await fake.collection('games').doc(gameRef.id).get();
    final players = (snap.data()!['players'] as List).cast<String>();
    expect(players.isNotEmpty, true);
  });
}
