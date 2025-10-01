// lib/screens/host_live_submissions_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:snaphunt/repositories/game_repository.dart';
import 'package:snaphunt/models/clue_model.dart';
import 'package:snaphunt/services/firestore_refs.dart';
import 'package:snaphunt/screens/score_screen.dart';

class HostLiveSubmissionsScreen extends StatefulWidget {
  final String gameId;
  final GameRepository? repository;

  const HostLiveSubmissionsScreen({
    super.key,
    required this.gameId,
    this.repository,
  });

  @override
  State<HostLiveSubmissionsScreen> createState() =>
      _HostLiveSubmissionsScreenState();
}

class _HostLiveSubmissionsScreenState extends State<HostLiveSubmissionsScreen> {
  late final GameRepository _repo;

  // Prevent duplicate navigations
  bool _navigatedToScores = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? GameRepository();
  }

  void _goToScoresOnce() {
    if (!mounted || _navigatedToScores) return;
    _navigatedToScores = true;
    // Post-frame so we don't navigate during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => ScoreScreen(gameId: widget.gameId)),
            (route) => false, // clear back stack
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF3E2C8B);
    const cardBg = Color(0xFF5D4BB2);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Player Submissions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreRefs.gameDoc(_repo.db, widget.gameId).snapshots(),
        builder: (context, gameSnap) {
          // ----------------- Build roster & detect host (schema-based) -----------------
          final List<_RosterEntry> roster = [];

          // Read game doc data safely
          String hostDeviceIdField = '';
          Map<String, dynamic> roles = const {};
          final rawPlayers = <dynamic>[];
          String statusRaw = 'waiting';

          if (gameSnap.hasData && gameSnap.data?.data() != null) {
            final data = gameSnap.data!.data()!;
            statusRaw = (data['status'] as String?)?.trim() ?? 'waiting';
            hostDeviceIdField = (data['hostDeviceId'] as String?)?.trim() ?? '';
            roles = (data['roles'] as Map?)?.cast<String, dynamic>() ?? const {};
            final rp = data['players'];
            if (rp is List) rawPlayers.addAll(rp);
          }

          // If the game is finished (whether by this host or not), leave this screen.
          if (statusRaw == 'finished') {
            _goToScoresOnce();
          }

          // Find any host-backed entry to learn the host's nickname (for legacy string dup removal)
          final hostNicknames = <String>{};
          for (final e in rawPlayers) {
            if (e is Map) {
              final m = Map<String, dynamic>.from(e);
              final did = (m['deviceId'] as String?)?.trim() ?? '';
              final nick = (m['nickname'] as String?)?.trim() ?? '';
              final isHost = (hostDeviceIdField.isNotEmpty && did == hostDeviceIdField) ||
                  (did.isNotEmpty && roles[did] == 'host');
              if (isHost && nick.isNotEmpty) hostNicknames.add(nick);
            }
          }

          // Build roster = every participant who is NOT the host
          final dedup = <String, _RosterEntry>{};
          for (final e in rawPlayers) {
            if (e is String) {
              final name = e.trim();
              if (name.isEmpty) continue;
              if (hostNicknames.contains(name)) continue; // drop legacy host copy
              dedup['n:$name'] = _RosterEntry(id: name, label: name);
            } else if (e is Map) {
              final m = Map<String, dynamic>.from(e);
              final did = (m['deviceId'] as String?)?.trim() ?? '';
              final nick = (m['nickname'] as String?)?.trim() ?? '';

              final isHost = (hostDeviceIdField.isNotEmpty && did == hostDeviceIdField) ||
                  (did.isNotEmpty && roles[did] == 'host');
              if (isHost) continue;

              final id = did.isNotEmpty ? did : (nick.isNotEmpty ? nick : '');
              if (id.isEmpty) continue;
              final label = nick.isNotEmpty ? nick : id;
              final key = did.isNotEmpty ? 'd:$did' : 'n:$label';
              dedup[key] = _RosterEntry(id: id, label: label);
            }
          }
          roster.addAll(dedup.values);

          // Simple host check for submissions (playerId == deviceId)
          bool _isHostId(String id) {
            if (id.isEmpty) return false;
            return hostDeviceIdField.isNotEmpty && id == hostDeviceIdField;
          }

          return StreamBuilder<List<Clue>>(
            stream: _repo.streamClues(widget.gameId),
            builder: (context, cluesSnap) {
              if (cluesSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (cluesSnap.hasError) {
                return Center(
                  child: Text(
                    'Error loading clues: ${cluesSnap.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }

              final clues = cluesSnap.data ?? const <Clue>[];
              if (clues.isEmpty) {
                return const Center(
                  child: Text(
                    'No host clues yet.',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirestoreRefs
                    .submissions(_repo.db, widget.gameId)
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, subsSnap) {
                  if (subsSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (subsSnap.hasError) {
                    return Center(
                      child: Text(
                        'Error loading submissions: ${subsSnap.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  // Map<clueId, Map<playerId, submissionData>>, skipping host submissions.
                  final Map<String, Map<String, Map<String, dynamic>>> byClueByPlayer = {};
                  for (final d in subsSnap.data?.docs ?? const []) {
                    final Map<String, dynamic> m = d.data();
                    final clueId = m['clueId'] as String?;
                    final playerId = (m['playerId'] as String?)?.trim() ?? '';
                    if (clueId == null || playerId.isEmpty) continue;
                    if (_isHostId(playerId)) continue; // ignore host
                    (byClueByPlayer[clueId] ??= {})[playerId] = {...m, 'id': d.id};
                  }

                  // ----- Completion logic for the End Game button -----
                  // 1) Every clue has at least one submission?
                  final allCluesHaveOne = clues.every(
                        (c) => (byClueByPlayer[c.id]?.isNotEmpty ?? false),
                  );

                  // 2) Have ALL (non-host) players submitted for EVERY clue?
                  bool everyoneSubmittedAll = false;
                  if (roster.isNotEmpty) {
                    everyoneSubmittedAll = clues.every((c) {
                      final count = byClueByPlayer[c.id]?.length ?? 0;
                      return count >= roster.length;
                    });
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: clues.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final clue = clues[index];
                            final clueSubs =
                                byClueByPlayer[clue.id] ?? const <String, Map>{};

                            // Merge roster with any submitters not in roster.
                            final merged = <String, _RosterEntry>{
                              for (final r in roster) r.id: r
                            };
                            for (final pid in clueSubs.keys) {
                              merged.putIfAbsent(
                                  pid, () => _RosterEntry(id: pid, label: pid));
                            }
                            final finalRoster = merged.values.toList(growable: false);

                            final submittedCount = clueSubs.length;
                            final totalCount = finalRoster.isNotEmpty
                                ? finalRoster.length
                                : submittedCount;

                            return Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Clue',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black26,
                                            borderRadius:
                                            BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '$submittedCount / $totalCount submitted',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: Image.network(
                                          clue.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                          const Center(
                                            child: Text(
                                              'Image failed to load',
                                              style: TextStyle(
                                                  color: Colors.white70),
                                            ),
                                          ),
                                          loadingBuilder:
                                              (context, child, progress) {
                                            if (progress == null) return child;
                                            return const Center(
                                                child:
                                                CircularProgressIndicator());
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    _PlayerGallery(
                                      roster: finalRoster,
                                      submissionsForClue:
                                      Map<String, Map<String, dynamic>>.from(
                                          clueSubs),
                                      heroPrefix: 'clue-${clue.id}',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // --------------------- End Game button ---------------------
                      SafeArea(
                        top: false,
                        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: allCluesHaveOne
                                ? () async {
                              // If not everyone submitted all clues, confirm.
                              if (!everyoneSubmittedAll) {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor:
                                    const Color(0xFF241A5E),
                                    title: const Text(
                                      'End Game?',
                                      style:
                                      TextStyle(color: Colors.white),
                                    ),
                                    content: const Text(
                                      'Are you sure? Some players haven’t submitted yet.',
                                      style: TextStyle(
                                          color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('No'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text('Yes'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok != true) {
                                  debugPrint('[EndGame] Cancelled by host');
                                  return;
                                }
                              }

                              try {
                                debugPrint(
                                    '[EndGame] Writing finished status...');
                                await FirestoreRefs
                                    .gameDoc(_repo.db, widget.gameId)
                                    .set(
                                  {
                                    'status': 'finished',
                                    'finishedAt':
                                    FieldValue.serverTimestamp(),
                                  },
                                  SetOptions(merge: true),
                                );

                                debugPrint(
                                    '[EndGame] Navigating to ScoreScreen...');
                                _goToScoresOnce(); // one-way exit
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Failed to end game: $e')),
                                );
                              }
                            }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: allCluesHaveOne
                                  ? Colors.redAccent
                                  : Colors.grey,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text('End Game'),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _RosterEntry {
  final String id;    // stable key (prefer deviceId or unique name)
  final String label; // display name
  const _RosterEntry({required this.id, required this.label});
}

class _PlayerGallery extends StatelessWidget {
  const _PlayerGallery({
    required this.roster,
    required this.submissionsForClue,
    required this.heroPrefix,
  });

  final List<_RosterEntry> roster;
  final Map<String, Map<String, dynamic>> submissionsForClue; // playerId -> sub
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    if (roster.isEmpty && submissionsForClue.isEmpty) {
      return const Text(
        'No submissions yet.',
        style: TextStyle(color: Colors.white70),
      );
    }

    final tiles = <Widget>[];

    if (roster.isNotEmpty) {
      for (final r in roster) {
        final sub = submissionsForClue[r.id];
        tiles.add(_PlayerTile(
          playerId: r.id,
          label: r.label,
          imageUrl: sub?['imageUrl'] as String?,
          heroTag: '$heroPrefix-${r.id}',
        ));
      }
    } else {
      submissionsForClue.forEach((pid, sub) {
        tiles.add(_PlayerTile(
          playerId: pid,
          label: pid,
          imageUrl: sub['imageUrl'] as String?,
          heroTag: '$heroPrefix-$pid',
        ));
      });
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tiles,
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.playerId,
    required this.label,
    required this.imageUrl,
    required this.heroTag,
  });

  final String playerId;
  final String label;     // shown under the tile
  final String? imageUrl; // null => not submitted
  final String heroTag;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.take(1).toString() +
        parts.last.characters.take(1).toString())
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final submitted = imageUrl != null && imageUrl!.isNotEmpty;

    final nameLabel = Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white.withOpacity(submitted ? 1.0 : 0.6),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );

    if (!submitted) {
      return SizedBox(
        width: 84,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38),
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _initials(label),
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 6),
            nameLabel,
          ],
        ),
      );
    }

    return SizedBox(
      width: 84,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => _FullScreenPhoto(
                    heroTag: heroTag,
                    networkUrl: imageUrl!,
                  ),
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child),
                ),
              );
            },
            child: Hero(
              tag: heroTag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF3E2C8B),
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image, color: Colors.white70),
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
          const SizedBox(height: 6),
          nameLabel,
        ],
      ),
    );
  }
}

/// Simple full-screen network image with pinch-to-zoom + Hero
class _FullScreenPhoto extends StatelessWidget {
  const _FullScreenPhoto({
    required this.heroTag,
    this.networkUrl,
    this.assetPath,
    this.filePath,
  }) : assert(networkUrl != null || assetPath != null || filePath != null);

  final String heroTag;
  final String? networkUrl;
  final String? assetPath;
  final String? filePath;

  @override
  Widget build(BuildContext context) {
    final Widget image = networkUrl != null
        ? Image.network(networkUrl!, fit: BoxFit.contain)
        : (assetPath != null
        ? Image.asset(assetPath!, fit: BoxFit.contain)
        : Image.file(File(filePath!), fit: BoxFit.contain));

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
