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
    final fakeDb = FakeFirebaseFirestore();

    // Seed the game doc the Lobby will stream
    await fakeDb.collection('games').doc('g_123').set({
      'joinCode': 'ZK7M3Q',
      'status': 'waiting',
      'createdAt': DateTime.now(),
      'players': <String>['Host'], // since we now seed hostName
    });

    final mockRepo = _MockGameRepository();
    final fakeGame = Game(
      id: 'g_123',
      joinCode: 'ZK7M3Q',
      status: 'waiting',
      createdAt: DateTime(2025, 1, 1),
      players: const ['Host'],
    );

    // IMPORTANT: match the named argument
    when(() => mockRepo.createGame(hostName: any(named: 'hostName')))
        .thenAnswer((_) async => fakeGame);

    await tester.pumpWidget(
      MaterialApp(
        home: HostGameScreen(repo: mockRepo, db: fakeDb),
      ),
    );

    // Tap "Create Game"
    await tester.tap(find.text('Create Game'));
    await tester.pump();            // start async
    await tester.pumpAndSettle();   // finish nav + stream

    // Verify the repo was called with a hostName (you can match exact if you want)
    verify(() => mockRepo.createGame(hostName: any(named: 'hostName'))).called(1);
    // or: verify(() => mockRepo.createGame(hostName: 'Host')).called(1);

    // Landed in Lobby and the join code is visible
    expect(find.byType(CreateGameLobbyScreen), findsOneWidget);
    expect(find.text('ZK7M3Q'), findsOneWidget);
  });
}
