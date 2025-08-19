// lib/repositories/game_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/models/game_model.dart';
import 'package:snaphunt/services/firestore_refs.dart';
import 'package:snaphunt/services/join_code.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class GameRepository {
  final FirebaseFirestore db;

  GameRepository({FirebaseFirestore? firestore})
      : db = firestore ?? FirebaseFirestore.instance;

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
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('games/$gameId/clues/$clueId.jpg');

    await storageRef.putFile(file);
    final downloadURL = await storageRef.getDownloadURL();

    await FirestoreRefs.clues(db, gameId).doc(clueId).set({
      'imageUrl': downloadURL,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    });

    return downloadURL;
  }
}
