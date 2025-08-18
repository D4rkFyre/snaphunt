// lib/screens/lobby_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/services/firestore_refs.dart';

/// ---------------------------------------------------------------------------
/// CreateGameLobbyScreen
/// ---------------------------------------------------------------------------
/// Purpose
/// - Show a **live lobby** for a specific game: who’s joined and the game status.
/// - Lets the **host** start the game (players only watch).
///
/// What this screen does
/// - Subscribes to `/games/{gameId}` in real time (StreamBuilder).
/// - Renders the **join code** (with a copy button).
/// - Shows a grid of **player nicknames** from `players[]`.
/// - If `isHost == true` and `status == "waiting"`, shows **Start Game**.
///
/// Inputs
/// - [gameId]   : the Firestore id for `/games/{gameId}`
/// - [joinCode] : the human code shown to players (e.g., "ABCD23")
/// - [isHost]   : host sees the Start button; players do not
/// - [db]       : optional Firestore instance (tests pass a Fake; app uses real)
///
/// Firestore actions
/// - READ (stream): `/games/{gameId}` → `status`, `players[]`
/// - WRITE (host): set `status: "active"` when starting the game
///
/// Navigation
/// - After Start, we will navigate to our first in-game screen (TODO marked below).
/// ---------------------------------------------------------------------------
class CreateGameLobbyScreen extends StatelessWidget {
  const CreateGameLobbyScreen({
    super.key,
    required this.gameId,
    required this.joinCode,
    required this.isHost,   // controls Start Game visibility
    this.db,                // optional injection for tests
  });

  final String gameId;     // e.g., "F2mJq7H..." (auto-id from game creation)
  final String joinCode;   // e.g., "ABCD23" (human-friendly)
  final bool isHost;
  final FirebaseFirestore? db;

  // Use the injected Firestore (tests) or the real one (app)
  FirebaseFirestore get _db => db ?? FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    // Document reference for this game
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

        // Live subscription: any change to /games/{gameId} re-renders this UI
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: gameDoc.snapshots(),
          builder: (context, snap) {
            // Loading state (first frame)
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Game deleted / not found
            if (!snap.hasData || !snap.data!.exists) {
              return const Center(
                child: Text('Game not found', style: TextStyle(color: Colors.white)),
              );
            }

            // Pull status + players from the snapshot
            final data = snap.data!.data()!;
            final status = (data['status'] as String?) ?? 'waiting';
            final players = (data['players'] as List?)?.cast<String>() ?? const <String>[];

            return Column(
              children: [
                // -----------------------------------------------------------------
                // Join code pill with a copy button
                // -----------------------------------------------------------------
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
                // Small status line: handy for debugging / verifying context
                Text('gameId: $gameId • status: $status', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),

                // -----------------------------------------------------------------
                // Players list (live)
                // - Shows “Waiting for players…” if none yet
                // - Otherwise renders a simple 3-column grid of nicknames
                // -----------------------------------------------------------------
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

                // -----------------------------------------------------------------
                // Start Game (host only)
                // - Only visible for the host
                // - Only enabled while status == "waiting"
                // - On press, flips status to "active"
                // -----------------------------------------------------------------
                if (isHost)
                  ElevatedButton(
                    onPressed: status == 'waiting'
                        ? () async {
                      try {
                        await gameDoc.update({'status': 'active'});
                        // TODO: Navigate to the first in-game screen, e.g.:
                        // Navigator.pushReplacement(context, MaterialPageRoute(
                        //   builder: (_) => InGameScreen(gameId: gameId, db: _db),
                        // ));
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
