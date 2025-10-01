// lib/screens/lobby_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/services/firestore_refs.dart';
import 'package:snaphunt/models/game_model.dart'; // enum + parser
import 'clue_submission_screen.dart';
import 'host_live_submissions_screen.dart'; // <-- NEW: navigate host here

/// ---------------------------------------------------------------------------
/// CreateGameLobbyScreen
/// ---------------------------------------------------------------------------
/// Purpose
/// - Show a **live lobby** for a specific game: who’s joined and the game status.
/// - Lets the **host** start the game (players only watch).
/// - When host starts (status -> "started"), **players** auto-navigate to Clues.
///   (Legacy "active" also treated as started via GameStatusX.fromString)
/// - NEW: When status -> "started", **host** auto-navigates to HostLiveSubmissionsScreen.
/// ---------------------------------------------------------------------------
class CreateGameLobbyScreen extends StatefulWidget {
  const CreateGameLobbyScreen({
    super.key,
    required this.gameId,
    required this.joinCode,
    required this.isHost,
    required this.playerId,
    this.db,
  });

  final String gameId;
  final String joinCode;
  final bool isHost;
  final String playerId;
  final FirebaseFirestore? db;

  @override
  State<CreateGameLobbyScreen> createState() => _CreateGameLobbyScreenState();
}

class _CreateGameLobbyScreenState extends State<CreateGameLobbyScreen> {
  bool _navigated = false; // ensure we navigate once for both host & players
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
            final statusRaw = (data['status'] as String?) ?? 'waiting';
            final status = GameStatusX.fromString(statusRaw); // maps "active" -> started

            final hostDeviceId = (data['hostDeviceId'] as String?) ?? '';
            final Map<String, dynamic> roles =
                (data['roles'] as Map?)?.cast<String, dynamic>() ?? const {};

            // Players array supports legacy strings OR {deviceId,nickname}
            final rawPlayers = data['players'];
            final List<_DisplayPlayer> parsedPlayers = [];
            if (rawPlayers is List) {
              for (final e in rawPlayers) {
                if (e is String) {
                  // legacy string: we don't know deviceId; keep name
                  parsedPlayers.add(_DisplayPlayer(deviceId: '', name: e));
                } else if (e is Map<String, dynamic>) {
                  final deviceId = (e['deviceId'] as String?) ?? '';
                  final nickname = (e['nickname'] as String?) ?? '';
                  final display = nickname.isNotEmpty
                      ? nickname
                      : (deviceId.isNotEmpty ? deviceId : 'Player');
                  parsedPlayers.add(_DisplayPlayer(deviceId: deviceId, name: display));
                }
              }
            }

            // --- Remove legacy duplicate of the host (string-only entry) ---
            // Determine the host's display name from the device-backed entry.
            String? hostDisplayName;
            for (final p in parsedPlayers) {
              final isHostByDevice = hostDeviceId.isNotEmpty && p.deviceId == hostDeviceId;
              final isHostByRole = p.deviceId.isNotEmpty && roles[p.deviceId] == 'host';
              if (isHostByDevice || isHostByRole) {
                hostDisplayName = p.name;
                break;
              }
            }
            final List<_DisplayPlayer> parsedPlayersNoLegacyHostDup =
            (hostDisplayName == null)
                ? parsedPlayers
                : parsedPlayers.where((p) {
              // Drop the legacy string-only copy if it matches the host's name.
              final isLegacyHostCopy = p.deviceId.isEmpty && p.name == hostDisplayName;
              return !isLegacyHostCopy;
            }).toList();

            // De-duplicate by deviceId (or by name when deviceId missing), INCLUDING host.
            final Map<String, _DisplayPlayer> dedupPlayers = {};
            for (final p in parsedPlayersNoLegacyHostDup) {
              final key = p.deviceId.isNotEmpty ? 'd:${p.deviceId}' : 'n:${p.name}';
              dedupPlayers[key] = p;
            }
            final List<_DisplayPlayer> playersList =
            dedupPlayers.values.toList(growable: false);

            // -----------------------------------------------------------------
            // Auto-navigation based on role and status
            // -----------------------------------------------------------------
            // Players (not host) → to Clues when started
            if (!widget.isHost && !_navigated && status == GameStatus.started) {
              _navigated = true; // prevent multiple pushes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ClueSubmissionScreen(
                      gameId: widget.gameId,
                      playerId: widget.playerId,
                    ),
                  ),
                );
              });
            }

            // HOST → to HostLiveSubmissionsScreen when started
            if (widget.isHost && !_navigated && status == GameStatus.started) {
              _navigated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => HostLiveSubmissionsScreen(
                      gameId: widget.gameId,
                    ),
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
                          colorFilter: const ColorFilter.mode(Color(0xFF3E2C8B), BlendMode.srcIn),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Text('gameId: ${widget.gameId} • status: $statusRaw',
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
                    child: playersList.isEmpty
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
                      itemCount: playersList.length,
                      itemBuilder: (context, index) {
                        final p = playersList[index];
                        final isHostIcon = p.deviceId.isNotEmpty &&
                            ((hostDeviceId.isNotEmpty && p.deviceId == hostDeviceId) ||
                                (roles[p.deviceId] == 'host'));

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Circle outline that changes color for host
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  width: 3,
                                  // Host pops with a bright outline; players keep theme purple.
                                  color: isHostIcon
                                      ? Colors.white
                                      : const Color(0xFF3E2C8B),
                                ),
                                boxShadow: isHostIcon
                                    ? [
                                  // subtle glow so the host stands out a bit more
                                  BoxShadow(
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: SvgPicture.asset(
                                'assets/icons/person-circle.svg',
                                width: 50,
                                height: 50,
                                colorFilter: const ColorFilter.mode(
                                    Color(0xFF3E2C8B), BlendMode.srcIn),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Name
                            Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3E2C8B),
                              ),
                            ),
                            // Tiny HOST badge
                            if (isHostIcon)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3E2C8B),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'HOST',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                    onPressed: status == GameStatus.waiting
                        ? () async {
                      try {
                        // Write enum string consistently ("started")
                        await gameDoc.update({'status': GameStatus.started.asString});

                        // Navigate host immediately; stream will also flip to started.
                        if (!mounted) return;
                        if (_navigated) return;
                        _navigated = true;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => HostLiveSubmissionsScreen(
                              gameId: widget.gameId,
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      textStyle:
                      const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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

class _DisplayPlayer {
  final String deviceId;
  final String name;
  const _DisplayPlayer({required this.deviceId, required this.name});
}
