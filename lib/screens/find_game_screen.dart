// lib/screens/find_game_screen.dart
import 'lobby_screen.dart';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/services/join_code.dart';
import 'package:snaphunt/services/device_id.dart';
import 'package:snaphunt/repositories/game_repository.dart';
import 'package:snaphunt/widgets/game_nav_bar.dart';
import 'package:snaphunt/services/route_transitions.dart';


/// ---------------------------------------------------------------------------
/// JoinGameScreen
/// ---------------------------------------------------------------------------
/// Purpose
/// - Let a player enter a **nickname** and a **join code** to enter a lobby.
///
/// How it works (step-by-step)
/// 1) Player types nickname (optional; we default to "Player ####").
/// 2) Player types 6-char code (A–Z + 2–9). We validate the format locally.
/// 3) We call GameRepository.joinGameByCode(...) which:
///    - resolves `/codes/{CODE}` → gameId,
///    - ensures the game is joinable,
///    - enforces device-based role rules,
///    - writes `{deviceId, nickname}` and `playerDeviceIds`.
/// 4) Navigate to **Lobby** with `isHost: false`.
///
/// Error states we surface to the user:
/// - "Enter a valid 6-character code (A–Z, 2–9)."
/// - "No game found." (bad code or missing/invalid link)
/// - "Game already started." (status != "waiting")
/// - "You are the host on this device and cannot join as a player."
///
/// Testing
/// - `db` can be injected; tests pass a FakeFirebaseFirestore.
/// - UI exposes a spinner while joining and a small error message when needed.
/// ---------------------------------------------------------------------------
class JoinGameScreen extends StatefulWidget {
  const JoinGameScreen({super.key, this.db});

  /// Optional injection for tests; defaults to FirebaseFirestore.instance
  final FirebaseFirestore? db;

  @override
  State<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<JoinGameScreen> {
  // Text fields: code + nickname
  final TextEditingController _gameCodeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  // Firestore handle (real in app, fake in tests)
  late final FirebaseFirestore _db = widget.db ?? FirebaseFirestore.instance;

  // Repository (logic layer)
  late final GameRepository _repo = GameRepository(firestore: _db);

  // Simple UI state
  bool _busy = false;
  String? _error;

  // Device identity cache
  String? _deviceId;
  Future<void> _loadDeviceId() async {
    final id = await DeviceId.get();
    if (!mounted) return;
    setState(() => _deviceId = id);
  }

  @override
  void initState() {
    super.initState();
    _loadDeviceId(); // fetch and cache device identity
  }

  @override
  void dispose() {
    _gameCodeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Try to join a game by code using the repository (atomic + role-enforced).
  Future<void> _join() async {
    // Close the keyboard for a clean transition
    FocusScope.of(context).unfocus();

    // Normalize user input
    final rawCode = _gameCodeController.text.trim();
    final code = rawCode.toUpperCase();

    // Quick local format check before any network calls
    if (!JoinCode.isValid(code)) {
      setState(() => _error = 'Enter a valid 6-character code (A–Z, 2–9).');
      return;
    }

    // If player leaves nickname empty, generate a friendly placeholder
    final rawName = _nameController.text.trim();
    final playerName = rawName.isEmpty
        ? 'Player ${DateTime.now().millisecondsSinceEpoch % 10000}'
        : rawName;

    setState(() {
      _busy = true;   // disable button / show spinner
      _error = null;  // clear any previous error
    });

    try {
      // Ensure we have a device identity for this session
      final deviceId = _deviceId ?? await DeviceId.get();

      // Atomic join with role enforcement + persistence fields
      final (gameId, resolvedCode) = await _repo.joinGameByCode(
        code: code,
        deviceId: deviceId,
        nickname: playerName,
      );

      if (!mounted) return;  // user navigated away mid-join

      // Success → go to the live Lobby view as a player (no Start button)
      Navigator.of(context).push(
        slideFromRight(
          CreateGameLobbyScreen(
            gameId: gameId,
            joinCode: resolvedCode,
            isHost: false,      // player view → no Start Game button
            playerId: deviceId, // device identity is the true playerId
            db: _db,            // pass the same Firestore instance for consistency/tests
          ),
        ),
      );
    } catch (e) {
      // Show friendly messages for known StateErrors; otherwise show raw error
      setState(() {
        _error = e is StateError ? e.message : e.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3E2C8B),
      appBar: AppBar(
        title: const Text(
          "Join Game",
          style: TextStyle(
            color: Colors.yellowAccent,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF3E2C8B),
        centerTitle: true,
        elevation: 0,
      ),

      // Centered column: nickname → code → error/spinner → join button
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1) Nickname input
              const Text(
                'Your Nickname',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Enter nickname (e.g., PlayerTwo)',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF5D4BB2),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: const BorderSide(color: Colors.white, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2) Code input (validated on press)
              const Text(
                'Game Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _gameCodeController,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,  // helps user type uppercase
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _busy ? null : _join(),
                decoration: InputDecoration(
                  hintText: 'Enter code',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF5D4BB2),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: const BorderSide(color: Colors.white, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 3) Error and progress indicators
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: CircularProgressIndicator(),
                ),
              const SizedBox(height: 12),

              // 4) Join button → triggers _join()
              ElevatedButton(
                onPressed: _busy ? null : _join,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text(
                  'Find a Game',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: const GameNavBar(current: GameNavTab.none),
    );
  }
}