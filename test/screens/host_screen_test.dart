import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snaphunt/models/game_model.dart';
import 'package:snaphunt/repositories/game_repository.dart';
import 'package:snaphunt/screens/host_screen.dart';
import 'package:snaphunt/screens/lobby_screen.dart';

/// A tiny fake repo that returns a canned Game and does nothing for uploads.
class _FakeRepo extends GameRepository {
  final FirebaseFirestore _db;
  _FakeRepo(this._db) : super(firestore: _db);

  @override
  Future<Game> createGame({String? hostName}) async {
    final gamesCol = _db.collection('games');
    final newDoc = gamesCol.doc('g-host');
    await newDoc.set({
      'joinCode': 'HST001',
      'status': 'waiting',
      'createdAt': Timestamp.now(),
      'players': <String>[],
    });
    return Game(
      id: 'g-host',
      joinCode: 'HST001',
      status: GameStatus.waiting, // <-- enum, not string
      createdAt: Timestamp.now(),
      players: const [],
      hostDeviceId: null,
      playerDeviceIds: const [],
    );
  }

  @override
  Future<void> setHostDeviceId({
    required String gameId,
    required String hostDeviceId,
    String? hostNickname,
  }) async {
    await _db.collection('games').doc(gameId).set({
      'hostDeviceId': hostDeviceId,
      'players': [
        if (hostNickname != null)
          {'deviceId': hostDeviceId, 'nickname': hostNickname}
      ],
    }, SetOptions(merge: true));
  }

  // No-op these calls in tests
  @override
  Future<String> uploadClue({
    required String gameId,
    required File file,
    required String createdBy,
    double? lat,
    double? lng,
  }) async {
    return 'https://example.com/fake.jpg';
  }
}

void main() {
  const deviceChannel = MethodChannel('snaphunt/device_id');

  setUpAll(() {
    // Stub DeviceId.get()
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceChannel, (call) async {
      if (call.method == 'getDeviceId') return 'host-device';
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceChannel, null);
  });

  testWidgets('HostGameScreen creates a game and navigates to Lobby', (tester) async {
    final db = FakeFirebaseFirestore();
    final repo = _FakeRepo(db);

    await tester.pumpWidget(
      MaterialApp(
        home: HostGameScreen(
          repo: repo,
          db: db,
          // Let us create without picking images in test
          requireCluesToCreate: false,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 80));

    // Tap "Create Game"
    final createBtn = find.widgetWithText(ElevatedButton, 'Create Game');
    expect(createBtn, findsOneWidget);
    await tester.tap(createBtn);

    // Let navigation occur
    await tester.pump(const Duration(milliseconds: 150));

    // Should navigate to Lobby
    expect(find.byType(CreateGameLobbyScreen), findsOneWidget);

    // Verify the game doc exists
    final snap = await db.collection('games').doc('g-host').get();
    expect(snap.exists, true);
    expect(snap.data()?['joinCode'], 'HST001');
  });
}
