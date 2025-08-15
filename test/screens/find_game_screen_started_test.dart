import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snaphunt/screens/find_game_screen.dart';

void main() {
  testWidgets('Entering code for active game shows "Game already started."', (tester) async {
    final fake = FakeFirebaseFirestore();

    // Seed ACTIVE game and code
    final gameRef = await fake.collection('games').add({
      'joinCode': 'START1',
      'status': 'active',
      'createdAt': DateTime.now(),
      'players': <String>['Host'],
    });
    await fake.collection('codes').doc('START1').set({
      'status': 'reserved',
      'gameId': gameRef.id,
      'createdAt': DateTime.now(),
    });

    await tester.pumpWidget(MaterialApp(home: JoinGameScreen(db: fake)));

    // Enter code lowercased to verify it uppercases/validates
    await tester.enterText(find.byType(TextField).at(1), 'start1');
    await tester.tap(find.text('Find a Game'));
    await tester.pumpAndSettle();

    // Error text shows
    expect(find.text('Game already started.'), findsOneWidget);

    // Ensure no player was added
    final snap = await fake.collection('games').doc(gameRef.id).get();
    final players = (snap.data()!['players'] as List).cast<String>();
    expect(players, contains('Host'));
    expect(players.length, 1);
  });
}
