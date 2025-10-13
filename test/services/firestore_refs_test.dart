// test/services/firestore_refs_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/services/firestore_refs.dart';

/// ---------------------------------------------------------------------------
/// FirestoreRefs tests
/// ---------------------------------------------------------------------------
/// Purpose
/// - Sanity-check our helper functions that build typed Firestore references.
/// - Ensures we don’t accidentally change collection paths in one place
///   and silently break reads/writes elsewhere.
///
/// Why FakeFirebaseFirestore?
/// - It gives us typed references (`CollectionReference`, `DocumentReference`)
///   without making any network calls.
/// ---------------------------------------------------------------------------
void main() {
  test('games() points to /games', () {
    final db = FakeFirebaseFirestore();

    // When we ask for the top-level games collection...
    final col = FirestoreRefs.games(db);

    // …it should be a typed CollectionReference and point at 'games'
    expect(col, isA<CollectionReference<Map<String, dynamic>>>());
    expect(col.path, 'games');
  });

  test('codeDoc() points to /codes/{code}', () {
    final db = FakeFirebaseFirestore();

    // When we ask for a specific code doc…
    final doc = FirestoreRefs.codeDoc(db, 'A1B2C3');

    // …it should be a typed DocumentReference and point at 'codes/A1B2C3'
    expect(doc, isA<DocumentReference<Map<String, dynamic>>>());
    expect(doc.path, 'codes/A1B2C3');
  });
}
