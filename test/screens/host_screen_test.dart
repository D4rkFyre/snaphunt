// test/screens/host_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:snaphunt/screens/host_screen.dart';
import 'package:snaphunt/screens/lobby_screen.dart';
import 'package:snaphunt/models/game_model.dart';
import 'package:snaphunt/repositories/game_repository.dart';

/// Simple mock for the repository so we can intercept createGame()
class _MockGameRepository extends Mock implements GameRepository {}

/// ---------------------------------------------------------------------------
/// HostGameScreen test
/// ---------------------------------------------------------------------------
/// Purpose
/// - Pressing **Create Game** should:
///   1) Call `GameRepository.createGame(hostName: ...)`
///   2) Navigate to the Lobby, passing the returned `gameId` + `joinCode`
///   3) Show the join code in the Lobby
///
/// Test strategy
/// - Use a **mock** `GameRepository` so we control the return value.
/// - Use **FakeFirebaseFirestore** so the Lobby’s StreamBuilder has a doc to read.
/// - Inject both into `HostGameScreen(repo: ..., db: ...)`.
///
/// Issues covered
/// - `mocktail` needs to match the **named argument** `hostName:` when stubbing.
/// - We seed `/games/{id}` so that once the screen navigates to Lobby,
///   the stream emits real data and the UI can render.
/// ---------------------------------------------------------------------------
void main() {
  testWidgets('Create Game calls repo and navigates to Lobby with args', (tester) async {
    final fakeDb = FakeFirebaseFirestore();

    // Seed the game doc the Lobby will listen to in real time.
    await fakeDb.collection('games').doc('g_123').set({
      'joinCode': 'ZK7M3Q',
      'status': 'waiting',
      'createdAt': DateTime.now(),
      'players': <String>['Host'], // since hostName is seeded by createGame()
    });

    // Mock the repository so we control createGame() output.
    final mockRepo = _MockGameRepository();
    final fakeGame = Game(
      id: 'g_123',
      joinCode: 'ZK7M3Q',
      status: 'waiting',
      createdAt: DateTime(2025, 1, 1),
      players: const ['Host'],
    );

    // IMPORTANT: match the named argument when stubbing with mocktail.
    when(() => mockRepo.createGame(hostName: any(named: 'hostName')))
        .thenAnswer((_) async => fakeGame);

    // Pump the Host screen with injected repo + db (DI-friendly for tests)
    await tester.pumpWidget(
      MaterialApp(
        home: HostGameScreen(repo: mockRepo, db: fakeDb),
      ),
    );

    // Tap "Create Game" → triggers repo call and then navigation to Lobby.
    await tester.tap(find.text('Create Game'));
    await tester.pump();            // start async
    await tester.pumpAndSettle();   // finish nav + first lobby stream tick

    // Verify the repo was invoked with a hostName.
    // (We can assert a specific value instead of any(...) if desired.)
    verify(() => mockRepo.createGame(hostName: any(named: 'hostName'))).called(1);
    // or: verify(() => mockRepo.createGame(hostName: 'Host')).called(1);

    // Landed in Lobby and the join code is visible
    expect(find.byType(CreateGameLobbyScreen), findsOneWidget);
    expect(find.text('ZK7M3Q'), findsOneWidget);
  });
}
