// lib/screens/host_screen.dart
import 'lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/models/game_model.dart';
import 'package:snaphunt/repositories/game_repository.dart';

/// ---------------------------------------------------------------------------
/// HostGameScreen
/// ---------------------------------------------------------------------------
/// Purpose
/// - Let a user act as the **host**: enter a nickname, create a game,
///   and jump to the lobby showing a join code.
///
/// What this screen does (end-to-end)
/// 1) Collects a host nickname (defaults to "Host" if empty)
/// 2) Calls `GameRepository.createGame(hostName: ...)`
///    - Internally generates a unique join code
///    - Atomically creates:
///        /codes/{CODE}  → { status: "reserved", gameId, createdAt }
///        /games/{gameId}→ { joinCode: CODE, status: "waiting", players: [hostName] }
/// 3) Navigates to the **Lobby** with:
///    - `gameId` (for live stream of the doc)
///    - `joinCode` (display & copy)
///    - `isHost: true` (enables the Start Game button)
///
/// Notes
/// - This widget supports **dependency injection** (DI) for tests via optional
///   `repo` and `db` params. In production, it falls back to real Firebase.
/// ---------------------------------------------------------------------------
class HostGameScreen extends StatefulWidget {
  const HostGameScreen({
    super.key,
    GameRepository? repo,
    FirebaseFirestore? db,
  })  : _repo = repo,
        _db = db;

  /// Optional DI for tests: if provided, the state will use these.
  final GameRepository? _repo;
  final FirebaseFirestore? _db;

  @override
  State<HostGameScreen> createState() => _HostGameScreenState();
}

class _HostGameScreenState extends State<HostGameScreen> {
  // Bottom nav index (purely UI; doesn’t affect hosting flow)
  int _selectedIndex = 0;

  // Simple UI state for button/spinner/error
  bool _busy = false;
  String? _error;

  // Text field controller for the host’s nickname
  final _nameCtrl = TextEditingController();

  // Firestore instance used by this screen (real in app, fake in tests)
  late final FirebaseFirestore _db =
      widget._db ?? FirebaseFirestore.instance;

  // Repository wrapping all “create game” logic/transaction
  late final GameRepository _repo =
      widget._repo ?? GameRepository(firestore: _db);

  @override
  void dispose() {
    // Always dispose controllers to avoid memory leaks
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Create a new game and navigate to the lobby.
  ///
  /// UX:
  /// - Disables the button while running (spinner)
  /// - Shows any error message below the field
  ///
  /// Data side:
  /// - Seeds the host nickname into `/games/{gameId}.players` if provided
  /// - Returns a `Game` model with `id` and `joinCode` we use for navigation
  Future<void> _createGame() async {
    final raw = _nameCtrl.text.trim();
    final hostName = raw.isEmpty ? 'Host' : raw;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Ask the repository to do the atomic code+game creation.
      final Game game = await _repo.createGame(hostName: hostName);

      // If the user navigated away mid-call, don’t try to push a new route.
      if (!mounted) return;

      // Navigate to the Lobby with host controls enabled.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreateGameLobbyScreen(
            gameId: game.id,         // `/games/{gameId}` document id
            joinCode: game.joinCode, // displays in the yellow pill
            isHost: true,            // host-only Start Game button
            db: _db,                 // pass same db for tests / consistency
          ),
        ),
      );
    } catch (e) {
      // Surface any errors to the user (e.g., Firestore/network issues)
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Bottom nav tap handler (UI only)
  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App-wide purple background for visual consistency
      backgroundColor: const Color(0xFF3E2C8B),

      appBar: AppBar(
        title: const Text(
          "Host Game",
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

      // Centered column: nickname input → spinner/error → Create Game button
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1) Host nickname input (used to seed the lobby)
              const Text(
                'Your Nickname',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Enter nickname (e.g., Host)',
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

              // 2) Error message (if any) and progress spinner
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: CircularProgressIndicator(),
                ),

              // 3) Create Game call-to-action (disabled while busy)
              ElevatedButton(
                onPressed: _busy ? null : _createGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                child: const Text("Create Game"),
              ),
            ],
          ),
        ),
      ),

      // Decorative bottom nav (Host/Join/Profile icons)
      // Note: this sample doesn’t navigate tabs here; HomeScreen manages tabs.
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFFFFC943),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: SvgPicture.asset('assets/icons/book.svg', color: const Color(0xFF3E2C8B), width: 28),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset('assets/icons/trophy-fill.svg', color: const Color(0xFF3E2C8B), width: 28),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset('assets/icons/person-circle.svg', color: const Color(0xFF3E2C8B), width: 28),
            label: '',
          ),
        ],
      ),
    );
  }
}
