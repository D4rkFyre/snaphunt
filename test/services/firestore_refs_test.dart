// test/services/firestore_refs_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaphunt/services/firestore_refs.dart';

void main() {
  test('games() points to /games', () {
    final db = FakeFirebaseFirestore();
    final col = FirestoreRefs.games(db);
    expect(col, isA<CollectionReference<Map<String, dynamic>>>());
    expect(col.path, 'games');
  });

  test('codeDoc() points to /codes/{code}', () {
    final db = FakeFirebaseFirestore();
    final doc = FirestoreRefs.codeDoc(db, 'A1B2C3');
    expect(doc, isA<DocumentReference<Map<String, dynamic>>>());
    expect(doc.path, 'codes/A1B2C3');
  });
}
