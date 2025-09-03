import 'dart:io';

import 'lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/models/game_model.dart';
import 'package:snaphunt/repositories/game_repository.dart';

// One-time tutorial memory
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async' as async; // for async.Completer, Future, etc.

class HostGameScreen extends StatefulWidget {
  const HostGameScreen({
    super.key,
    GameRepository? repo,
    FirebaseFirestore? db,
  })  : _repo = repo,
        _db = db;

  final GameRepository? _repo;
  final FirebaseFirestore? _db;

  @override
  State<HostGameScreen> createState() => _HostGameScreenState();
}

class _HostGameScreenState extends State<HostGameScreen> {
  int _selectedIndex = 0;
  bool _busy = false;
  String? _error;

  final _nameCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _clueFiles = [];

  // Tutorial targets
  final _nickKey = GlobalKey();
  final _photoRowKey = GlobalKey();
  final _createKey = GlobalKey();

  late final FirebaseFirestore _db =
      widget._db ?? FirebaseFirestore.instance;

  late final GameRepository _repo =
      widget._repo ?? GameRepository(firestore: _db);

  // Simple tutorial controller
  _Coach? _coach;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTutorial());
  }

  Future<void> _maybeStartTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('host_tutorial_seen') ?? false;
    if (seen || !mounted) return;

    _coach ??= _Coach(context);
    await _coach!.start([
      _CoachStep(
        key: _nickKey,
        title: 'Your Nickname',
        text: 'Type your host name. Players will see it in the lobby.',
      ),
      _CoachStep(
        key: _photoRowKey,
        title: 'Add a Clue Photo',
        text: 'Attach one or more photos your players will hunt from.',
      ),
      _CoachStep(
        key: _createKey,
        title: 'Create Your Game',
        text: 'Generate a join code and go to the lobby. Start when players join.',
      ),
    ]);

    await prefs.setBool('host_tutorial_seen', true);
  }

  @override
  void dispose() {
    _coach?.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _createGame() async {
    final raw = _nameCtrl.text.trim();
    final hostName = raw.isEmpty ? 'Host' : raw;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final Game game = await _repo.createGame(hostName: hostName);

      for (final x in _clueFiles) {
        final file = File(x.path);
        await _repo.uploadClue(
          gameId: game.id,
          file: file,
          createdBy: hostName,
        );
      }

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreateGameLobbyScreen(
            gameId: game.id,
            joinCode: game.joinCode,
            isHost: true,
            db: _db,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your Nickname',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // STEP 1 target
              _CoachTarget(
                key: _nickKey,
                child: TextField(
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
              ),

              const SizedBox(height: 16),
              const SizedBox(height: 24),

              const Text(
                'Upload Clues (Photos)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // STEP 2 target
              _CoachTarget(
                key: _photoRowKey,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.camera_alt, size: 28, color: Colors.white),
                      onPressed: _busy
                          ? null
                          : () async {
                        final file = await _picker.pickImage(source: ImageSource.camera);
                        if (file != null) {
                          setState(() => _clueFiles.add(file));
                        }
                      },
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(Icons.photo_library, size: 28, color: Colors.white),
                      onPressed: _busy
                          ? null
                          : () async {
                        final files = await _picker.pickMultiImage();
                        if (files.isNotEmpty) {
                          setState(() => _clueFiles.addAll(files));
                        }
                      },
                    ),
                  ],
                ),
              ),

              if (_clueFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Selected Clues',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() => _clueFiles.clear()),
                      child: const Text("Clear All", style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < _clueFiles.length; i++)
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_clueFiles[i].path),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _clueFiles.removeAt(i)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black87,
                              child: Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 8),
              const SizedBox(height: 24),

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

              // STEP 3 target
              _CoachTarget(
                key: _createKey,
                child: ElevatedButton(
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

/// Wraps a target so it’s easy to measure its rect on screen
class _CoachTarget extends StatelessWidget {
  final Widget child;
  const _CoachTarget({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

/// One coach step config
class _CoachStep {
  final GlobalKey key;
  final String title;
  final String text;
  _CoachStep({required this.key, required this.title, required this.text});
}

/// Very small overlay-based coach marks system
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
    // find rect for the target
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
        // place tooltip under/over the target depending on space
        final spaceBelow = media.size.height - (offset.dy + size.height);
        final tooltipAbove = spaceBelow < 140;

        return Stack(
          children: [
            // dim background
            Positioned.fill(
              child: GestureDetector(
                onTap: () {}, // absorb taps
                child: Container(color: Colors.black54),
              ),
            ),
            // highlight box (no cutout to keep it simple & stable)
            Positioned(
              left: offset.dx - 6,
              top: offset.dy - 6,
              width: size.width + 12,
              height: size.height + 12,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.yellowAccent, width: 3),
                  ),
                ),
              ),
            ),
            // tooltip card
            Positioned(
              left: offset.dx.clamp(16.0, media.size.width - 16.0),
              top: tooltipAbove
                  ? (offset.dy - 16 - 120).clamp(16.0, media.size.height - 136.0)
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
                Text(title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Colors.yellowAccent,
                    )),
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
                        padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: onNext,
                      child: Text(index == total ? 'Done' : 'Next',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    )
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
