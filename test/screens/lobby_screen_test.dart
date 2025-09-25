import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snaphunt/screens/lobby_screen.dart';

Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
      Duration timeout = const Duration(seconds: 5),
    }) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  }
  throw TestFailure('Timed out waiting for condition.');
}

void main() {
  const deviceChannel = MethodChannel('snaphunt/device_id');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceChannel, (call) async {
      if (call.method == 'getDeviceId') return 'dev1';
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceChannel, null);
  });

  testWidgets('Host sees Start Game and can set status active', (tester) async {
    final db = FakeFirebaseFirestore();

    // Seed a waiting game with host + players in new schema.
    final gameRef = db.collection('games').doc('gameA');
    await gameRef.set({
      'joinCode': 'ABC123',
      'status': 'waiting',
      'createdAt': Timestamp.now(),
      'hostDeviceId': 'dev1',
      'playerDeviceIds': ['dev1'],
      'players': [
        {'deviceId': 'dev1', 'nickname': 'PlayerOne'},
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CreateGameLobbyScreen(
          gameId: 'gameA',
          joinCode: 'ABC123',
          isHost: true,
          playerId: 'dev1',
          db: db,
        ),
      ),
    );

    // Let the stream paint
    await tester.pump(const Duration(milliseconds: 150));

    // Start button present
    final startBtn = find.widgetWithText(ElevatedButton, 'Start Game');
    expect(startBtn, findsOneWidget);

    // (Don’t assert nickname text—UI may render chips/avatars) Just click start:
    await tester.tap(startBtn);
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Firestore status flips to active (poll a moment for async updates)
    await pumpUntil(tester, () async {
      final snap = await gameRef.get();
      return snap.data()?['status'] == 'active';
    } as bool Function());

    final snap = await gameRef.get();
    expect(snap.data()?['status'], 'active');
  });
}
