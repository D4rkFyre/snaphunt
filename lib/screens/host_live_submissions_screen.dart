// lib/screens/host_live_submissions_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:snaphunt/repositories/game_repository.dart';
import 'package:snaphunt/models/clue_model.dart';
import 'package:snaphunt/services/firestore_refs.dart';
import 'package:snaphunt/screens/score_screen.dart';
import 'package:snaphunt/widgets/game_nav_bar.dart';
import 'package:snaphunt/services/route_transitions.dart';


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
        fadeTo(ScoreScreen(gameId: widget.gameId)),
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
                // Use updatedAt so UI reacts immediately to retakes/scores
                stream: FirestoreRefs
                    .submissions(_repo.db, widget.gameId)
                    .orderBy('updatedAt', descending: true)
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

                  // ---- Pick the LATEST submission per (clueId, playerId)
                  // Use submission time (createdAt/submittedAt/timestamp/ts), not updatedAt,
                  // so an older doc updated later won't override a newer submission.
                  int _extractSubmissionMillis(Map<String, dynamic> m) {
                    final keys = const ['createdAt', 'submittedAt', 'timestamp', 'ts'];
                    for (final k in keys) {
                      final v = m[k];
                      if (v == null) continue;
                      if (v is Timestamp) return v.millisecondsSinceEpoch;
                      if (v is num) return v.toInt();
                      if (v is String) {
                        try {
                          return DateTime.parse(v).millisecondsSinceEpoch;
                        } catch (_) {/* ignore */}
                      }
                    }
                    return 0;
                  }

                  final Map<String, Map<String, Map<String, dynamic>>> latestByClueByPlayer = {};
                  final Map<String, Map<String, int>> whenMap = {}; // clueId -> playerId -> ms

                  for (final d in subsSnap.data?.docs ?? const []) {
                    final m = d.data();

                    final clueId = (m['clueId'] as String?)?.trim();
                    final playerId = (m['playerId'] as String?)?.trim() ?? '';
                    if (clueId == null || clueId.isEmpty || playerId.isEmpty) continue;
                    if (_isHostId(playerId)) continue; // ignore host submissions

                    final when = _extractSubmissionMillis(m);
                    final wp = (whenMap[clueId] ??= <String, int>{});
                    final prev = wp[playerId] ?? -1;
                    if (when >= prev) {
                      wp[playerId] = when;
                      (latestByClueByPlayer[clueId] ??= {})[playerId] = {
                        ...m,
                        'id': d.id,
                      };
                    }
                  }

                  // ----- Completion logic for the End Game button -----
                  // 1) Every clue has at least one submission?
                  final allCluesHaveOne = clues.every(
                        (c) => (latestByClueByPlayer[c.id]?.isNotEmpty ?? false),
                  );

                  // 2) Have ALL (non-host) players submitted for EVERY clue?
                  bool everyoneSubmittedAll = false;
                  if (roster.isNotEmpty) {
                    everyoneSubmittedAll = clues.every((c) {
                      final count = latestByClueByPlayer[c.id]?.length ?? 0;
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
                                latestByClueByPlayer[clue.id] ?? const <String, Map>{};

                            // Merge roster with any submitters not in roster.
                            final merged = <String, _RosterEntry>{
                              for (final r in roster) r.id: r
                            };
                            for (final pid in clueSubs.keys) {
                              merged.putIfAbsent(
                                  pid, () => _RosterEntry(id: pid, label: pid));
                            }
                            final finalRoster =
                            merged.values.toList(growable: false);

                            final submittedCount = clueSubs.length;
                            final totalCount = finalRoster.isNotEmpty
                                ? finalRoster.length
                                : submittedCount;

                            final hostHeroTag = 'host-${clue.id}';

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
                                  crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
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

                                    // Host clue image → tap to fullscreen (Hero)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              PageRouteBuilder(
                                                pageBuilder: (_, __, ___) =>
                                                    _FullScreenPhoto(
                                                      heroTag: hostHeroTag,
                                                      networkUrl: clue.imageUrl,
                                                      caption: 'Host Photo',
                                                    ),
                                                transitionsBuilder:
                                                    (_, animation, __, child) =>
                                                    FadeTransition(
                                                      opacity: animation,
                                                      child: child,
                                                    ),
                                              ),
                                            );
                                          },
                                          child: Hero(
                                            tag: hostHeroTag,
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
                                                if (progress == null) {
                                                  return child;
                                                }
                                                return const Center(
                                                  child:
                                                  CircularProgressIndicator(),
                                                );
                                              },
                                            ),
                                          ),
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
                                  debugPrint(
                                      '[EndGame] Cancelled by host');
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
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Failed to end game: $e'),
                                  ),
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
      bottomNavigationBar: GameNavBar(
        current: GameNavTab.none,
        gameId: widget.gameId,
      ),
    );
  }
}

class _RosterEntry {
  final String id; // stable key (prefer deviceId or unique name)
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
          score: (sub?['score'] as num?)?.toDouble(),
        ));
      }
    } else {
      // Fallback: no roster → iterate known submitters
      submissionsForClue.forEach((pid, sub) {
        tiles.add(_PlayerTile(
          playerId: pid,
          label: pid,
          imageUrl: sub['imageUrl'] as String?,
          heroTag: '$heroPrefix-$pid',
          score: (sub['score'] as num?)?.toDouble(),
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
    this.score,
  });

  final String playerId;
  final String label; // shown under the tile
  final String? imageUrl; // null => not submitted
  final String heroTag;
  final double? score;

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
        color: Colors.white.withValues(alpha: submitted ? 1.0 : 0.6),
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

    final scoreSubtitle = Text(
      score == null ? 'Scoring…' : 'Score: ${score!.toStringAsFixed(0)}',
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
    );

    return SizedBox(
      width: 84,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final caption = score == null
                  ? '$label • Scoring…'
                  : '$label • Score ${score!.toStringAsFixed(0)}';
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => _FullScreenPhoto(
                    heroTag: heroTag,
                    networkUrl: imageUrl!,
                    caption: caption,
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
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF3E2C8B),
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image,
                                color: Colors.white70),
                          ),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                                child: CircularProgressIndicator());
                          },
                        ),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: _ScoreBadge(score: score),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          nameLabel,
          const SizedBox(height: 2),
          scoreSubtitle,
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({this.score});
  final double? score;

  @override
  Widget build(BuildContext context) {
    final pending = score == null;
    final text = pending ? '…' : score!.toStringAsFixed(0);

    Color bg;
    Color fg;
    if (pending) {
      bg = Colors.black54;
      fg = Colors.white;
    } else if (score! >= 80) {
      bg = Colors.greenAccent.withValues(alpha: 0.9);
      fg = Colors.black;
    } else if (score! >= 50) {
      bg = Colors.orangeAccent.withValues(alpha: 0.9);
      fg = Colors.black;
    } else {
      bg = Colors.white24;
      fg = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Simple full-screen network image with pinch-to-zoom + Hero + caption
class _FullScreenPhoto extends StatelessWidget {
  const _FullScreenPhoto({
    required this.heroTag,
    this.networkUrl,
    this.assetPath,
    this.filePath,
    this.caption,
  }) : assert(networkUrl != null || assetPath != null || filePath != null);

  final String heroTag;
  final String? networkUrl;
  final String? assetPath;
  final String? filePath;
  final String? caption;

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
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: image,
              ),
            ),
          ),
          if (caption != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    caption!,
                    textAlign: TextAlign.center,
                    style:
                    const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}