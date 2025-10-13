// lib/models/submission_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Player submission of a photo for a given clue.
class Submission {
  final String id;
  final String gameId;
  final String clueId;
  final String playerId;     // deviceId or nickname
  final String imageUrl;
  final String status;       // "pending" | "scored" | "rejected"
  final DateTime? createdAt; // NULLABLE (serverTimestamp resolves later)

  // Optional fields for when you hook the scorer:
  final double? score;           // fused score

  Submission({
    required this.id,
    required this.gameId,
    required this.clueId,
    required this.playerId,
    required this.imageUrl,
    required this.status,
    required this.createdAt, // nullable
    this.score,
  });

  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'clueId': clueId,
    'playerId': playerId,
    'imageUrl': imageUrl,
    'status': status,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    if (score != null) 'score': score,
  };

  factory Submission.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data()!;
    return Submission(
      id: snap.id,
      gameId: d['gameId'] as String,
      clueId: d['clueId'] as String,
      playerId: d['playerId'] as String,
      imageUrl: d['imageUrl'] as String,
      status: d['status'] as String,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(), // tolerant of null
      score: (d['score'] as num?)?.toDouble(),
    );
  }
}
