// lib/screens/lobby_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/services/firestore_refs.dart';
import 'clue_submission_screen.dart'; // <- add this

/// ---------------------------------------------------------------------------
/// CreateGameLobbyScreen
/// ---------------------------------------------------------------------------
/// Purpose
/// - Show a **live lobby** for a specific game: who’s joined and the game status.
/// - Lets the **host** start the game (players only watch).
/// - When host starts (status -> "active"), **players** auto-navigate to Clues.
/// ---------------------------------------------------------------------------
class CreateGameLobbyScreen extends StatefulWidget {
  const CreateGameLobbyScreen({
    super.key,
    required this.gameId,
    required this.joinCode,
    required this.isHost,
    this.db,
  });

  final String gameId;
  final String joinCode;
  final bool isHost;
  final FirebaseFirestore? db;

  @override
  State<CreateGameLobbyScreen> createState() => _CreateGameLobbyScreenState();
}

class _CreateGameLobbyScreenState extends State<CreateGameLobbyScreen> {
  bool _navigated = false; // ensure we navigate once for joiners

  FirebaseFirestore get _db => widget.db ?? FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final gameDoc = FirestoreRefs.gameDoc(_db, widget.gameId);

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

        // Live subscription: any change to /games/{gameId} re-renders this UI
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

            // -----------------------------------------------------------------
            // Player (not host) → auto-navigate to Clues when status == "active"
            // -----------------------------------------------------------------
            if (!widget.isHost && !_navigated && status == 'active') {
              _navigated = true; // prevent multiple pushes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const PhotoTasksScreen(),
                  ),
                );
              });
            }

            return Column(
              children: [
                // Join code with copy
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
                        widget.joinCode,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E2C8B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.joinCode));
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
                Text('gameId: ${widget.gameId} • status: $status',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),

                // Players grid
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
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
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

                // Host-only Start Game button
                if (widget.isHost)
                  ElevatedButton(
                    onPressed: status == 'waiting'
                        ? () async {
                      try {
                        await gameDoc.update({'status': 'active'});
                        // Host stays on lobby or navigate host elsewhere if you prefer:
                        // Navigator.pushReplacement(... host view ...)
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
