// lib/repositories/game_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/models/game_model.dart';
import 'package:snaphunt/services/firestore_refs.dart';
import 'package:snaphunt/services/join_code.dart';

/// Handles game creation and code uniqueness using Firestore transactions.
class GameRepository {
  final FirebaseFirestore db;

  /// If no Firestore instance is passed, default to live Firestore instance
  GameRepository({FirebaseFirestore? firestore})
    : db = firestore ?? FirebaseFirestore.instance;

  /// Creates a new game with a unique join code.
  /// - Reserves code at /codes/{code} (doc id = code)
  /// - Creates the game at /games/{autoId}
  /// Returns the created Game.
  Future<Game> createGame() async {
    const maxAttempts = 10;  // Avoid infinite loops

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      // random 6-character join code
      final code = JoinCode.generate();

      try {
        // Firestore transaction start (atomic)
        final game = await db.runTransaction<Game>((tx) async {
          // 1) Pick a code and check if reserved
          final codeRef = FirestoreRefs.codeDoc(db, code);
          final codeSnap = await tx.get(codeRef);
          if (codeSnap.exists) {
            // collision → retry
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'already-exists',
              message: 'Join code collision',
            );
          }

          // 2) Create the game doc FIRST to get its id
          final gamesCol = FirestoreRefs.games(db);
          final newGameRef = gamesCol.doc(); // auto-id

          // 3) Reserve the code and link it to the game
          tx.set(codeRef, {
            'status': 'reserved',
            'gameId': newGameRef.id,                 // <— add this
            'createdAt': FieldValue.serverTimestamp(),
          });

          // 4) Create the game
          tx.set(newGameRef, {
            'joinCode': code,
            'status': 'waiting',
            'createdAt': FieldValue.serverTimestamp(),
            'players': <String>[],
          });

          // 5) Return local model (createdAt is local; Firestore has server time)
          return Game(
            id: newGameRef.id,
            joinCode: code,
            status: 'waiting',
            createdAt: DateTime.now(),
            players: const [],
          );
        });


        return game; // success
      } on FirebaseException catch (e) {
        // Retry if game code exists (until retry limit)
        if (e.code == 'already-exists') {
          if (attempt == maxAttempts) rethrow;
          continue; // try a new code
        }
        rethrow;
      }
    }

    // EVERYTHING HAS FAILED IF WE ARE HERE.
    throw StateError(
      'Failed to create a unique join code after $maxAttempts attempts.',
    );
  }
}
