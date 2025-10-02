// lib/services/firestore_refs.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/models/clue_model.dart';
import 'package:snaphunt/models/submission_model.dart';

/// ---------------------------------------------------------------------------
/// FirestoreRefs
/// ---------------------------------------------------------------------------
/// Think of Firestore like cloud folders and files:
/// - A *collection* is a **folder**
/// - A *document* is a **file** inside a folder
///
/// This class keeps **all Firestore paths in one place**, so the rest of the
/// app can call small helper functions instead of hard-coding strings.
///
/// What we store right now:
/// - `/codes/{CODE}` → links a human join code (like "ABCD23") to a game id
/// - `/games/{gameId}` → the game itself (status, players, etc.)
/// - `/games/{gameId}/clues/{clueId}` → image clue uploaded by the host
/// - `/games/{gameId}/submissions/{submissionId}` → a player's submission
///
/// Why this file helps:
/// - If we rename a path later, we fix it **here once**
/// - Easier to read and test (no scattered `"games"` or `"codes"` strings)
/// ---------------------------------------------------------------------------
class FirestoreRefs {
  FirestoreRefs._(); // Prevent instantiation (static-only utility)

  // -------------------------------------------------------------------------
  // Stable submission id helpers
  // -------------------------------------------------------------------------

  /// Deterministic submission ID per (playerId, clueId).
  /// Keep it simple; just avoid '/' in ids.
  static String submissionIdFor(String playerId, String clueId) =>
      '${playerId}__${clueId}';

  /// Convenience wrapper returning the submission doc for (playerId, clueId).
  static DocumentReference<Map<String, dynamic>> submissionForPlayerClue(
      FirebaseFirestore db,
      String gameId,
      String playerId,
      String clueId,
      ) =>
      submissionDoc(db, gameId, submissionIdFor(playerId, clueId));

  /// NEW: Convenience accessor using (gameId, clueId, playerId) ordering.
  /// This keeps call sites readable when you naturally have clueId first.
  static DocumentReference<Map<String, dynamic>> submissionDocByPair(
      FirebaseFirestore db,
      String gameId,
      String clueId,
      String playerId,
      ) =>
      submissionDoc(db, gameId, submissionIdFor(playerId, clueId));

  // -------------------------------------------------------------------------
  // Collections (folders)
  // -------------------------------------------------------------------------

  /// The "games" folder: `/games`
  static CollectionReference<Map<String, dynamic>> games(
      FirebaseFirestore db,
      ) =>
      db.collection('games');

  /// The "clues" folder for a specific game: `/games/{gameId}/clues`
  static CollectionReference<Map<String, dynamic>> clues(
      FirebaseFirestore db,
      String gameId,
      ) =>
      db.collection('games').doc(gameId).collection('clues');

  /// The "submissions" folder: `/games/{gameId}/submissions`
  static CollectionReference<Map<String, dynamic>> submissions(
      FirebaseFirestore db,
      String gameId,
      ) =>
      db.collection('games').doc(gameId).collection('submissions');

  // -------------------------------------------------------------------------
  // Typed converters (for compile-time safety in reads/writes)
  // -------------------------------------------------------------------------

  static CollectionReference<Clue> cluesTyped(
      FirebaseFirestore db,
      String gameId,
      ) =>
      clues(db, gameId).withConverter<Clue>(
        fromFirestore: (doc, _) => Clue.fromSnapshot(doc),
        toFirestore: (clue, _) => clue.toJson(),
      );

  static CollectionReference<Submission> submissionsTyped(
      FirebaseFirestore db,
      String gameId,
      ) =>
      submissions(db, gameId).withConverter<Submission>(
        fromFirestore: (doc, _) => Submission.fromSnapshot(doc),
        toFirestore: (sub, _) => sub.toJson(),
      );

  /// `/games/{gameId}/clues/{clueId}` as DocumentReference<Clue>
  static DocumentReference<Clue> clueDocTyped(
      FirebaseFirestore db,
      String gameId,
      String clueId,
      ) =>
      clueDoc(db, gameId, clueId).withConverter<Clue>(
        fromFirestore: (doc, _) => Clue.fromSnapshot(doc),
        toFirestore: (clue, _) => clue.toJson(),
      );

  /// `/games/{gameId}/submissions/{submissionId}` as DocumentReference<Submission>
  static DocumentReference<Submission> submissionDocTyped(
      FirebaseFirestore db,
      String gameId,
      String submissionId,
      ) =>
      submissionDoc(db, gameId, submissionId).withConverter<Submission>(
        fromFirestore: (doc, _) => Submission.fromSnapshot(doc),
        toFirestore: (sub, _) => sub.toJson(),
      );

  /// NEW: typed helper using (gameId, clueId, playerId) ordering.
  static DocumentReference<Submission> submissionDocByPairTyped(
      FirebaseFirestore db,
      String gameId,
      String clueId,
      String playerId,
      ) =>
      submissionDocByPair(db, gameId, clueId, playerId).withConverter<Submission>(
        fromFirestore: (doc, _) => Submission.fromSnapshot(doc),
        toFirestore: (sub, _) => sub.toJson(),
      );

  // -------------------------------------------------------------------------
  // Documents (files)
  // -------------------------------------------------------------------------

  /// A single game file: `/games/{gameId}`
  static DocumentReference<Map<String, dynamic>> gameDoc(
      FirebaseFirestore db,
      String gameId,
      ) =>
      db.collection('games').doc(gameId);

  /// A single code file: `/codes/{CODE}`
  static DocumentReference<Map<String, dynamic>> codeDoc(
      FirebaseFirestore db,
      String code,
      ) =>
      db.collection('codes').doc(code);

  /// A single clue file: `/games/{gameId}/clues/{clueId}`
  static DocumentReference<Map<String, dynamic>> clueDoc(
      FirebaseFirestore db,
      String gameId,
      String clueId,
      ) =>
      db.collection('games').doc(gameId).collection('clues').doc(clueId);

  /// A single submission file: `/games/{gameId}/submissions/{submissionId}`
  static DocumentReference<Map<String, dynamic>> submissionDoc(
      FirebaseFirestore db,
      String gameId,
      String submissionId,
      ) =>
      db.collection('games').doc(gameId).collection('submissions').doc(submissionId);

  // -------------------------------------------------------------------------
  // String path helpers (nice for logs or rules docs)
  // -------------------------------------------------------------------------

  /// Returns "games/{gameId}"
  static String gameDocPath(String gameId) => 'games/$gameId';

  /// Returns "codes/{code}"
  static String codeDocPath(String code) => 'codes/$code';

  /// String helper: "games/{gameId}/submissions/{submissionId}"
  static String submissionDocPath(String gameId, String submissionId) =>
      'games/$gameId/submissions/$submissionId';

  /// Returns "games/{gameId}/clues/{clueId}"
  static String clueDocPath(String gameId, String clueId) =>
      'games/$gameId/clues/$clueId';
}
