// lib/repositories/game_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/models/game_model.dart';
import 'package:snaphunt/services/firestore_refs.dart';
import 'package:snaphunt/services/join_code.dart';
import 'package:snaphunt/models/clue_model.dart';
import 'package:snaphunt/models/submission_model.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


class GameRepository {
  /// NOTE: Make these nullable so we don't touch Firebase singletons in tests
  /// unless a method actually needs them.
  final FirebaseFirestore? _db;
  final FirebaseStorage? _storage;

  GameRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? firebaseStorage,
  })  : _db = firestore,
        _storage = firebaseStorage;

  // Lazy getters (only resolve singletons if needed)
  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;
  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

  Future<Game> createGame({String? hostName}) async {
    const maxAttempts = 10;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final code = JoinCode.generate();

      try {
        final game = await db.runTransaction<Game>((tx) async {
          final codeRef = FirestoreRefs.codeDoc(db, code);
          final codeSnap = await tx.get(codeRef);
          if (codeSnap.exists) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'already-exists',
              message: 'Join code collision',
            );
          }

          final gamesCol = FirestoreRefs.games(db);
          final newGameRef = gamesCol.doc();

          tx.set(codeRef, {
            'status': 'reserved',
            'gameId': newGameRef.id,
            'createdAt': FieldValue.serverTimestamp(),
          });

          tx.set(newGameRef, {
            'joinCode': code,
            'status': 'waiting',
            'createdAt': FieldValue.serverTimestamp(),
            'players': hostName == null ? <String>[] : <String>[hostName],
          });

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

  /// Upload a clue image to Firebase Storage and write metadata to Firestore.
  Future<String> uploadClue({
    required String gameId,
    required File file,
    required String createdBy,
  }) async {
    final clueId = const Uuid().v4();
    final storageRef = storage.ref().child('games/$gameId/clues/$clueId.jpg');

    await storageRef.putFile(file);
    final downloadURL = await storageRef.getDownloadURL();

    await FirestoreRefs.clues(db, gameId).doc(clueId).set({
      'imageUrl': downloadURL,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    });

    return downloadURL;
  }

  /// Stream all clues for a given game, ordered by creation time.
  /// Note: createdAt is set via serverTimestamp() on write; initial nulls will settle.
  Stream<List<Clue>> streamClues(String gameId) {
    return FirestoreRefs.clues(db, gameId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((qs) => qs.docs.map((d) => Clue.fromSnapshot(d)).toList());
  }

  /// Upload a player's submission image and create a submission doc.
  /// Storage: games/{gameId}/submissions/{submissionId}.jpg
  /// Firestore: /games/{gameId}/submissions/{submissionId}
  Future<Submission> uploadPlayerSubmission({
    required String gameId,
    required String clueId,
    required String playerId, // deviceId or nickname
    required File imageFile,
  }) async {
    final submissionId = const Uuid().v4();

    // 1) Upload image to Storage
    final storageRef = storage.ref().child('games/$gameId/submissions/$submissionId.jpg');

    await storageRef.putFile(imageFile);
    final downloadURL = await storageRef.getDownloadURL();

    // 2) Write Firestore doc
    final docRef = FirestoreRefs.submissions(db, gameId).doc(submissionId);
    await docRef.set({
      'gameId': gameId,
      'clueId': clueId,
      'playerId': playerId,
      'imageUrl': downloadURL,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(), // server-side time
    });

    // Return a Submission; createdAt will be null until server fills it
    return Submission(
      id: submissionId,
      gameId: gameId,
      clueId: clueId,
      playerId: playerId,
      imageUrl: downloadURL,
      status: 'pending',
      createdAt: null,
    );
  }
  /// Calls the Firebase HTTPS Function to score a submission via Cloud Run scorer.
  /// The backend Function will update the submission doc with { score, status: "scored", components, diagnostics, scoredAt }.
  /// Throws an Exception on non-200 responses with a short body snippet for easier debugging.
  Future<void> scoreSubmission({
    required String gameId,
    required String submissionId,
    required String hostUrl,
    required String playerUrl,
  }) async {
    final uri = Uri.parse(
      'https://us-central1-snaphunt-d99b8.cloudfunctions.net/scoreSubmission',
    );

    final payload = <String, dynamic>{
      'gameId': gameId,
      'submissionId': submissionId,
      'hostUrl': hostUrl,
      'playerUrl': playerUrl,
    };

    http.Response resp;
    try {
      resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } on Exception catch (e) {
      // Network/transport error
      throw Exception('Failed to call scoreSubmission: $e');
    }

    if (resp.statusCode != 200) {
      final body = resp.body;
      final snippet = body.length > 240 ? '${body.substring(0, 240)}…' : body;
      throw Exception(
        'scoreSubmission failed (${resp.statusCode}): $snippet',
      );
    }
  }
}
