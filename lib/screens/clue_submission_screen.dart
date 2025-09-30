// lib/screens/clue_submission_screen.dart
import 'dart:async'; // <-- NEW: for StreamSubscription
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:snaphunt/repositories/game_repository.dart';
import 'package:snaphunt/models/clue_model.dart';
import 'package:snaphunt/services/firestore_refs.dart';
import 'package:snaphunt/screens/score_screen.dart'; // <-- NEW

class ClueSubmissionScreen extends StatefulWidget {
  final String gameId;
  final String playerId; // deviceId or nickname
  final GameRepository? repository; // optional DI for tests

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
  bool _busy = false; // global uploading flag for UX

  // Navigate-on-finish
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _gameSub; // <-- NEW
  bool _navigatedToScores = false; // <-- NEW

  // Track what's been submitted this session (by clueId)
  final Set<String> _submitted = <String>{};
  // Store the player's uploaded image URL for thumbnail per clue
  final Map<String, String> _mySubmissionThumb = <String, String>{};

  Future<void> _prefetchMySubmissions() async {
    try {
      final q = await FirestoreRefs
          .submissions(_repo.db, widget.gameId)
          .where('playerId', isEqualTo: widget.playerId)
          .get();

      final submitted = <String>{};
      final thumbs = <String, String>{};

      for (final d in q.docs) {
        final data = d.data();
        final clueId = data['clueId'] as String?;
        final imageUrl = data['imageUrl'] as String?;
        if (clueId != null) {
          submitted.add(clueId);
          if (imageUrl != null) thumbs[clueId] = imageUrl;
        }
      }

      if (!mounted) return;
      setState(() {
        _submitted
          ..clear()
          ..addAll(submitted);
        _mySubmissionThumb
          ..clear()
          ..addAll(thumbs);
      });
    } catch (_) {
      // Non-fatal: repo-level uniqueness (next section) still blocks duplicates
    }
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? GameRepository();
    _prefetchMySubmissions();

    // --- NEW: Listen for game status changes and jump to ScoreScreen on finish ---
    _gameSub = FirestoreRefs.gameDoc(_repo.db, widget.gameId)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      final status = (data?['status'] as String?)?.trim() ?? 'waiting';
      if (status == 'finished') {
        _goToScoresOnce();
      }
    });
  }

  @override
  void dispose() {
    _gameSub?.cancel(); // <-- NEW
    super.dispose();
  }

  void _goToScoresOnce() { // <-- NEW
    if (!mounted || _navigatedToScores) return;
    _navigatedToScores = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => ScoreScreen(gameId: widget.gameId)),
            (route) => false,
      );
    });
  }

  // ---------------------- Location helpers ----------------------
  Future<Position?> _getPlayerPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  double _deg2rad(double d) => d * math.pi / 180.0;
  double _haversineMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const R = 6371000.0; // meters
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  // ---------------------- Submit flow ----------------------
  Future<void> _submit({
    required String clueId,
    required String hostUrl,
  }) async {
    // Pick source
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
              title:
              const Text('Take a Photo', style: TextStyle(color: Colors.white)),
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

    // --------- Game area check BEFORE upload ----------
    double? centerLat, centerLng, radiusMeters;
    try {
      final gameSnap =
      await FirestoreRefs.gameDoc(_repo.db, widget.gameId).get();
      final data = gameSnap.data();
      if (data != null) {
        if (data['centerLat'] != null &&
            data['centerLng'] != null &&
            data['radiusMeters'] != null) {
          centerLat = (data['centerLat'] as num).toDouble();
          centerLng = (data['centerLng'] as num).toDouble();
          radiusMeters = (data['radiusMeters'] as num).toDouble();
        }
      }
    } catch (_) {
      // If read fails, fall through to normal flow (missing data)
    }

    if (centerLat != null && centerLng != null && radiusMeters != null) {
      final playerPos = await _getPlayerPosition();
      if (playerPos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location unavailable — proceeding without area check.',
              ),
            ),
          );
        }
      } else {
        final userLat = playerPos.latitude;
        final userLng = playerPos.longitude;
        final dist = _haversineMeters(
          lat1: userLat,
          lng1: userLng,
          lat2: centerLat,
          lng2: centerLng,
        );
        if (dist > radiusMeters) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'You’re outside the game area (${dist.toStringAsFixed(0)}m > ${radiusMeters.toStringAsFixed(0)}m).'),
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return; // Do NOT upload
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Inside game area (~${dist.toStringAsFixed(0)}m to center)'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No game area set — normal submission.')),
        );
      }
    }

    // ---------- Upload flow ----------
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

      // Close uploading dialog
      Navigator.of(context).pop();

      // Mark this clue as submitted and store the image URL for thumbnail
      setState(() {
        _submitted.add(clueId);
        _mySubmissionThumb[clueId] = submission.imageUrl;
      });

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
          final snap = await FirestoreRefs
              .submissions(_repo.db, widget.gameId)
              .doc(submission.id)
              .get();
          final data = snap.data() as Map<String, dynamic>?;
          if (data != null && data['score'] != null) {
            score = (data['score'] as num).toDouble();
          }
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(score != null
                  ? 'Scored! ${score!.toStringAsFixed(0)}'
                  : 'Scored!'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Scoring failed: $e')),
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
        pageBuilder: (_, __, ___) => _FullScreenPhoto(networkUrl: url, heroTag: heroTag),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF3E2C8B);
    const accent = Color(0xFFFFC943);

    return Scaffold(
      backgroundColor: darkBg,
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
              final isSubmitted = _submitted.contains(clue.id);
              final submittedUrl = _mySubmissionThumb[clue.id];

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
                                  return const Center(
                                      child: CircularProgressIndicator());
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Submit button (disabled after submitted)
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (_busy || isSubmitted)
                              ? null
                              : () => _submit(
                            clueId: clue.id,
                            hostUrl: clue.imageUrl,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_busy || isSubmitted)
                                ? Colors.grey
                                : const Color(0xFFFFC943),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: Text(isSubmitted ? 'Submitted' : 'Submit'),
                        ),
                      ),

                      // Player's own uploaded thumbnail (expandable)
                      if (submittedUrl != null) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Your submission',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => _openFullScreenNetwork(
                                submittedUrl, 'submission-${clue.id}'),
                            child: Hero(
                              tag: 'submission-${clue.id}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  submittedUrl,
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    width: 140,
                                    height: 140,
                                    child: Center(
                                      child: Text(
                                        'Preview failed',
                                        style:
                                        TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
