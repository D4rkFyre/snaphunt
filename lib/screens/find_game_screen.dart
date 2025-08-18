// lib/screens/find_game_screen.dart
import 'lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/services/firestore_refs.dart';
import 'package:snaphunt/services/join_code.dart';

/// ---------------------------------------------------------------------------
/// JoinGameScreen
/// ---------------------------------------------------------------------------
/// Purpose
/// - Let a player enter a **nickname** and a **join code** to enter a lobby.
///
/// How it works (step-by-step)
/// 1) Player types nickname (optional; we default to "Player ####").
/// 2) Player types 6-char code (A–Z + 2–9). We validate the format locally.
/// 3) We look up `/codes/{CODE}` to find `gameId`.
/// 4) We fetch `/games/{gameId}` and require `status == "waiting"`.
/// 5) We add the nickname to `/games/{gameId}.players` (arrayUnion).
/// 6) Navigate to **Lobby** with `isHost: false`.
///
/// Error states we surface to the user:
/// - "Enter a valid 6-character code (A–Z, 2–9)."
/// - "No game found." (bad code or missing/invalid link)
/// - "Game already started." (status != "waiting")
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
  // Decorative bottom nav index (unrelated to join logic)
  int _selectedIndex = 0;

  // Text fields: code + nickname
  final TextEditingController _gameCodeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  // Firestore handle (real in app, fake in tests)
  late final FirebaseFirestore _db = widget.db ?? FirebaseFirestore.instance;

  // Simple UI state
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _gameCodeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  /// Try to join a game by code.
  ///
  /// Validation:
  /// - Code must be 6 chars, uppercase A–Z and digits 2–9 (see JoinCode.isValid).
  ///
  /// Firestore reads/writes:
  /// - READ  `/codes/{CODE}`  → get `gameId`
  /// - READ  `/games/{gameId}`→ ensure `status == "waiting"`
  /// - WRITE `/games/{gameId}`→ `players: arrayUnion([nickname])`
  ///
  /// Navigation:
  /// - On success → push Lobby screen with `isHost: false`.
  Future<void> _join() async {
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
      // Step 1: code → gameId
      final codeSnap = await FirestoreRefs.codeDoc(_db, code).get();
      if (!codeSnap.exists) {
        // Either a bad code or not reserved/created yet
        throw StateError('No game found.');
      }
      final codeData = codeSnap.data()!;
      final gameId = codeData['gameId'] as String?;
      if (gameId == null || gameId.isEmpty) {
        // Defensive: if code doc exists but is missing the link
        throw StateError('No game found.');
      }

      // Step 2: ensure the game exists and is still joinable
      final gameRef = FirestoreRefs.gameDoc(_db, gameId);
      final gameSnap = await gameRef.get();
      if (!gameSnap.exists) {
        throw StateError('No game found.');
      }
      final status = (gameSnap.data()!['status'] as String?) ?? 'waiting';
      if (status != 'waiting') {
        // Host already started the game; block late joins
        throw StateError('Game already started.');
      }

      // Step 3: add this player’s nickname atomically
      // arrayUnion prevents dupes and avoids race conditions.
      await gameRef.update({
        'players': FieldValue.arrayUnion([playerName]),
      });

      if (!mounted) return;  // user navigated away mid-join

      // Step 4: success → go to the live Lobby view as a player (no Start button)
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreateGameLobbyScreen(
            gameId: gameId,
            joinCode: code,
            isHost: false,  // player view → no Start Game button
            db: _db,        // pass the same Firestore instance for consistency/tests
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
          "Snaphunt",
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
              // 1) Nickname input (stored in the game's players[] on success)
              const Text(
                'Your Nickname',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
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

      // Decorative nav (icons only)
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
