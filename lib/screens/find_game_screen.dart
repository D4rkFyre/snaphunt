// lib/screens/find_game_screen.dart
import 'lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/services/join_code.dart';
import 'package:snaphunt/services/device_id.dart';
import 'package:snaphunt/repositories/game_repository.dart';
import 'package:snaphunt/widgets/game_nav_bar.dart';
import 'package:snaphunt/services/route_transitions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async' as async; // for async.Completer, Future, etc.

/// ---------------------------------------------------------------------------
/// JoinGameScreen (FindGame)
/// ---------------------------------------------------------------------------
/// Purpose
/// - Let a player enter a nickname and join code to enter an existing game.
///
/// Tutorial (first-time users)
/// - Highlights nickname → game code → "Find a Game" button.
/// ---------------------------------------------------------------------------
class JoinGameScreen extends StatefulWidget {
  const JoinGameScreen({super.key, this.db});

  final FirebaseFirestore? db;

  @override
  State<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<JoinGameScreen> {
  final TextEditingController _gameCodeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  late final FirebaseFirestore _db = widget.db ?? FirebaseFirestore.instance;
  late final GameRepository _repo = GameRepository(firestore: _db);

  bool _busy = false;
  String? _error;
  String? _deviceId;

  // Tutorial targets
  final _nickKey = GlobalKey();
  final _codeKey = GlobalKey();
  final _findKey = GlobalKey();
  _Coach? _coach;

  Future<void> _loadDeviceId() async {
    final id = await DeviceId.get();
    if (!mounted) return;
    setState(() => _deviceId = id);
  }

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeStartTutorial();
    });
  }

  Future<void> _maybeStartTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('join_tutorial_seen') ?? false;
    if (seen || !mounted) return;

    _coach ??= _Coach(context);
    await _coach!.start([
      _CoachStep(
        key: _nickKey,
        title: 'Your Nickname',
        text: 'Enter your display name. Others will see it in the lobby.',
      ),
      _CoachStep(
        key: _codeKey,
        title: 'Game Code',
        text: 'Ask your host for a 6-character join code and enter it here.',
      ),
      _CoachStep(
        key: _findKey,
        title: 'Find the Game',
        text: 'Tap this button to join the game lobby!',
      ),
    ]);

    await prefs.setBool('join_tutorial_seen', true);
  }

  @override
  void dispose() {
    _gameCodeController.dispose();
    _nameController.dispose();
    _coach?.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    FocusScope.of(context).unfocus();

    final rawCode = _gameCodeController.text.trim();
    final code = rawCode.toUpperCase();

    if (!JoinCode.isValid(code)) {
      setState(() => _error = 'Enter a valid 6-character code (A–Z, 2–9).');
      return;
    }

    final rawName = _nameController.text.trim();
    final playerName = rawName.isEmpty
        ? 'Player ${DateTime.now().millisecondsSinceEpoch % 10000}'
        : rawName;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final deviceId = _deviceId ?? await DeviceId.get();

      final (gameId, resolvedCode) = await _repo.joinGameByCode(
        code: code,
        deviceId: deviceId,
        nickname: playerName,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        slideFromRight(
          CreateGameLobbyScreen(
            gameId: gameId,
            joinCode: resolvedCode,
            isHost: false,
            playerId: deviceId,
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Nickname input ---
                const Text(
                  'Your Nickname',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _CoachTarget(
                  key: _nickKey,
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Enter nickname (e.g., PlayerTwo)',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF5D4BB2),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14.0, horizontal: 20.0),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(40),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(40),
                        borderSide:
                        const BorderSide(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // --- Game code input ---
                const Text(
                  'Game Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _CoachTarget(
                  key: _codeKey,
                  child: TextField(
                    controller: _gameCodeController,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _busy ? null : _join(),
                    decoration: InputDecoration(
                      hintText: 'Enter code',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF5D4BB2),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 18.0, horizontal: 20.0),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(40),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(40),
                        borderSide:
                        const BorderSide(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // --- Error and progress ---
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

                // --- Join button ---
                _CoachTarget(
                  key: _findKey,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _join,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 32),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text(
                      'Find a Game',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const GameNavBar(current: GameNavTab.none),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Tutorial helpers (copied from host_screen.dart)
/// ---------------------------------------------------------------------------

class _CoachTarget extends StatelessWidget {
  final Widget child;
  const _CoachTarget({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

class _CoachStep {
  final GlobalKey key;
  final String title;
  final String text;
  _CoachStep({required this.key, required this.title, required this.text});
}

class _Coach {
  final BuildContext root;
  OverlayEntry? _entry;
  _Coach(this.root);

  Future<void> start(List<_CoachStep> steps) async {
    for (var i = 0; i < steps.length; i++) {
      await _showStep(steps[i], i + 1, steps.length);
    }
  }

  Future<void> _showStep(_CoachStep step, int index, int total) async {
    final ctx = step.key.currentContext;
    if (ctx == null) return;
    final rb = ctx.findRenderObject() as RenderBox?;
    if (rb == null || !rb.attached) return;
    final size = rb.size;
    final offset = rb.localToGlobal(Offset.zero);
    final completer = async.Completer<void>();

    _entry = OverlayEntry(
      builder: (context) {
        final media = MediaQuery.of(context);
        final spaceBelow = media.size.height - (offset.dy + size.height);
        final tooltipAbove = spaceBelow < 140;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {},
                child: Container(color: Colors.black54),
              ),
            ),
            Positioned(
              left: offset.dx - 6,
              top: offset.dy - 6,
              width: size.width + 12,
              height: size.height + 12,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border:
                    Border.all(color: Colors.yellowAccent, width: 3),
                  ),
                ),
              ),
            ),
            Positioned(
              left: offset.dx.clamp(16.0, media.size.width - 16.0),
              top: tooltipAbove
                  ? (offset.dy - 16 - 120)
                  .clamp(16.0, media.size.height - 136.0)
                  : (offset.dy + size.height + 12)
                  .clamp(16.0, media.size.height - 136.0),
              right: 16,
              child: _CoachCard(
                title: step.title,
                text: step.text,
                index: index,
                total: total,
                onNext: () {
                  _entry?.remove();
                  _entry = null;
                  completer.complete();
                },
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(root, rootOverlay: true).insert(_entry!);
    return completer.future;
  }

  void dispose() {
    _entry?.remove();
    _entry = null;
  }
}

class _CoachCard extends StatelessWidget {
  final String title;
  final String text;
  final int index;
  final int total;
  final VoidCallback onNext;

  const _CoachCard({
    required this.title,
    required this.text,
    required this.index,
    required this.total,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF241A5E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Colors.yellowAccent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(text, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('$index / $total',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.yellowAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: onNext,
                      child: Text(
                        index == total ? 'Done' : 'Next',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
