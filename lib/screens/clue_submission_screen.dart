// lib/screens/clue_submission_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:snaphunt/widgets/progress_overlay.dart';

import 'package:snaphunt/repositories/game_repository.dart';
import 'package:snaphunt/models/clue_model.dart';
import 'package:snaphunt/services/firestore_refs.dart';
import 'package:snaphunt/screens/score_screen.dart';
import 'package:snaphunt/widgets/game_nav_bar.dart';

class ClueSubmissionScreen extends StatefulWidget {
  const ClueSubmissionScreen({
    super.key,
    required this.gameId,
    required this.playerId,
    this.repository,
  });

  final String gameId;
  final String playerId;
  final GameRepository? repository;

  @override
  State<ClueSubmissionScreen> createState() => _ClueSubmissionScreenState();
}

class _ClueSubmissionScreenState extends State<ClueSubmissionScreen> {
  final ImagePicker _picker = ImagePicker();
  late final GameRepository _repo;
  bool _busy = false;

  // Progress overlay controller
  final _progress = ProgressOverlayController();

  // Navigate-on-finish
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _gameSub;
  bool _navigatedToScores = false;

  // Track which clues we've already submitted
  final Set<String> _submitted = <String>{};
  final Map<String, String> _mySubmissionThumb = <String, String>{};

  // ---- Resubmit limits ----
  static const int _kMaxAttemptsPerClue = 3; // 1 initial + 2 retries
  final Map<String, int> _attempts = <String, int>{}; // clueId -> attempts so far

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? GameRepository();
    _prefetchMySubmissions();
    _checkFinishedOnce();

