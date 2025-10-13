import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snaphunt/screens/find_game_screen.dart';
import 'package:snaphunt/screens/lobby_screen.dart';

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

  testWidgets('Valid code joins waiting game and navigates to Lobby', (tester) async {
    final db = FakeFirebaseFirestore();

    await db.collection('codes').doc('ZZZZZZ').set({
      'status': 'reserved',
      'gameId': 'game42',
      'createdAt': Timestamp.now(),
    });

    await db.collection('games').doc('game42').set({
      'joinCode': 'ZZZZZZ',
      'status': 'waiting',
      'createdAt': Timestamp.now(),
      'players': <String>[],
    });

    await tester.pumpWidget(MaterialApp(home: JoinGameScreen(db: db)));
    await tester.pump(const Duration(milliseconds: 80));

    await tester.enterText(find.byType(TextField).at(0), 'PlayerZed');
    await tester.enterText(find.byType(TextField).at(1), 'ZZZZZZ');

    final joinBtn = find.widgetWithText(ElevatedButton, 'Find a Game');
    await tester.tap(joinBtn);

    // Give async navigation time to occur
    await tester.pump(const Duration(milliseconds: 120));
    await pumpUntilFound(tester, find.byType(CreateGameLobbyScreen));

    expect(find.byType(CreateGameLobbyScreen), findsOneWidget);
  });
}
