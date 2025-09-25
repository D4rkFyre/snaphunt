// lib/services/rejoin_service.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/screens/lobby_screen.dart';

class RejoinService {
  static const _activeStatuses = ['waiting', 'active'];

  static Future<void> promptRejoinIfApplicable({
    required BuildContext context,
    required String deviceId,
  }) async {
    final db = FirebaseFirestore.instance;

    // Look for a game where this device is host
    final hostSnap = await db
        .collection('games')
        .where('hostDeviceId', isEqualTo: deviceId)
        .where('status', whereIn: _activeStatuses)
        .limit(1)
        .get();

    DocumentSnapshot<Map<String, dynamic>>? gameDoc;

    if (hostSnap.docs.isNotEmpty) {
      gameDoc = hostSnap.docs.first;
    } else {
      // Or a game where this device is a player
      final playerSnap = await db
          .collection('games')
          .where('playerDeviceIds', arrayContains: deviceId)
          .where('status', whereIn: _activeStatuses)
          .limit(1)
          .get();
      if (playerSnap.docs.isNotEmpty) {
        gameDoc = playerSnap.docs.first;
      }
    }

    if (gameDoc == null) return;

    final data = gameDoc.data()!;
    final gameId = gameDoc.id;
    final joinCode = (data['joinCode'] as String?) ?? '';
    final isHost = data['hostDeviceId'] == deviceId;

    final shouldRejoin = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejoin Game?'),
        content: const Text('Do you want to rejoin your recent game?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );

    if (shouldRejoin == true && context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CreateGameLobbyScreen(
          gameId: gameId,
          joinCode: joinCode,
          isHost: isHost,
          playerId: deviceId, // <-- required by your LobbyScreen
        ),
      ));
    }
  }
}