    _gameSub = FirestoreRefs.gameDoc(_repo.db, widget.gameId)
        .snapshots()
        .listen((snap) {
      final status = (snap.data()?['status'] as String?)?.trim() ?? 'waiting';
      if (status == 'finished') {
        _goToScoresOnce();
      }
    });
  }

  Future<bool> _confirmLeaveGame() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3E2C8B),
        title: const Text(
          'Leave Game?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to leave?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _prefetchMySubmissions() async {
    try {
      final q = await FirestoreRefs
          .submissions(_repo.db, widget.gameId)
          .where('playerId', isEqualTo: widget.playerId)
          .get();

      if (!context.mounted) return;

      final submitted = <String>{};
      final thumbs = <String, String>{};
      final attempts = <String, int>{};

      for (final doc in q.docs) {
        final data = doc.data();
        final clueId = data['clueId'] as String?;
        final imageUrl = data['imageUrl'] as String?;
        if (clueId != null) {
          submitted.add(clueId);
          attempts[clueId] = (attempts[clueId] ?? 0) + 1;
          if (imageUrl != null) thumbs[clueId] = imageUrl;
        }
      }

      setState(() {
        _submitted
          ..clear()
          ..addAll(submitted);
        _mySubmissionThumb
          ..clear()
          ..addAll(thumbs);
        _attempts
          ..clear()
          ..addAll(attempts);
      });
    } catch (_) {/* non-fatal */}
  }

  // ---------------------- Location helpers ----------------------
  Future<Position?> _getPlayerPosition() async {
    final servicesOn = await Geolocator.isLocationServiceEnabled();
    if (!servicesOn) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.')),
        );
      }
      return null;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return null;
      }
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      return pos;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
      return null;
    }
  }

  double _haversineMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadiusM = 6371000.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLng = (lng2 - lng1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }

  // ---------------------- Flow helpers ----------------------
  Future<void> _checkFinishedOnce() async {
    try {
      final snap = await FirestoreRefs.gameDoc(_repo.db, widget.gameId).get();
      if (!context.mounted) return;
      final status = (snap.data()?['status'] as String?)?.trim() ?? 'waiting';
      if (status == 'finished') {
        _goToScoresOnce();
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _gameSub?.cancel();
    super.dispose();
  }

  void _goToScoresOnce() {
    if (!mounted || _navigatedToScores) return;
    _navigatedToScores = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Game ended! Showing final scores…')),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ScoreScreen(gameId: widget.gameId),
        ),
            (route) => false,
      );
    });
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
              leading: const Icon(Icons.photo_camera, color: Colors.white),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
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
      final gameSnap = await FirestoreRefs.gameDoc(_repo.db, widget.gameId).get();
      if (!context.mounted) return;
      final data = gameSnap.data() ?? {};
      final fence = data['geofence'] as Map?;
      if (fence != null && fence['type'] == 'circle') {
        final center = fence['center'] as Map?;
        if (center != null) {
          centerLat = (center['lat'] as num?)?.toDouble();
          centerLng = (center['lng'] as num?)?.toDouble();
          radiusMeters = (fence['radiusMeters'] as num?)?.toDouble();
        }
      }
    } catch (_) {
      // ignore
    }

    if (centerLat != null && centerLng != null && radiusMeters != null) {
      final pos = await _getPlayerPosition();
      if (pos == null) return;

      // promote to local non-nullables (no !)
      final cLat = centerLat;
      final cLng = centerLng;
      final r = radiusMeters;

      final dist = _haversineMeters(
        lat1: pos.latitude,
        lng1: pos.longitude,
        lat2: cLat,
        lng2: cLng,
      );
      if (dist > r) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You are outside the game area (${dist.toStringAsFixed(0)}m away).')),
          );
        }
        return;
      }
    }
    // -----------------------------------------------

    // Start overlay & flag
    _progress.show();
    _progress.addStep('Uploading photo…');
    setState(() => _busy = true);

    try {
      // Upload image (assume non-nullables per your model)
      final submission = await _repo.uploadPlayerSubmission(
        gameId: widget.gameId,
        clueId: clueId,
        playerId: widget.playerId,
        imageFile: File(picked.path),
      );

      if (!context.mounted) return;

      _progress.addStep('Upload complete.');
      _progress.addStep('Submitting for scoring…');

      setState(() {
        _submitted.add(clueId);
        _mySubmissionThumb[clueId] = submission.imageUrl; // non-null

        // increment attempts
        final nextCount = (_attempts[clueId] ?? 0) + 1;
        _attempts[clueId] = nextCount;
      });

      // Kick off scoring (no score leaks here)
      try {
        await _repo.scoreSubmission(
          gameId: widget.gameId,
          submissionId: submission.id,     // non-null
          hostUrl: hostUrl,
          playerUrl: submission.imageUrl,  // non-null
        );

        if (context.mounted) {
          _progress.addStep('Scoring request accepted.');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Scoring failed: $e')),
          );
          _progress.addStep('Scoring failed. Please retry.');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _progress.hide();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (context.mounted) {
        setState(() => _busy = false);
        _progress.hide();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF3E2C8B);
    const accent = Color(0xFFFFC943);
    const accentDarker = Color(0xFFE0B23C); // slightly darker for resubmits

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // system already handled it

        // snapshot navigator before the async gap to keep the analyzer happy
        final navigator = Navigator.of(context);

        final leave = await _confirmLeaveGame();
        if (leave && context.mounted) {
          navigator.maybePop();
        }
      },
      child: Scaffold(
        backgroundColor: darkBg,
        endDrawer: Drawer(
          backgroundColor: darkBg,
          child: ListView(
            padding: EdgeInsets.zero,
            children: const [
              DrawerHeader(
                decoration: BoxDecoration(color: Color(0xFF2E1F66)),
                child: Text('Menu', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        appBar: AppBar(
          backgroundColor: darkBg,
          title: const Text('Submit Your Photos'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Scores are revealed at the end of the game.')),
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            StreamBuilder<List<Clue>>(
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
                      'No clues yet. Please wait for the host.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: clues.length,
                  itemBuilder: (context, i) {
                    final clue = clues[i];
                    final clueId = clue.id;        // non-nullable in your model
                    final hostUrl = clue.imageUrl; // non-nullable in your model
                    final myThumb = _mySubmissionThumb[clueId];

                    final heroPrompt = 'clue_prompt_$clueId';
                    final heroThumb = 'thumb_$clueId';

                    // attempts & button state
                    final attempts = _attempts[clueId] ?? 0;       // 0 until first upload
                    final hasSubmitted = attempts > 0;
                    final remainingRetries = hasSubmitted
                        ? (_kMaxAttemptsPerClue - attempts)
                        : 0;
                    final isOutOfRetries = hasSubmitted && remainingRetries <= 0;

                    return Card(
                      color: const Color(0xFF2E1F66),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: GestureDetector(
                                onTap: () => _openFullScreenNetwork(hostUrl, heroPrompt, title: 'Host Photo'),
                                child: Hero(
                                  tag: heroPrompt,
                                  child: Image.network(
                                    hostUrl,
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
                            const SizedBox(height: 8),
                            const Text(
                              'Match the above photo',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (myThumb != null)
                              Center(
                                child: GestureDetector(
                                  onTap: () => _openFullScreenNetwork(myThumb, heroThumb, title: 'Your Photo'),
                                  child: Hero(
                                    tag: heroThumb,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        height: 120,
                                        width: 120,
                                        child: Image.network(myThumb, fit: BoxFit.cover),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // Compare button (only when submission exists)
                            if (myThumb != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.center,
                                child: TextButton.icon(
                                  onPressed: () => _openCompare(hostUrl, myThumb, heroPrompt, heroThumb),
                                  icon: const Icon(Icons.compare),
                                  label: const Text('Compare Images'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _busy || isOutOfRetries
                                  ? null
                                  : () => _submit(clueId: clueId, hostUrl: hostUrl),
                              icon: const Icon(Icons.photo_camera),
                              label: Text(
                                hasSubmitted
                                    ? (isOutOfRetries
                                    ? 'No retries left'
                                    : 'Resubmit Photo (${remainingRetries} left)')
                                    : 'Submit Photo',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasSubmitted ? accentDarker : accent,
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            ProgressOverlay(controller: _progress, title: 'Submitting & Scoring'),
          ],
        ),
        // ✅ Bottom nav wired here (we are inside the State class → widget.gameId is valid)
        bottomNavigationBar: GameNavBar(
          current: GameNavTab.none,
          gameId: widget.gameId,
        ),
      ),
    );
  }

  void _openFullScreenNetwork(String url, String heroTag, {required String title}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenNetworkImage(
          url: url,
          heroTag: heroTag,
          title: title,
        ),
      ),
    );
  }

  void _openCompare(String hostUrl, String playerUrl, String hostHero, String playerHero) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CompareImagesScreen(
          hostUrl: hostUrl,
          playerUrl: playerUrl,
          hostHero: hostHero,
          playerHero: playerHero,
        ),
      ),
    );
  }
}

class _FullScreenNetworkImage extends StatelessWidget {
  const _FullScreenNetworkImage({
    required this.url,
    required this.heroTag,
    required this.title,
  });
  final String url;
  final String heroTag;
  final String title;

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      url,
      fit: BoxFit.contain,
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
    );

    return Scaffold(
      backgroundColor: const Color(0xFF3E2C8B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3E2C8B),
        title: Text(title),
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

class _CompareImagesScreen extends StatelessWidget {
  const _CompareImagesScreen({
    required this.hostUrl,
    required this.playerUrl,
    required this.hostHero,
    required this.playerHero,
  });

  final String hostUrl;
  final String playerUrl;
  final String hostHero;
  final String playerHero;

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF3E2C8B);

    Widget zoomable(String url, {String? hero}) {
      final img = Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('Image failed to load', style: TextStyle(color: Colors.white70)),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
      );
      final viewer = InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: img,
      );
      return hero == null ? viewer : Hero(tag: hero, child: viewer);
    }

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        title: const Text('Compare Images'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;

          if (isWide) {
            // Side-by-side on wider layouts
            return Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Host Photo', style: TextStyle(color: Colors.white70)),
                      ),
                      Expanded(child: Center(child: zoomable(hostUrl, hero: hostHero))),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: Colors.black26),
                Expanded(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Your Photo', style: TextStyle(color: Colors.white70)),
                      ),
                      Expanded(child: Center(child: zoomable(playerUrl, hero: playerHero))),
                    ],
                  ),
                ),
              ],
            );
          }

          // Stacked on phones / narrow
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: Text('Host', style: TextStyle(color: Colors.white70))),
              ),
              SizedBox(height: constraints.maxHeight * 0.45, child: zoomable(hostUrl, hero: hostHero)),
              const Divider(height: 16, thickness: 1, color: Colors.black26),
              const Center(child: Text('Your Submission', style: TextStyle(color: Colors.white70))),
              SizedBox(height: constraints.maxHeight * 0.45, child: zoomable(playerUrl, hero: playerHero)),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}
