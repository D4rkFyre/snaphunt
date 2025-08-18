// test/screens/find_game_screen_started_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/screens/find_game_screen.dart';

/// ---------------------------------------------------------------------------
/// JoinGameScreen (active game) test
/// ---------------------------------------------------------------------------
/// Purpose
/// - If a player enters a valid code for a game that is already "active",
///   the screen should show the message **"Game already started."**
///   and must NOT add the player to the lobby.
///
/// What we simulate here
/// - A game doc with `status: "active"`
/// - A matching code doc that points to that game
/// - Typing the code (lowercased) to ensure UI handles uppercase conversion
/// - Tapping "Find a Game" → expect the error text
///
/// Why FakeFirebaseFirestore?
/// - No network calls; we can seed docs and read them back synchronously.
/// ---------------------------------------------------------------------------
void main() {
  testWidgets('Entering code for active game shows "Game already started."', (tester) async {
    final fake = FakeFirebaseFirestore();

    // Seed an ACTIVE game and its code mapping
    // Note: createdAt uses DateTime here; FakeFirestore accepts that for tests.
    final gameRef = await fake.collection('games').add({
      'joinCode': 'START1',
      'status': 'active',             // ← key: already started
      'createdAt': DateTime.now(),
      'players': <String>['Host'],
    });
    await fake.collection('codes').doc('START1').set({
      'status': 'reserved',
      'gameId': gameRef.id,             // ← link code → game
      'createdAt': DateTime.now(),
    });

    // Pump the Join screen using the fake Firestore
    await tester.pumpWidget(MaterialApp(home: JoinGameScreen(db: fake)));

    // Enter the code (lowercase) to verify UI normalizes to uppercase + validates.
    // There are two TextFields: [0] nickname, [1] game code.
    await tester.enterText(find.byType(TextField).at(1), 'start1');

    // Attempt to join
    await tester.tap(find.text('Find a Game'));
    await tester.pumpAndSettle();

    // Expect a clear error message
    expect(find.text('Game already started.'), findsOneWidget);

    // Double-check no player was added accidentally
    final snap = await fake.collection('games').doc(gameRef.id).get();
    final players = (snap.data()!['players'] as List).cast<String>();
    expect(players, contains('Host'));
    expect(players.length, 1);    // still only the host
  });
}
