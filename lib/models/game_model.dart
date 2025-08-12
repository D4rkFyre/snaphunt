// lib/models/game_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Game document stored in Firestore under `games/{gameId}`.
class Game {
  final String id; // Firestore doc id
  final String joinCode; // e.g., "A1B2C3"
  final String status; // "waiting" | "active" | "ended"
  final DateTime createdAt; // when the game was created
  final List<String> players; // list of player IDs

  Game({
    required this.id,
    required this.joinCode,
    required this.status,
    required this.createdAt,
    required this.players,
  });

  // Return a copy with specific fields changed
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

  /// Serialize for Firestore (no doc ID)
  Map<String, dynamic> toJson() {
    return {
      'joinCode': joinCode,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'players': players,
    };
  }

  /// Build a Game from a Firestore doc snapshot.
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

  /// Construct from a map if game ID is known
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
