// test/dev/dev_host_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/dev/dev_host_screen.dart';
import 'package:snaphunt/models/game_model.dart';
import 'package:snaphunt/repositories/game_repository.dart';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

class _FakeRepoSuccess extends GameRepository {
  _FakeRepoSuccess() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<Game> createGame() async {
    return Game(
      id: 'fake123',
      joinCode: 'ABC123',
      status: 'waiting',
      createdAt: DateTime.now(),
      players: const [],
    );
  }
}

class _FakeRepoFailure extends GameRepository {
  _FakeRepoFailure() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<Game> createGame() async {
    throw Exception('boom');
  }
}

void main() {
  testWidgets('DevHostScreen creates a game and shows code', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: DevHostScreen(repo: _FakeRepoSuccess())),
    );

    // Tap the FAB
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Verify join code + id are displayed
    expect(find.textContaining('Last game id: fake123'), findsOneWidget);
    expect(find.textContaining('Last join code: ABC123'), findsOneWidget);
    // Optional: SnackBar text also appears
    expect(
      find.textContaining('Created game fake123 with code ABC123'),
      findsOneWidget,
    );
  });

  testWidgets('DevHostScreen shows error on failure', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: DevHostScreen(repo: _FakeRepoFailure())),
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('Error:'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });
}
