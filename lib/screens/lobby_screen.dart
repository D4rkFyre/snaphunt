// lib/screens/lobby_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/services/firestore_refs.dart';

class CreateGameLobbyScreen extends StatefulWidget {
  const CreateGameLobbyScreen({
    super.key,
    required this.gameId,
    required this.joinCode,
    required this.isHost,
    required this.playerId, // deviceId for the current device
    this.db,
  });

  final String gameId;
  final String joinCode;
  final bool isHost;
  final String playerId; // deviceId
  final FirebaseFirestore? db;

  @override
  State<CreateGameLobbyScreen> createState() => _CreateGameLobbyScreenState();
}

class _CreateGameLobbyScreenState extends State<CreateGameLobbyScreen> {
  late final FirebaseFirestore _db = widget.db ?? FirebaseFirestore.instance;

  Future<void> _startGame() async {
    final gameRef = FirestoreRefs.gameDoc(_db, widget.gameId);
    await gameRef.update({'status': 'started'});
  }

  Future<void> _leaveLobby() async {
    // For now, just pop back. (If you later want to remove the player from the array,
    // you can add a repo call that removes `{deviceId: X, nickname: Y}` by merging.)
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final gameDoc = FirestoreRefs.gameDoc(_db, widget.gameId);

    return Scaffold(
      backgroundColor: const Color(0xFF3E2C8B),
      appBar: AppBar(
        title: const Text(
          'Lobby',
          style: TextStyle(
            color: Colors.yellowAccent,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF3E2C8B),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: gameDoc.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Error: ${snap.error}',
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(
              child: Text(
                'Game not found.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final data = snap.data!.data() ?? <String, dynamic>{};
          final status = (data['status'] as String?) ?? 'waiting';
          final hostDeviceId = data['hostDeviceId'] as String?;

          // Parse players as list of { deviceId, nickname }
          final rawPlayers = (data['players'] as List?) ?? const [];
          final playerEntries = rawPlayers
              .whereType<Map>()
              .map((m) => (
          deviceId: (m['deviceId'] as String?) ?? '',
          nickname: (m['nickname'] as String?) ?? 'Player',
          ))
              .toList();

          // Determine host view either from flag or doc (extra safety)
          final isHostView = widget.isHost || (hostDeviceId == widget.playerId);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Join code card
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D4BB2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Game Code: ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SelectableText(
                        widget.joinCode,
                        style: const TextStyle(
                          color: Colors.yellowAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Status badge
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: status == 'waiting'
                        ? Colors.orangeAccent
                        : Colors.greenAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status == 'waiting' ? 'Waiting for players' : 'Started',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Players header
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Players (${playerEntries.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Players grid or "waiting"
                Expanded(
                  child: playerEntries.isEmpty
                      ? const Center(
                    child: Text(
                      'Waiting for players…',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFCFCCF1),
                      ),
                    ),
                  )
                      : GridView.builder(
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: playerEntries.length,
                    itemBuilder: (context, index) {
                      final entry = playerEntries[index];
                      final isMe = entry.deviceId == widget.playerId;
                      final display = isMe
                          ? '${entry.nickname} (you)'
                          : entry.nickname;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/person-circle.svg',
                            width: 50,
                            height: 50,
                            color: const Color(0xFFCFCCF1),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            display,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Host actions
                if (isHostView && status == 'waiting')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('Start Game'),
                    ),
                  ),

                // Leave button (all roles)
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _leaveLobby,
                  child: const Text(
                    'Leave Lobby',
                    style: TextStyle(
                      color: Colors.yellowAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
