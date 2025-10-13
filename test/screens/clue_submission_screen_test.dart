// test/screens/clue_submission_screen_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:snaphunt/screens/clue_submission_screen.dart';
import 'package:snaphunt/repositories/game_repository.dart';
import 'package:snaphunt/models/clue_model.dart';

/// A simple fake repo that lets tests control the clues stream.
class _FakeGameRepository extends GameRepository {
  _FakeGameRepository() : super(firestore: FakeFirebaseFirestore());

  final _controller = StreamController<List<Clue>>.broadcast();

  void emit(List<Clue> clues) => _controller.add(clues);

  @override
  Stream<List<Clue>> streamClues(String gameId) => _controller.stream;

// If we later test upload, override uploadPlayerSubmission here to avoid Storage.
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget _wrap(Widget child) => MaterialApp(
    home: Scaffold(body: child),
  );

  group('ClueSubmissionScreen', () {
    testWidgets('shows empty state when no clues yet', (tester) async {
      final repo = _FakeGameRepository();

      await tester.pumpWidget(_wrap(ClueSubmissionScreen(
        gameId: 'game-1',
        playerId: 'player-1',
        repository: repo,
      )));

      // Stream starts with nothing → empty state
      repo.emit(const <Clue>[]);

      // Let the stream tick/render
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('No clues yet. Waiting for host...'), findsOneWidget);
    });

    testWidgets('renders a clue card with Submit button', (tester) async {
      final repo = _FakeGameRepository();

      await tester.pumpWidget(_wrap(ClueSubmissionScreen(
        gameId: 'game-1',
        playerId: 'player-1',
        repository: repo,
      )));

      // Emit one clue
      final clue = Clue(
        id: 'clue-1',
        imageUrl: 'https://example.com/image.jpg',
        createdBy: 'host',
        createdAt: DateTime.now(),
      );
      repo.emit([clue]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // We expect one card and a Submit button
      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('tapping Submit opens the photo source bottom sheet', (tester) async {
      final repo = _FakeGameRepository();

      await tester.pumpWidget(_wrap(ClueSubmissionScreen(
        gameId: 'game-1',
        playerId: 'player-1',
        repository: repo,
      )));

      // Emit one clue so we have a Submit button to tap.
      final clue = Clue(
        id: 'clue-1',
        imageUrl: 'https://example.com/image.jpg',
        createdBy: 'host',
        createdAt: DateTime.now(),
      );
      repo.emit([clue]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Tap "Submit"
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      // Bottom sheet should show both options
      expect(find.text('Choose from Gallery'), findsOneWidget);
      expect(find.text('Take a Photo'), findsOneWidget);

      // Dismiss the sheet to clean up
      // (Tap the system back or just pop the route)
      Navigator.of(tester.element(find.text('Choose from Gallery'))).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('updates UI when new clues arrive (live stream)', (tester) async {
      final repo = _FakeGameRepository();

      await tester.pumpWidget(_wrap(ClueSubmissionScreen(
        gameId: 'game-1',
        playerId: 'player-1',
        repository: repo,
      )));

      // Initially empty
      repo.emit(const <Clue>[]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('No clues yet. Waiting for host...'), findsOneWidget);

      // Later, host adds 2 clues → stream emits new list
      final c1 = Clue(
        id: 'c1',
        imageUrl: 'https://example.com/1.jpg',
        createdBy: 'host',
        createdAt: DateTime.now(),
      );
      final c2 = Clue(
        id: 'c2',
        imageUrl: 'https://example.com/2.jpg',
        createdBy: 'host',
        createdAt: DateTime.now(),
      );
      repo.emit([c1, c2]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Expect two cards (each with a Submit button)
      expect(find.byType(Card), findsNWidgets(2));
      expect(find.text('Submit'), findsNWidgets(2));
    });
  });
}
