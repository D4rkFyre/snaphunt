import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snaphunt/screens/find_game_screen.dart';

Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
      Duration timeout = const Duration(seconds: 6),
    }) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 60));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

void main() {
  const deviceChannel = MethodChannel('snaphunt/device_id');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceChannel, (call) async {
      if (call.method == 'getDeviceId') return 'dev-join';
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceChannel, null);
  });

  testWidgets('Entering code for active game shows "Game already started."', (tester) async {
    final db = FakeFirebaseFirestore();

    await db.collection('codes').doc('ACTIVE1').set({
      'status': 'reserved',
      'gameId': 'gActive',
      'createdAt': Timestamp.now(),
    });

    await db.collection('games').doc('gActive').set({
      'joinCode': 'ACTIVE1',
      'status': 'active',
      'createdAt': Timestamp.now(),
      'players': <String>[],
    });

    await tester.pumpWidget(MaterialApp(home: JoinGameScreen(db: db)));
    await tester.pump(const Duration(milliseconds: 80));

    await tester.enterText(find.byType(TextField).at(0), 'PlayerA');
    await tester.enterText(find.byType(TextField).at(1), 'ACTIVE1');

    final joinBtn = find.widgetWithText(ElevatedButton, 'Find a Game');
    await tester.tap(joinBtn);

    // Let async state update and error render
    await tester.pump(const Duration(milliseconds: 150));
    await pumpUntilFound(tester, find.text('Game already started.'));

    expect(find.text('Game already started.'), findsOneWidget);
  });
}
