// lib/models/clue_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Clue {
  final String id;
  final String imageUrl;
  final DateTime createdAt;
  final String createdBy;

  Clue({
    required this.id,
    required this.imageUrl,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() => {
    'imageUrl': imageUrl,
    'createdAt': Timestamp.fromDate(createdAt),
    'createdBy': createdBy,
  };

  factory Clue.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data()!;
    return Clue(
      id: snap.id,
      imageUrl: d['imageUrl'] as String,
      // Safely handle null createdAt (e.g. right after serverTimestamp write)
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdBy: d['createdBy'] as String,
    );
  }
}
