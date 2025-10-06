// lib/screens/score_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:snaphunt/services/firestore_refs.dart';
import 'package:snaphunt/repositories/game_repository.dart';
import 'package:snaphunt/screens/home_screen.dart';
import 'package:snaphunt/widgets/game_nav_bar.dart';

class ScoreScreen extends StatefulWidget {
  final String gameId;
  final GameRepository? repository;

  const ScoreScreen({
    super.key,
    required this.gameId,
    this.repository,
  });

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  late final GameRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? GameRepository();
  }

  void _goHome() {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF3E2C8B);
    const cardBg = Color(0xFF5D4BB2);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _goHome();
      },
      child: Scaffold(
        backgroundColor: darkBg,
        appBar: AppBar(
          backgroundColor: darkBg,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _goHome,
            tooltip: 'Back to Home',
          ),
          title: const Text(
            'Final Scores',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirestoreRefs.gameDoc(_repo.db, widget.gameId).snapshots(),
          builder: (context, gameSnap) {
            // ---------------- Build roster (EXCLUDE HOST) ----------------
            final Map<String, String> roster = {}; // playerId -> label
            String hostDeviceId = '';
            Map<String, dynamic> roles = const {};
            final rawPlayers = <dynamic>[];

            if (gameSnap.hasData && gameSnap.data?.data() != null) {
              final g = gameSnap.data!.data()!;
              hostDeviceId = (g['hostDeviceId'] as String?)?.trim() ?? '';
              roles = (g['roles'] as Map?)?.cast<String, dynamic>() ?? const {};
              final rp = g['players'];
              if (rp is List) rawPlayers.addAll(rp);
            }

            // Detect legacy host nickname so we can exclude it
            final hostNicknames = <String>{};
            for (final e in rawPlayers) {
              if (e is Map) {
                final m = Map<String, dynamic>.from(e);
                final did = (m['deviceId'] as String?)?.trim() ?? '';
                final nick = (m['nickname'] as String?)?.trim() ?? '';
                final isHost = (hostDeviceId.isNotEmpty && did == hostDeviceId) ||
                    (did.isNotEmpty && roles[did] == 'host');
                if (isHost && nick.isNotEmpty) hostNicknames.add(nick);
              }
            }

            // Fill roster with non-host players (prefer deviceId as id)
            for (final e in rawPlayers) {
              if (e is Map) {
                final m = Map<String, dynamic>.from(e);
                final did = (m['deviceId'] as String?)?.trim() ?? '';
                final nick = (m['nickname'] as String?)?.trim() ?? '';
                final isHost = (hostDeviceId.isNotEmpty && did == hostDeviceId) ||
                    (did.isNotEmpty && roles[did] == 'host');
                if (isHost) continue;
                final id = did.isNotEmpty ? did : (nick.isNotEmpty ? nick : '');
                if (id.isEmpty) continue;
                roster[id] = nick.isNotEmpty ? nick : id;
              } else if (e is String) {
                final name = e.trim();
                if (name.isEmpty) continue;
                if (hostNicknames.contains(name)) continue;
                roster[name] = name; // legacy string-only entry
              }
            }

            bool isHostId(String id) {
              if (id.isEmpty) return false;
              return hostDeviceId.isNotEmpty && id == hostDeviceId;
            }

            // ---------------- Also stream clues to get COUNT ----------------
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreRefs.clues(_repo.db, widget.gameId).snapshots(),
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

                final totalClues = cluesSnap.data?.docs.length ?? 0;

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreRefs
                      .submissions(_repo.db, widget.gameId)
                      .snapshots(),
                  builder: (context, subsSnap) {
                    if (subsSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (subsSnap.hasError) {
                      return Center(
                        child: Text(
                          'Error loading scores: ${subsSnap.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    // --------- Gather latest submission per (playerId, clueId) ---------
                    final Map<String, Map<String, _LatestSub>> latest = {};
                    final Map<String, Map<String, int>> whenMap = {}; // millis

                    int _extractWhenMillis(Map<String, dynamic> m) {
                      // Look for common timestamp fields in priority order
                      final keys = const [
                        'updatedAt',
                        'createdAt',
                        'submittedAt',
                        'timestamp',
                        'ts',
                      ];
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
                      return 0; // unknown -> treat as oldest
                    }

                    for (final d in subsSnap.data?.docs ?? const []) {
                      final m = d.data();

                      final pid = (m['playerId'] as String?)?.trim() ?? '';
                      if (pid.isEmpty || isHostId(pid)) continue;

                      final clueId = (m['clueId'] as String?)?.trim() ?? '';
                      if (clueId.isEmpty) continue;

                      final when = _extractWhenMillis(m);
                      final imageUrl = (m['imageUrl'] as String?)?.trim();
                      final score = (m['score'] as num?)?.toDouble();

                      final wp = whenMap.putIfAbsent(pid, () => <String, int>{});
                      final prevWhen = wp[clueId] ?? -1;
                      if (when >= prevWhen) {
                        wp[clueId] = when;
                        final lp = latest.putIfAbsent(pid, () => <String, _LatestSub>{});
                        lp[clueId] = _LatestSub(
                          imageUrl: imageUrl,
                          when: when,
                          score: score,
                        );
                      }
                    }
                    // -------------------------------------------------------------------------

                    // Build final rows
                    final List<_AvgRow> rows = [];
                    final ids = {...roster.keys, ...latest.keys};

                    for (final pid in ids) {
                      final label = roster[pid] ?? pid;

                      if (totalClues <= 0) {
                        rows.add(_AvgRow(
                          playerId: pid,
                          name: label,
                          avg: 0.0,
                          count: 0,
                          imageUrls: const [],
                        ));
                        continue;
                      }

                      final perClue = latest[pid] ?? const <String, _LatestSub>{};

                      double sum = 0.0;
                      int submittedCount = 0;
                      final List<String> images = [];
                      perClue.forEach((_, s) {
                        if (s.score != null) {
                          sum += s.score!;
                          submittedCount++;
                        }
                        if ((s.imageUrl ?? '').isNotEmpty) {
                          images.add(s.imageUrl!);
                        }
                      });

                      final avg = sum / totalClues;

                      rows.add(_AvgRow(
                        playerId: pid,
                        name: label,
                        avg: avg,
                        count: submittedCount,
                        imageUrls: images,
                      ));
                    }

                    // Sort by avg desc, then by name
                    rows.sort((a, b) {
                      final d = b.avg.compareTo(a.avg);
                      if (d != 0) return d;
                      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                    });

                    if (rows.isEmpty) {
                      return Column(
                        children: [
                          const Expanded(
                            child: Center(
                              child: Text(
                                'No scores yet.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                          // Bottom New Game button
                          SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _goHome,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.greenAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16, horizontal: 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: const Text(
                                    'New Game',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    final top = rows.take(3).toList();

                    // ---- Main content + bottom button ----
                    return Column(
                      children: [
                        // Expandable main content (winners + leaderboard)
                        Expanded(
                          child: Column(
                            children: [
                              // Winners block
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Winners',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                        children: [
                                          if (top.length >= 2)
                                            _PodiumTile(rank: 2, row: top[1]),
                                          _PodiumTile(
                                              rank: 1,
                                              row: top[0],
                                              highlight: true),
                                          if (top.length >= 3)
                                            _PodiumTile(rank: 3, row: top[2]),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Full leaderboard WITH a single-row horizontal scroller
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ListView.separated(
                                      padding:
                                      const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                      itemCount: rows.length,
                                      separatorBuilder: (_, __) => const Divider(
                                          color: Colors.white24, height: 1),
                                      itemBuilder: (context, i) {
                                        final r = rows[i];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6),
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              ListTile(
                                                leading:
                                                _CircleInitials(name: r.name),
                                                title: Text(
                                                  r.name,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  totalClues > 0
                                                      ? 'Avg across $totalClues clue(s) • ${r.count} submission(s)'
                                                      : 'No clues',
                                                  style: const TextStyle(
                                                      color: Colors.white70),
                                                ),
                                                trailing: Text(
                                                  r.avg.toStringAsFixed(0),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),

                                              // >>> SINGLE-LINE HORIZONTAL SCROLLER <<<
                                              if (r.imageUrls.isNotEmpty)
                                                SizedBox(
                                                  height: 78,
                                                  child: ScrollConfiguration(
                                                    behavior: const _NoGlowBehavior(),
                                                    child: SingleChildScrollView(
                                                      scrollDirection:
                                                      Axis.horizontal,
                                                      physics:
                                                      const BouncingScrollPhysics(),
                                                      padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 12),
                                                      child: Row(
                                                        children: [
                                                          for (int idx = 0;
                                                          idx < r.imageUrls.length;
                                                          idx++) ...[
                                                            GestureDetector(
                                                              onTap: () {
                                                                Navigator.of(context).push(
                                                                  MaterialPageRoute(
                                                                    builder: (_) =>
                                                                        _ImageViewerPage(
                                                                          imageUrls:
                                                                          r.imageUrls,
                                                                          initialIndex: idx,
                                                                          title: r.name,
                                                                        ),
                                                                  ),
                                                                );
                                                              },
                                                              child: ClipRRect(
                                                                borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                    10),
                                                                child: AspectRatio(
                                                                  aspectRatio: 1,
                                                                  child:
                                                                  Image.network(
                                                                    r.imageUrls[idx],
                                                                    fit: BoxFit.cover,
                                                                    loadingBuilder:
                                                                        (c, w, p) {
                                                                      if (p == null) {
                                                                        return w;
                                                                      }
                                                                      return Container(
                                                                        color: Colors
                                                                            .black12,
                                                                        alignment:
                                                                        Alignment
                                                                            .center,
                                                                        child:
                                                                        const SizedBox(
                                                                          width: 18,
                                                                          height: 18,
                                                                          child:
                                                                          CircularProgressIndicator(
                                                                            strokeWidth:
                                                                            2,
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                                    errorBuilder:
                                                                        (c, e, st) {
                                                                      return Container(
                                                                        color: Colors
                                                                            .black26,
                                                                        alignment:
                                                                        Alignment
                                                                            .center,
                                                                        child:
                                                                        const Icon(
                                                                          Icons
                                                                              .broken_image,
                                                                          color: Colors
                                                                              .white70,
                                                                        ),
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Bottom New Game button (matches other green buttons)
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _goHome,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16, horizontal: 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  'New Game',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
      ),
    );
  }
}

class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();
  @override
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }

  // For newer Flutter versions (no glow):
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

class _LatestSub {
  final String? imageUrl;
  final int when;
  final double? score;
  _LatestSub({this.imageUrl, required this.when, this.score});
}

class _AvgRow {
  final String playerId;
  final String name;
  final double avg;
  final int count;
  final List<String> imageUrls;
  _AvgRow({
    required this.playerId,
    required this.name,
    required this.avg,
    required this.count,
    required this.imageUrls,
  });
}

class _PodiumTile extends StatelessWidget {
  final int rank; // 1,2,3
  final _AvgRow row;
  final bool highlight;
  const _PodiumTile({
    super.key,
    required this.rank,
    required this.row,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlight ? Colors.amber : Colors.white;
    final fg = highlight ? Colors.black : Colors.black87;

    return Column(
      children: [
        Container(
          width: highlight ? 92 : 80,
          height: highlight ? 92 : 80,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            row.avg.toStringAsFixed(0),
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              fontSize: highlight ? 28 : 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '#$rank',
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 110,
          child: Text(
            row.name,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _CircleInitials extends StatelessWidget {
  final String name;
  const _CircleInitials({super.key, required this.name});

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
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
    return CircleAvatar(
      backgroundColor: Colors.white,
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Full-screen image viewer with swipe / zoom.
class _ImageViewerPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String title;

  const _ImageViewerPage({
    required this.imageUrls,
    required this.initialIndex,
    required this.title,
  });

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.imageUrls.length,
        itemBuilder: (context, index) {
          final url = widget.imageUrls[index];
          return InteractiveViewer(
            panEnabled: true,
            minScale: 0.8,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (c, w, p) {
                  if (p == null) return w;
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
                errorBuilder: (c, e, st) => const Icon(
                  Icons.broken_image,
                  color: Colors.white70,
                  size: 48,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
