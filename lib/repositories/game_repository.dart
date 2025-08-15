// lib/repositories/game_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/models/game_model.dart';
import 'package:snaphunt/services/firestore_refs.dart';
import 'package:snaphunt/services/join_code.dart';

/// ---------------------------------------------------------------------------
/// GameRepository
/// ---------------------------------------------------------------------------
/// Purpose: create a new game and guarantee the join code is unique.
///
/// Think of this as the "backend helper" for hosting a game. It:
/// 1) Generates a 6-char human code (e.g., "ZK7M3Q").
/// 2) Uses a Firestore *transaction* to:
///    - make sure nobody else already reserved that code
///    - create the game file `/games/{gameId}`
///    - store a pointer from `/codes/{CODE}` → `gameId`
///
/// Why a transaction?
/// - So the code reservation and the game creation happen *together or not at all*.
/// - Prevents race conditions where two hosts could grab the same code.
///
/// Returns: a `Game` model you can use to navigate to the Lobby.
/// ---------------------------------------------------------------------------
class GameRepository {
  final FirebaseFirestore db;

  /// You can pass a fake/injected Firestore in tests. In the app we default to the real one.
  GameRepository({FirebaseFirestore? firestore})
      : db = firestore ?? FirebaseFirestore.instance;

  /// Creates a new game with a **unique join code**.
  ///
  /// - [hostName] (optional): if provided, we seed the lobby's `players` with this name
  ///   so the host appears immediately in the Lobby UI.
  ///
  /// Steps (inside a Firestore transaction):
  ///  - Check `/codes/{CODE}` doesn't exist → code is free
  ///  - Create `/games/{gameId}` (auto-id)
  ///  - Write `/codes/{CODE}` with { status: "reserved", gameId, createdAt }
  ///  - Write `/games/{gameId}` with { joinCode, status: "waiting", players, createdAt }
  ///
  /// On code collision, we *retry* with a fresh code (up to [maxAttempts]).
  Future<Game> createGame({String? hostName}) async {
    const maxAttempts = 10;

    // Try a handful of times in case of rare code collisions.
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      // 6-char uppercase A–Z and digits (excluding lookalikes): see JoinCode.
      final code = JoinCode.generate();

      try {
        // Run everything atomically so the code and game are always in sync.
        final game = await db.runTransaction<Game>((tx) async {
          // 1) Is this code already taken?
          final codeRef = FirestoreRefs.codeDoc(db, code);
          final codeSnap = await tx.get(codeRef);
          if (codeSnap.exists) {
            // Someone else reserved this code between generation and now.
            // Throw a known error so the outer loop will try a new code.
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'already-exists',
              message: 'Join code collision',
            );
          }

          // 2) Create the game document first to get a stable `gameId`.
          final gamesCol = FirestoreRefs.games(db);
          final newGameRef = gamesCol.doc();  // Firestore auto-id

          // 3) Reserve the code and link it to the game (so Join can look up gameId fast).
          tx.set(codeRef, {
            'status': 'reserved',
            'gameId': newGameRef.id,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // 4) Create the game itself. If hostName is provided, show the host in the lobby right away.
          tx.set(newGameRef, {
            'joinCode': code,
            'status': 'waiting',  // Only waiting lobbies can be joined.
            'createdAt': FieldValue.serverTimestamp(),
            'players': hostName == null ? <String>[] : <String>[hostName],
          });

          // 5) Build and return a local `Game` model for immediate UI use.
          //    Note: `createdAt` here uses local time; Firestore has the true server timestamp.
          return Game(
            id: newGameRef.id,
            joinCode: code,
            status: 'waiting',
            createdAt: DateTime.now(),
            players: hostName == null ? const [] : [hostName],
          );
        });

        return game;  // Success path.
      } on FirebaseException catch (e) {
        // Retry on known "code already exists" collisions.
        if (e.code == 'already-exists') {
          if (attempt == maxAttempts) rethrow;  // we tried; bubble up
          continue;  // try the loop again with a fresh code
        }
        // Other Firestore errors: bubble up immediately.
        rethrow;
      }
    }
    // Defensive: practically unreachable unless incredibly unlucky or Firestore is unhappy.
    throw StateError('Failed to create a unique join code after $maxAttempts attempts.');
  }
}
