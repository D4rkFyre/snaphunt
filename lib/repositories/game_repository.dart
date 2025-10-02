// lib/repositories/game_repository.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:snaphunt/models/game_model.dart';
import 'package:snaphunt/services/firestore_refs.dart';
import 'package:snaphunt/services/join_code.dart';
import 'package:snaphunt/models/clue_model.dart';
import 'package:snaphunt/models/submission_model.dart';
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

  /// Player flow: join by code with (deviceId, nickname).
  /// Enforces: game exists, status == waiting, and host device cannot join as player.
  Future<(String gameId, String joinCode)> joinGameByCode({
    required String code,
    required String deviceId,
    required String nickname,
  }) async {
    final c = code.toUpperCase();

    return await db.runTransaction<(String, String)>((tx) async {
      // 1) code -> gameId
      final codeRef = FirestoreRefs.codeDoc(db, c);
      final codeSnap = await tx.get(codeRef);
      if (!codeSnap.exists) throw StateError('No game found.');
      final gameId = (codeSnap.data()!['gameId'] as String?) ?? '';
      if (gameId.isEmpty) throw StateError('No game found.');

      // 2) validate game + status
      final gameRef = FirestoreRefs.gameDoc(db, gameId);
      final gameSnap = await tx.get(gameRef);
      if (!gameSnap.exists) throw StateError('No game found.');

      final data = gameSnap.data()!;
      final statusStr =
          (data['status'] as String?) ?? GameStatus.waiting.asString;
      if (statusStr != GameStatus.waiting.asString) {
        throw StateError('Game already started.');
      }

      final hostDeviceId = data['hostDeviceId'] as String?;
      final playerDeviceIds =
          (data['playerDeviceIds'] as List?)?.whereType<String>().toSet() ??
              <String>{};

      // Role enforcement: host device can't join as player.
      if (hostDeviceId != null && hostDeviceId == deviceId) {
        throw StateError(
            'You are the host on this device and cannot join as a player.');
      }

      // 3) updates: add deviceId and ensure players[] has a display entry
      final updates = <String, dynamic>{};

      if (!playerDeviceIds.contains(deviceId)) {
        updates['playerDeviceIds'] = FieldValue.arrayUnion([deviceId]);
      }

      updates['players'] = FieldValue.arrayUnion([
        {'deviceId': deviceId, 'nickname': nickname},
      ]);

      updates['roles.$deviceId'] = 'player';

      tx.update(gameRef, updates);
      return (gameId, c);
    });
  }

  /// Host flow: set host device (id + optional nickname), but only if not set or same device.
  Future<void> setHostDeviceId({
    required String gameId,
    required String hostDeviceId,
    String? hostNickname,
  }) async {
    final gameRef = FirestoreRefs.gameDoc(db, gameId);
    await db.runTransaction((tx) async {
      final snap = await tx.get(gameRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      final currentHost = data['hostDeviceId'] as String?;
      if (currentHost != null &&
          currentHost.isNotEmpty &&
          currentHost != hostDeviceId) {
        // Host already set to someone else; leave it alone.
        return;
      }

      final updates = <String, dynamic>{
        'hostDeviceId': hostDeviceId,
        // ensure arrays exist (arrayUnion with empty keeps them typed as arrays)
        'playerDeviceIds': FieldValue.arrayUnion(<String>[]),
        'players': FieldValue.arrayUnion(<Map<String, dynamic>>[]),

        'roles.$hostDeviceId': 'host',
      };

      if (hostNickname != null && hostNickname.isNotEmpty) {
        updates['players'] = FieldValue.arrayUnion([
          {'deviceId': hostDeviceId, 'nickname': hostNickname},
        ]);
      }

      tx.update(gameRef, updates);
    });
  }

  /// Host flow: create a game with a unique join code.
  /// Writes Firestore strings for status (waiting/started/finished).
  Future<Game> createGame({String? hostName}) async {
    const maxAttempts = 10;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final code = JoinCode.generate().toUpperCase();

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

          // Reserve the code -> gameId link
          tx.set(codeRef, {
            'status': 'reserved',
            'gameId': newGameRef.id,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Create the game doc
          tx.set(newGameRef, {
            'joinCode': code,
            'status': GameStatus.waiting.asString,
            'createdAt': FieldValue.serverTimestamp(),
            // Keep legacy-friendly players list (strings) so old UIs/tests still work.
            'players': hostName == null ? <String>[] : <String>[hostName],
            // hostDeviceId/playerDeviceIds will be set later (setHostDeviceId / joins)
          });

          // Return a strongly-typed Game for the UI layer
          return Game(
            id: newGameRef.id,
            joinCode: code,
            status: GameStatus.waiting,
            createdAt: Timestamp.now(), // local fallback until server writes
            players: hostName == null
                ? const <PlayerEntry>[]
                : [PlayerEntry(deviceId: "", nickname: hostName)],
          );
        });

        return game;
      } on FirebaseException catch (e) {
        if (e.code == 'already-exists') {
          if (attempt == maxAttempts) rethrow;
          continue; // retry with a new code
        }
        rethrow;
      }
    }

    throw StateError(
      'Failed to create a unique join code after $maxAttempts attempts.',
    );
  }

  /// Upload a clue image to Firebase Storage and write metadata to Firestore.
  /// Pass lat/lng to store a GeoPoint on the clue.
  Future<String> uploadClue({
    required String gameId,
    required File file,
    required String createdBy,
    double? lat,
    double? lng,
  }) async {
    final clueId = const Uuid().v4();
    final storageRef =
    storage.ref().child('games/$gameId/clues/$clueId.jpg');

    // Optional: attach metadata (handy for debugging in Storage)
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        if (lat != null && lng != null) 'lat': '$lat',
        if (lat != null && lng != null) 'lng': '$lng',
        'createdBy': createdBy,
        'gameId': gameId,
        'clueId': clueId,
      },
    );

    await storageRef.putFile(file, metadata);
    final downloadURL = await storageRef.getDownloadURL();

    final data = <String, dynamic>{
      'imageUrl': downloadURL,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      if (lat != null && lng != null) 'location': GeoPoint(lat, lng),
    };

    // debug
    // ignore: avoid_print
    print(
        "[uploadClue] gameId=$gameId clueId=$clueId lat=$lat lng=$lng willWriteLocation=${data.containsKey('location')}"
    );

    await FirestoreRefs.clues(db, gameId)
        .doc(clueId)
        .set(data, SetOptions(merge: true));

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

  // === Helpers for deterministic IDs ==================================

  /// Sanitize a string to be safe in Firestore doc IDs and Storage paths.
  String _safeIdPart(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');

  /// Deterministic submission ID per (playerId, clueId).
  String _submissionIdFor(String playerId, String clueId) =>
      '${_safeIdPart(playerId)}__${_safeIdPart(clueId)}';

  DateTime? _asDateTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _withCacheBust(String url) {
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Upload (or re-upload) a player's submission image to a **single** doc per
  /// (playerId, clueId). On retake, we overwrite the Storage object and update
  /// the same submission document, resetting scoring fields and setting
  /// `status: "pending"`. We also update `imageUrl` with a cache-busting query
  /// param so the UI refreshes immediately.
  Future<Submission> uploadPlayerSubmission({
    required String gameId,
    required String clueId,
    required String playerId, // deviceId or nickname
    required File imageFile,
  }) async {
    final submissionId = _submissionIdFor(playerId, clueId);
    final subRef = FirestoreRefs.submissionDoc(db, gameId, submissionId);

    // Upload to a deterministic path so only one blob exists per pair.
    final storageRef =
    storage.ref().child('games/$gameId/submissions/$submissionId.jpg');
    await storageRef.putFile(imageFile);
    final rawDownloadURL = await storageRef.getDownloadURL();
    final bustedURL = _withCacheBust(rawDownloadURL);

    await db.runTransaction((tx) async {
      final snap = await tx.get(subRef);
      if (snap.exists) {
        // RETAKE: overwrite fields, keep createdAt, set updatedAt, reset scoring.
        tx.update(subRef, {
          'imageUrl': bustedURL,
          'status': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
          // wipe stale scoring/diagnostics
          'score': FieldValue.delete(),
          'components': FieldValue.delete(),
          'diagnostics': FieldValue.delete(),
          'scoredAt': FieldValue.delete(),
        });
      } else {
        // FIRST SUBMISSION: set createdAt (and also updatedAt for convenience)
        tx.set(subRef, {
          'gameId': gameId,
          'clueId': clueId,
          'playerId': playerId,
          'imageUrl': bustedURL,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    // Return latest snapshot (reflecting upsert)
    final latest = await subRef.get();
    final m = latest.data() ?? {};
    return Submission(
      id: submissionId,
      gameId: gameId,
      clueId: clueId,
      playerId: playerId,
      imageUrl: (m['imageUrl'] as String?) ?? bustedURL,
      status: (m['status'] as String?) ?? 'pending',
      createdAt: _asDateTime(m['createdAt']),
      // (Optional) If your model has updatedAt, add it there too.
    );
  }

  /// Calls the Firebase HTTPS Function to score a submission via Cloud Run scorer.
  /// The backend Function will update the submission doc with:
  /// { score, status: "scored", components, diagnostics, scoredAt }.
  /// Throws an Exception on non-200 responses with a short body snippet.
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
      throw Exception('Failed to call scoreSubmission: $e');
    }

    if (resp.statusCode != 200) {
      final body = resp.body;
      final snippet = body.length > 240 ? '${body.substring(0, 240)}…' : body;
      throw Exception('scoreSubmission failed (${resp.statusCode}): $snippet');
    }
  }

  /// Store the computed game area on the game document (merge-safe).
  Future<void> setGameArea({
    required String gameId,
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
  }) {
    final gameRef = FirestoreRefs.gameDoc(db, gameId);
    final payload = {
      'centerLat': centerLat,
      'centerLng': centerLng,
      'radiusMeters': radiusMeters,
      'areaComputedAt': FieldValue.serverTimestamp(),
    };

    // debug
    // ignore: avoid_print
    print('[setGameArea] gameId=$gameId '
        'center=($centerLat,$centerLng) radiusMeters=$radiusMeters');

    return gameRef.set(payload, SetOptions(merge: true));
  }
}
