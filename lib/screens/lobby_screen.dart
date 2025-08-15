// lib/screens/lobby_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/services/firestore_refs.dart';

class CreateGameLobbyScreen extends StatelessWidget {
  const CreateGameLobbyScreen({
    super.key,
    required this.gameId,
    required this.joinCode,
    required this.isHost, // <— controls Start Game visibility
    this.db,              // optional injection for tests
  });

  final String gameId;     // /games/{gameId}
  final String joinCode;   // e.g., A1B2C3
  final bool isHost;
  final FirebaseFirestore? db;

  FirebaseFirestore get _db => db ?? FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final gameDoc = FirestoreRefs.gameDoc(_db, gameId);

    return Scaffold(
      backgroundColor: const Color(0xFF3E2C8B),
      appBar: AppBar(
        title: const Text(
          "Game Lobby",
          style: TextStyle(
            color: Colors.yellowAccent,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF3E2C8B),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: gameDoc.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || !snap.data!.exists) {
              return const Center(
                child: Text('Game not found', style: TextStyle(color: Colors.white)),
              );
            }

            final data = snap.data!.data()!;
            final status = (data['status'] as String?) ?? 'waiting';
            final players = (data['players'] as List?)?.cast<String>() ?? const <String>[];

            return Column(
              children: [
                // Join code pill with copy
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC943),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        joinCode,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E2C8B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: joinCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Game code copied to clipboard!"),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: SvgPicture.asset(
                          'assets/icons/copy.svg',
                          width: 24,
                          height: 24,
                          color: const Color(0xFF3E2C8B),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Text('gameId: $gameId • status: $status', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),

                // Players panel (live)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC943),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: players.isEmpty
                        ? const Center(
                      child: Text(
                        'Waiting for players…',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E2C8B),
                        ),
                      ),
                    )
                        : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final name = players[index];
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              'assets/icons/person-circle.svg',
                              width: 50,
                              height: 50,
                              color: const Color(0xFF3E2C8B),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3E2C8B),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Start Game: host only, and only while waiting
                if (isHost)
                  ElevatedButton(
                    onPressed: status == 'waiting'
                        ? () async {
                      try {
                        await gameDoc.update({'status': 'active'});
                        // TODO: Navigate to the first in-game screen
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to start game: $e')),
                        );
                      }
                    }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    child: const Text("Start Game"),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
