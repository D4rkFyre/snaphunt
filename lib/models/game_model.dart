// lib/models/game_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// ---------------------------------------------------------------------------
/// Game (data model)
/// ---------------------------------------------------------------------------
/// Purpose
/// - In-memory representation of a Firestore document at `/games/{gameId}`.
/// - Keeps types consistent and conversions (to/from Firestore) in one place.
///
/// Fields (current milestone)
/// - `id`        : Firestore document id (auto-generated on create)
/// - `joinCode`  : 6-char human code (e.g., "ABCD23")
/// - `status`    : "waiting" | "active" | "ended"
/// - `createdAt` : When the game was created (DateTime in app)
/// - `players`   : List of **nicknames** currently in the lobby
///
/// Notes
/// - Firestore stores `createdAt` as a `Timestamp`. We convert to/from `DateTime`.
/// - Today `players` is a simple list of strings (nicknames). In the future,
///   we can upgrade this to richer player objects (uid + name) or a subcollection.
/// ---------------------------------------------------------------------------
class Game {
  final String id;            // Firestore doc id
  final String joinCode;      // e.g., "ABCD23"
  final String status;        // "waiting" | "active" | "ended"
  final DateTime createdAt;   // when the game was created
  final List<String> players; // lobby display names (nicknames)

  Game({
    required this.id,
    required this.joinCode,
    required this.status,
    required this.createdAt,
    required this.players,
  });

  /// Return a new Game with any subset of fields changed.
  Game copyWith({
    String? id,
    String? joinCode,
    String? status,
    DateTime? createdAt,
    List<String>? players,
  }) {
    return Game(
      id: id ?? this.id,
      joinCode: joinCode ?? this.joinCode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      players: players ?? this.players,
    );
  }

  /// Convert this model into a plain map for Firestore **writes**.
  ///
  /// Important:
  /// - When creating a game, we usually let Firestore set `createdAt`
  ///   with `FieldValue.serverTimestamp()` inside the repository/transaction.
  ///   This `toJson()` is handy for updates or non-transactional writes.
  Map<String, dynamic> toJson() {
    return {
      'joinCode': joinCode,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'players': players,
    };
  }

  /// Build a `Game` from a typed Firestore snapshot at `/games/{gameId}`.
  ///
  /// Assumes the document exists and has all expected fields.
  /// If you need extra safety (e.g., missing fields early in lifecycle),
  /// add null-checks/defaults here.
  factory Game.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data()!;
    return Game(
      id: snap.id,
      joinCode: d['joinCode'] as String,
      status: d['status'] as String,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      players: (d['players'] as List<dynamic>).cast<String>(),
    );
  }

  /// Construct from a `{...}` map when we already know the `id`.
  /// Useful with manual queries or when using `withConverter` in a custom way.
  factory Game.fromMap(String id, Map<String, dynamic> d) {
    return Game(
      id: id,
      joinCode: d['joinCode'] as String,
      status: d['status'] as String,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      players: (d['players'] as List<dynamic>).cast<String>(),
    );
  }
}
