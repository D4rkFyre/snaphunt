// lib/services/rejoin_service.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:snaphunt/models/game_model.dart';
import 'package:snaphunt/screens/lobby_screen.dart';

class RejoinService {
  RejoinService._();

  /// Accept enum-backed strings; keep 'active' for legacy docs.
  static final List<String> _activeStatusValues = <String>[
    GameStatus.waiting.asString,
    GameStatus.started.asString,
    'active', // legacy alias that GameStatusX maps to started
  ];

  // Brand colors pulled from the app
  static const _purple = Color(0xFF3E2C8B);
  static const _purpleAlt = Color(0xFF6C5DD3);
  static const _yellow = Color(0xFFFFC943);

  // Light dialog surface (pale yellow so text pops)
  static const _dialogBg = Color(0xFFFFF7E6);

  static Future<void> promptRejoinIfApplicable({
    required BuildContext context,
    required String deviceId,
  }) async {
    final db = FirebaseFirestore.instance;

    try {
      final hostSnap = await db
          .collection('games')
          .where('hostDeviceId', isEqualTo: deviceId)
          .where('status', whereIn: _activeStatusValues)
          .limit(10)
          .get();

      final playerSnap = await db
          .collection('games')
          .where('playerDeviceIds', arrayContains: deviceId)
          .where('status', whereIn: _activeStatusValues)
          .limit(10)
          .get();

      final candidates = <QueryDocumentSnapshot<Map<String, dynamic>>>[
        ...hostSnap.docs,
        ...playerSnap.docs,
      ];
      if (candidates.isEmpty) return;

      // Sort by recency (prefer updatedAt, fallback createdAt)
      candidates.sort((a, b) {
        final am = a.data();
        final bm = b.data();
        final at = (am['updatedAt'] ?? am['createdAt']);
        final bt = (bm['updatedAt'] ?? bm['createdAt']);
        if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
        return 0;
      });

      // Build options (may include same game twice — one per role)
      final options = <_RejoinOption>[];
      for (final doc in candidates) {
        final data = doc.data();
        final code = (data['joinCode'] as String?) ?? '';
        final statusRaw =
            (data['status'] as String?) ?? GameStatus.waiting.asString;
        final status = GameStatusX.fromString(statusRaw);
        final isHostRole = ((data['hostDeviceId'] as String?) ?? '') == deviceId;

        if (status != GameStatus.waiting && status != GameStatus.started) {
          continue;
        }

        options.add(_RejoinOption(
          gameId: doc.id,
          joinCode: code,
          isHost: isHostRole,
          statusRaw: statusRaw,
        ));
      }

      if (options.isEmpty) return;

      final pickedIdx = await showDialog<int>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: _dialogBg,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'Rejoin Game?',
              style: TextStyle(
                color: _purple,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Select a game/role below to hop back in, or Cancel to start/play a new game.',
                          style: TextStyle(fontSize: 13, color: _purple),
                        ),
                      ),
                    ),
                    for (int i = 0; i < options.length; i++) ...[
                      _optionButton(ctx, options[i], i),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _purple, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      );

      if (pickedIdx == null || pickedIdx < 0 || pickedIdx >= options.length) {
        return;
      }
      final chosen = options[pickedIdx];

      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreateGameLobbyScreen(
            gameId: chosen.gameId,
            joinCode: chosen.joinCode,
            isHost: chosen.isHost,
            playerId: deviceId,
          ),
        ),
      );
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print('[RejoinService] Firebase error: ${e.code} ${e.message}');
    } catch (e) {
      // ignore: avoid_print
      print('[RejoinService] Unexpected error: $e');
    }
  }

  // --- UI helpers ---

  static Widget _optionButton(BuildContext ctx, _RejoinOption opt, int idx) {
    final style = _roleStyle(opt.isHost);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(ctx, idx),
        style: ElevatedButton.styleFrom(
          backgroundColor: style.bg,
          foregroundColor: style.fg,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          elevation: 3,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: style.border ?? BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            Icon(opt.isHost ? Icons.star : Icons.person, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${opt.isHost ? "Host" : "Player"} • Code: ${opt.joinCode}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(children: [_statusPill(opt.statusRaw)]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  /// Role style (colors + optional border)
  static _RoleStyle _roleStyle(bool isHost) {
    if (isHost) {
      return const _RoleStyle(bg: _purpleAlt, fg: Colors.white, border: null);
    }
    // Player: yellow bg, purple text, purple border for separation
    return const _RoleStyle(
      bg: _yellow,
      fg: _purple,
      border: BorderSide(color: _purple, width: 1.2),
    );
  }

  static Widget _statusPill(String raw) {
    final status = GameStatusX.fromString(raw);
    final base = status == GameStatus.started ? Colors.green : Colors.orange;
    final label = status == GameStatus.started ? 'STARTED' : 'WAITING';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: base.withValues(alpha: 0.7), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: base.withValues(alpha: 0.95),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _RejoinOption {
  final String gameId;
  final String joinCode;
  final bool isHost;
  final String statusRaw;

  const _RejoinOption({
    required this.gameId,
    required this.joinCode,
    required this.isHost,
    required this.statusRaw,
  });
}

class _RoleStyle {
  final Color bg;
  final Color fg;
  final BorderSide? border;
  const _RoleStyle({required this.bg, required this.fg, this.border});
}
