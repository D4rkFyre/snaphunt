// test/screens/find_game_screen_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/screens/find_game_screen.dart';
import 'package:snaphunt/screens/lobby_screen.dart';

/// ---------------------------------------------------------------------------
/// JoinGameScreen test
/// ---------------------------------------------------------------------------
/// Purpose
/// - Simulate a normal join flow:
///   1) There is a **waiting** game in Firestore
///   2) `/codes/{CODE}` points to that game
///   3) User enters nickname + code and taps "Find a Game"
///   4) We navigate to the Lobby and the player gets added to `players[]`
///
/// Why this works without the network
/// - We use `FakeFirebaseFirestore` to seed the exact docs the UI expects,
///   then we read back results to assert side effects (e.g., player added).
/// ---------------------------------------------------------------------------
void main() {
  testWidgets('enter code, join game, navigate to lobby', (tester) async {
    final fake = FakeFirebaseFirestore();

    // Seed a WAITING game and link it from /codes/{CODE}
    final gameRef = await fake.collection('games').add({
      'joinCode': 'ABCD23',
      'status': 'waiting',          // ← must be waiting to allow joins
      'createdAt': DateTime.now(),
      'players': <String>[],
    });
    await fake.collection('codes').doc('ABCD23').set({
      'status': 'reserved',
      'gameId': gameRef.id,          // ← link code → game
      'createdAt': DateTime.now(),
    });

    // Pump the Join screen with the same fake DB
    await tester.pumpWidget(MaterialApp(home: JoinGameScreen(db: fake)));
    await tester.pump(); // settle first frame

    // (Optional) enter a nickname in the first TextField
    await tester.enterText(find.byType(TextField).at(0), 'Tester');

    // Enter the CODE in the second TextField (nickname is at index 0)
    // We type lowercase on purpose; the widget uppercases before validation.
    await tester.enterText(find.byType(TextField).at(1), 'abcd23');

    // Attempt to join
    await tester.tap(find.text('Find a Game'));

    // Let async work complete + push route + first lobby stream tick
    await tester.pump();                 // start async
    await tester.pumpAndSettle();        // finish nav/stream

    // We should now be in the Lobby
    expect(find.byType(CreateGameLobbyScreen), findsOneWidget);
    expect(find.text('ABCD23'), findsOneWidget);

    // Player nickname should have been appended to players[]
    final snap = await fake.collection('games').doc(gameRef.id).get();
    final players = (snap.data()!['players'] as List).cast<String>();
    expect(players.isNotEmpty, true);
  });
}
