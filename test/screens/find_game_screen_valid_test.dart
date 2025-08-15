// test/screens/find_game_screen_valid_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/screens/find_game_screen.dart';
import 'package:snaphunt/screens/lobby_screen.dart';

/// ---------------------------------------------------------------------------
/// JoinGameScreen (valid waiting game) test
/// ---------------------------------------------------------------------------
/// Purpose
/// - Given a valid code for a **waiting** game:
///   - Tapping "Find a Game" should navigate to the Lobby
///   - The player should be appended to `players[]`
///
/// Why FakeFirebaseFirestore?
/// - Lets us seed `/games` and `/codes` without hitting the network,
///   and then read back the effect after the UI runs.
/// ---------------------------------------------------------------------------
void main() {
  testWidgets('Valid code joins waiting game and navigates to Lobby', (tester) async {
    final fake = FakeFirebaseFirestore();

    // Seed a WAITING game + link its code
    final gameRef = await fake.collection('games').add({
      'joinCode': 'ABCD23',
      'status': 'waiting',          // ← allows joins
      'createdAt': DateTime.now(),
      'players': <String>[],
    });
    await fake.collection('codes').doc('ABCD23').set({
      'status': 'reserved',
      'gameId': gameRef.id,          // ← link code → game
      'createdAt': DateTime.now(),
    });

    // Pump Join screen with the same fake DB
    await tester.pumpWidget(MaterialApp(home: JoinGameScreen(db: fake)));

    // Enter code (lowercase on purpose; widget uppercases/validates internally)
    await tester.enterText(find.byType(TextField).at(1), 'abcd23'); // code box
    await tester.tap(find.text('Find a Game'));
    await tester.pumpAndSettle();  // finish async + navigation + first lobby stream tick

    // Landed in Lobby
    expect(find.byType(CreateGameLobbyScreen), findsOneWidget);

    // Player was added to the game’s players[]
    final snap = await fake.collection('games').doc(gameRef.id).get();
    final players = (snap.data()!['players'] as List).cast<String>();
    expect(players.isNotEmpty, true);
  });
}
