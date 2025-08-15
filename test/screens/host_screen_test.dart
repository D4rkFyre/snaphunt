// test/screens/host_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:snaphunt/screens/host_screen.dart';
import 'package:snaphunt/screens/lobby_screen.dart';
import 'package:snaphunt/models/game_model.dart';
import 'package:snaphunt/repositories/game_repository.dart';

class _MockGameRepository extends Mock implements GameRepository {}

void main() {
  testWidgets('Create Game calls repo and navigates to Lobby with args', (tester) async {
    // Use a fake Firestore so we don't need Firebase.initializeApp()
    final fakeDb = FakeFirebaseFirestore();

    // Seed the game doc the Lobby will stream from (ID must match mocked Game.id)
    await fakeDb.collection('games').doc('g_123').set({
      'joinCode': 'ZK7M3Q',
      'status': 'waiting',
      'createdAt': DateTime.now(),
      'players': <String>[],
    });

    // Mock the repository to return that same game id/code
    final mockRepo = _MockGameRepository();
    final fakeGame = Game(
      id: 'g_123',
      joinCode: 'ZK7M3Q',
      status: 'waiting',
      createdAt: DateTime(2025, 1, 1),
      players: const [],
    );
    // Mocktail: Answer must accept an argument
    when(() => mockRepo.createGame()).thenAnswer((_) async => fakeGame);

    // Pump Host screen with injected repo and db (so Lobby uses the same fakeDb)
    await tester.pumpWidget(
      MaterialApp(
        home: HostGameScreen(repo: mockRepo, db: fakeDb),
      ),
    );

    // Tap "Create Game"
    final createButton = find.text('Create Game');
    expect(createButton, findsOneWidget);
    await tester.tap(createButton);

    // Let async + navigation + first stream frame complete
    await tester.pump();            // start async
    await tester.pumpAndSettle();   // finish nav & stream build

    // Repo called once
    verify(() => mockRepo.createGame()).called(1);

    // Landed in Lobby and the join code is visible
    expect(find.byType(CreateGameLobbyScreen), findsOneWidget);
    expect(find.text('ZK7M3Q'), findsOneWidget);
  });
}
