import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snaphunt/screens/find_game_screen.dart';
import 'package:snaphunt/screens/lobby_screen.dart';

void main() {
  testWidgets('Valid code joins waiting game and navigates to Lobby', (tester) async {
    final fake = FakeFirebaseFirestore();

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

    await tester.pumpWidget(MaterialApp(home: JoinGameScreen(db: fake)));
    await tester.enterText(find.byType(TextField).at(1), 'abcd23'); // code box
    await tester.tap(find.text('Find a Game'));
    await tester.pumpAndSettle();

    // Landed in Lobby
    expect(find.byType(CreateGameLobbyScreen), findsOneWidget);

    // Player added
    final snap = await fake.collection('games').doc(gameRef.id).get();
    final players = (snap.data()!['players'] as List).cast<String>();
    expect(players.isNotEmpty, true);
  });
}
