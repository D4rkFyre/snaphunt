import 'package:cloud_firestore/cloud_firestore.dart';

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
///
/// Why this file helps:
/// - If we rename a path later, we fix it **here once**
/// - Easier to read and test (no scattered `"games"` or `"codes"` strings)
/// ---------------------------------------------------------------------------
class FirestoreRefs {
  FirestoreRefs._(); // Prevent instantiation (static-only utility)

  // -------------------------------------------------------------------------
  // Collections (folders)
  // -------------------------------------------------------------------------

  /// The "games" folder: `/games`
  static CollectionReference<Map<String, dynamic>> games(
      FirebaseFirestore db,
      ) => db.collection('games');

  /// The "clues" folder for a specific game: `/games/{gameId}/clues`
  static CollectionReference<Map<String, dynamic>> clues(
      FirebaseFirestore db,
      String gameId,
      ) => db.collection('games').doc(gameId).collection('clues');

  // -------------------------------------------------------------------------
  // Documents (files)
  // -------------------------------------------------------------------------

  /// A single game file: `/games/{gameId}`
  static DocumentReference<Map<String, dynamic>> gameDoc(
      FirebaseFirestore db,
      String gameId,
      ) => db.collection('games').doc(gameId);

  /// A single code file: `/codes/{CODE}`
  static DocumentReference<Map<String, dynamic>> codeDoc(
      FirebaseFirestore db,
      String code,
      ) => db.collection('codes').doc(code);

  // -------------------------------------------------------------------------
  // String path helpers (nice for logs or rules docs)
  // -------------------------------------------------------------------------

  /// Returns "games/{gameId}"
  static String gameDocPath(String gameId) => 'games/$gameId';

  /// Returns "codes/{code}"
  static String codeDocPath(String code) => 'codes/$code';
}
