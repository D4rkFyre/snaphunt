// lib/repositories/game_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/models/game_model.dart';
import 'package:snaphunt/services/firestore_refs.dart';
import 'package:snaphunt/services/join_code.dart';

/// Handles game creation and code uniqueness using Firestore transactions.
class GameRepository {
  final FirebaseFirestore db;

  GameRepository({FirebaseFirestore? firestore})
    : db = firestore ?? FirebaseFirestore.instance;

  /// Creates a new game with a unique join code.
  /// - Reserves code at /codes/{code} (doc id = code)
  /// - Creates the game at /games/{autoId}
  /// Returns the created Game.
  Future<Game> createGame() async {
    const maxAttempts = 10;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final code = JoinCode.generate();

      try {
        final game = await db.runTransaction<Game>((tx) async {
          // 1) Check if code is already reserved.
          final codeRef = FirestoreRefs.codeDoc(db, code);
          final codeSnap = await tx.get(codeRef);
          if (codeSnap.exists) {
            // collision → retry with a new code
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'already-exists',
              message: 'Join code collision',
            );
          }

          // 2) Reserve the code.
          tx.set(codeRef, {
            'status': 'reserved',
            'createdAt': FieldValue.serverTimestamp(),
          });

          // 3) Create the game in the same transaction (atomic).
          final gamesCol = FirestoreRefs.games(db);
          final newGameRef = gamesCol.doc(); // auto-id
          tx.set(newGameRef, {
            'joinCode': code,
            'status': 'waiting',
            'createdAt': FieldValue.serverTimestamp(),
            'players': <String>[],
          });

          return Game(
            id: newGameRef.id,
            joinCode: code,
            status: 'waiting',
            createdAt: DateTime.now(), // local convenience; stored is server ts
            players: const [],
          );
        });

        return game; // success
      } on FirebaseException catch (e) {
        if (e.code == 'already-exists') {
          if (attempt == maxAttempts) rethrow;
          continue; // try a new code
        }
        rethrow;
      }
    }

    throw StateError(
      'Failed to create a unique join code after $maxAttempts attempts.',
    );
  }
}
