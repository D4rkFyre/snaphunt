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
  /// If [hostName] is provided, seeds the players array with the host.
  Future<Game> createGame({String? hostName}) async {
    const maxAttempts = 10;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final code = JoinCode.generate();
      try {
        final game = await db.runTransaction<Game>((tx) async {
          // 1) Reserve code if free
          final codeRef = FirestoreRefs.codeDoc(db, code);
          final codeSnap = await tx.get(codeRef);
          if (codeSnap.exists) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'already-exists',
              message: 'Join code collision',
            );
          }

          // 2) Create game doc (to get id)
          final gamesCol = FirestoreRefs.games(db);
          final newGameRef = gamesCol.doc();

          // 3) Link code -> game
          tx.set(codeRef, {
            'status': 'reserved',
            'gameId': newGameRef.id,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // 4) Create game (seed host if provided)
          tx.set(newGameRef, {
            'joinCode': code,
            'status': 'waiting',
            'createdAt': FieldValue.serverTimestamp(),
            'players': hostName == null ? <String>[] : <String>[hostName],
          });

          // 5) Return local model
          return Game(
            id: newGameRef.id,
            joinCode: code,
            status: 'waiting',
            createdAt: DateTime.now(),
            players: hostName == null ? const [] : [hostName],
          );
        });
        return game;
      } on FirebaseException catch (e) {
        if (e.code == 'already-exists') {
          if (attempt == maxAttempts) rethrow;
          continue;
        }
        rethrow;
      }
    }
    throw StateError('Failed to create a unique join code after $maxAttempts attempts.');
  }
}
