// lib/services/firestore_refs.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized Firestore collection/document references.
class FirestoreRefs {
  FirestoreRefs._(); // no instances (library-private)

  /// Top-level collection for games: `/games`
  static CollectionReference<Map<String, dynamic>> games(
    FirebaseFirestore db,
  ) => db.collection('games');

  /// Reservation/lock for join codes: `/codes/{code}`
  /// Doc ID == the join code itself (e.g., "A1B2C3").
  static DocumentReference<Map<String, dynamic>> codeDoc(
    FirebaseFirestore db,
    String code,
  ) => db.collection('codes').doc(code);
}
