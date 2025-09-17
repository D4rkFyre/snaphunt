// lib/screens/clue_submission_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:snaphunt/repositories/game_repository.dart';
import 'package:snaphunt/models/clue_model.dart';
import 'package:snaphunt/services/firestore_refs.dart';

class ClueSubmissionScreen extends StatefulWidget {
  final String gameId;
  final String playerId;             // deviceId or nickname
  final GameRepository? repository;  // optional DI for tests

  const ClueSubmissionScreen({
    super.key,
    required this.gameId,
    required this.playerId,
    this.repository,
  });

  @override
  State<ClueSubmissionScreen> createState() => _ClueSubmissionScreenState();
}

class _ClueSubmissionScreenState extends State<ClueSubmissionScreen> {
  final ImagePicker _picker = ImagePicker();
  late final GameRepository _repo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? GameRepository();
  }

  Future<void> _submit({required String clueId, required String hostUrl}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF3E2C8B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            const Divider(height: 0, color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.white),
              title: const Text('Take a Photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (picked == null) return;

    _showUploadingDialog();
    setState(() => _busy = true);

    try {
      final submission = await _repo.uploadPlayerSubmission(
        gameId: widget.gameId,
        clueId: clueId,
        playerId: widget.playerId,
        imageFile: File(picked.path),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss uploading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submission uploaded!')),
      );
      // Begin scoring via HTTPS Function
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scoring…')),
        );
      }
      try {
        await _repo.scoreSubmission(
          gameId: widget.gameId,
          submissionId: submission.id,
          hostUrl: hostUrl,
          playerUrl: submission.imageUrl,
        );
        // Try to read score once from Firestore (optional, best-effort).
        double? score;
        try {
          final snap = await FirestoreRefs.submissions(_repo.db, widget.gameId)
              .doc(submission.id)
              .get();
          final data = snap.data() as Map<String, dynamic>?;
          if (data != null && data['score'] != null) {
            score = (data['score'] as num).toDouble();
          }
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(score != null ? 'Scored! ${score!.toStringAsFixed(0)}' : 'Scored!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scoring failed: $e'),
              action: SnackBarAction(
                label: 'RETRY',
                onPressed: () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Scoring…')),
                    );
                    await _repo.scoreSubmission(
                      gameId: widget.gameId,
                      submissionId: submission.id,
                      hostUrl: hostUrl,
                      playerUrl: submission.imageUrl,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Scored!')),
                      );
                    }
                  } catch (e2) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Scoring failed: $e2')),
                      );
                    }
                  }
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showUploadingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _UploadingDialog(),
    );
  }

  void _openFullScreenNetwork(String url, String heroTag) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            _FullScreenPhoto(networkUrl: url, heroTag: heroTag),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF3E2C8B); // solid dark background
    const accent = Color(0xFFFFC943); // your yellow accent

    return Scaffold(
      backgroundColor: darkBg,

      // Right-side drawer for profile/settings
      endDrawer: Drawer(
        backgroundColor: darkBg,
        child: ListView(
          padding: EdgeInsets.zero,
          children: const [
            DrawerHeader(
              decoration: BoxDecoration(color: accent),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.person, color: Colors.white),
              title: Text('Profile', style: TextStyle(color: Colors.white)),
            ),
            ListTile(
              leading: Icon(Icons.settings, color: Colors.white),
              title: Text('Settings', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),

      // Top app bar
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: const Text(
          'Clues',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.person, color: Colors.white),
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),

      // Live clues list
      body: StreamBuilder<List<Clue>>(
        stream: _repo.streamClues(widget.gameId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Error loading clues: ${snap.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          final clues = snap.data ?? const <Clue>[];
          if (clues.isEmpty) {
            return const Center(
              child: Text(
                'No clues yet. Waiting for host...',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: clues.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final clue = clues[index];
              final heroPrompt = 'prompt-${clue.id}';

              return Card(
                color: const Color(0xFF5D4BB2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Clue image (tap to expand)
                      GestureDetector(
                        onTap: () => _openFullScreenNetwork(clue.imageUrl, heroPrompt),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Hero(
                              tag: heroPrompt,
                              child: Image.network(
                                clue.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text(
                                    'Image failed to load',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(child: CircularProgressIndicator());
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Submit button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _busy ? null : () => _submit(clueId: clue.id, hostUrl: clue.imageUrl),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            _busy ? Colors.grey : const Color(0xFFFFC943),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: const Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Centered uploading popup
class _UploadingDialog extends StatelessWidget {
  const _UploadingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF3E2C8B),
      insetPadding: const EdgeInsets.symmetric(horizontal: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Uploading your photo....',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Full-screen image viewer (asset, file, or network) with pinch-to-zoom
class _FullScreenPhoto extends StatelessWidget {
  const _FullScreenPhoto({
    required this.heroTag,
    this.assetPath,
    this.filePath,
    this.networkUrl,
  }) : assert(assetPath != null || filePath != null || networkUrl != null,
  'Provide an image source');

  final String heroTag;
  final String? assetPath;
  final String? filePath;
  final String? networkUrl;

  @override
  Widget build(BuildContext context) {
    final Widget image = assetPath != null
        ? Image.asset(assetPath!, fit: BoxFit.contain)
        : filePath != null
        ? Image.file(File(filePath!), fit: BoxFit.contain)
        : Image.network(networkUrl!, fit: BoxFit.contain);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: image,
          ),
        ),
      ),
    );
  }
}