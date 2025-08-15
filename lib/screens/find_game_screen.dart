// lib/screens/find_game_screen.dart
import 'lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/services/firestore_refs.dart';
import 'package:snaphunt/services/join_code.dart';

class JoinGameScreen extends StatefulWidget {
  const JoinGameScreen({super.key, this.db});

  /// Optional injection for tests; defaults to FirebaseFirestore.instance
  final FirebaseFirestore? db;

  @override
  State<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<JoinGameScreen> {
  int _selectedIndex = 0;
  final TextEditingController _gameCodeController = TextEditingController();

  late final FirebaseFirestore _db = widget.db ?? FirebaseFirestore.instance;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _gameCodeController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  Future<void> _join() async {
    final raw = _gameCodeController.text.trim();
    final code = raw.toUpperCase();

    if (!JoinCode.isValid(code)) {
      setState(() => _error = 'Enter a valid 6-character code (A–Z, 2–9).');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // 1) Resolve code -> gameId
      final codeSnap = await FirestoreRefs.codeDoc(_db, code).get();
      if (!codeSnap.exists) {
        throw StateError('No game found.');
      }
      final codeData = codeSnap.data()!;
      final gameId = codeData['gameId'] as String?;
      if (gameId == null || gameId.isEmpty) {
        throw StateError('No game found.');
      }

      // 2) Fetch game doc and enforce status == 'waiting'
      final gameRef = FirestoreRefs.gameDoc(_db, gameId);
      final gameSnap = await gameRef.get();
      if (!gameSnap.exists) {
        throw StateError('No game found.');
      }
      final gameData = gameSnap.data()!;
      final status = (gameData['status'] as String?) ?? 'waiting';
      if (status != 'waiting') {
        throw StateError('Game already started.');
      }

      // 3) Add placeholder player (use a tiny suffix to avoid duplicates)
      final playerName = 'Player ${DateTime.now().millisecondsSinceEpoch % 10000}';
      await gameRef.update({
        'players': FieldValue.arrayUnion([playerName]),
      });

      if (!mounted) return;

      // 4) Navigate to lobby with real context
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreateGameLobbyScreen(
            gameId: gameId,
            joinCode: code,
            db: _db,
          ),
        ),
      );
    } catch (e) {
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Game Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _gameCodeController,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Enter code',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF5D4BB2),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 18.0,
                    horizontal: 20.0,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: const BorderSide(
                      color: Colors.white,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
              ElevatedButton(
                onPressed: _busy ? null : _join,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 32,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
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
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFFFFC943),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/book.svg',
              color: const Color(0xFF3E2C8B),
              width: 28,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/trophy-fill.svg',
              color: const Color(0xFF3E2C8B),
              width: 28,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/person-circle.svg',
              color: const Color(0xFF3E2C8B),
              width: 28,
            ),
            label: '',
          ),
        ],
      ),
    );
  }
}