// lib/services/firestore_refs.dart
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
  ///
  /// Usage:
  /// ```dart
  /// final gamesFolder = FirestoreRefs.games(db);
  /// final snapshot = await gamesFolder.get(); // list all games (dev only)
  /// ```
  static CollectionReference<Map<String, dynamic>> games(
    FirebaseFirestore db,
  ) => db.collection('games');

  // -------------------------------------------------------------------------
  // Documents (files)
  // -------------------------------------------------------------------------

  /// A single game file: `/games/{gameId}`
  ///
  /// Each game document currently has fields like:
  /// - `joinCode` (String)   e.g., "ABCD23"
  /// - `status`   (String)   "waiting" or "active"
  /// - `players`  (List<String>) nicknames shown in the lobby
  /// - `createdAt`(Timestamp)
  static DocumentReference<Map<String, dynamic>> gameDoc(
      FirebaseFirestore db,
      String gameId,
      ) => db.collection('games').doc(gameId);

  /// A single code file: `/codes/{CODE}`
  ///
  /// The file name *is* the join code itself (e.g., "ABCD23").
  /// We use this to quickly find which game a code belongs to.
  ///
  /// Current fields:
  /// - `status`    (String)   "reserved" (means this code is taken)
  /// - `gameId`    (String)   points to `/games/{gameId}`
  /// - `createdAt` (Timestamp)
  ///
  /// Note: We create the code file and the game file **together** in one
  /// transaction during hosting, so they always match.
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
