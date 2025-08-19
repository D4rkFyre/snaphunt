import 'dart:io';

import 'lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snaphunt/models/game_model.dart';
import 'package:snaphunt/repositories/game_repository.dart';

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

  late final FirebaseFirestore _db =
      widget._db ?? FirebaseFirestore.instance;

  late final GameRepository _repo =
      widget._repo ?? GameRepository(firestore: _db);

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCluePhotos() async {
    if (_busy) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF3E2C8B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Upload Clues (Photos)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Camera icon
                    IconButton(
                      icon: const Icon(Icons.camera_alt, size: 36, color: Colors.white),
                      onPressed: () async {
                        Navigator.pop(context);
                        final file = await _picker.pickImage(source: ImageSource.camera);
                        if (file != null) {
                          setState(() => _clueFiles.add(file));
                        }
                      },
                    ),
                    const SizedBox(width: 40),
                    // Gallery icon
                    IconButton(
                      icon: const Icon(Icons.photo_library, size: 36, color: Colors.white),
                      onPressed: () async {
                        Navigator.pop(context);
                        final files = await _picker.pickMultiImage();
                        if (files.isNotEmpty) {
                          setState(() => _clueFiles.addAll(files));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Camera', style: TextStyle(color: Colors.white70)),
                    SizedBox(width: 60),
                    Text('Library', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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

              Row(
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
