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
import 'package:snaphunt/services/app_helpers.dart';

class HostLiveSubmissionsScreen extends StatefulWidget {
  final String gameId;
  final String? hostNickname;
  final String? hostDeviceId;
  final GameRepository? repository;

  const HostLiveSubmissionsScreen({
    super.key,
    required this.gameId,
    this.hostNickname,
    this.hostDeviceId,
    this.repository,
  });

  @override
  State<HostLiveSubmissionsScreen> createState() => _HostLiveSubmissionsScreenState();
}

class _HostLiveSubmissionsScreenState extends State<HostLiveSubmissionsScreen> {
  late final GameRepository _repo;
  bool _navigatedToScores = false;

  bool _isHostNickname(String nick) {
    final hn = (widget.hostNickname ?? '').trim();
    if (hn.isEmpty || nick.isEmpty) return false;
    return hn.toLowerCase() == nick.toLowerCase();
  }

  bool _isHostId(String deviceId) {
    final hd = (widget.hostDeviceId ?? '').trim();
    if (hd.isEmpty || deviceId.isEmpty) return false;
    return hd == deviceId;
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? GameRepository();
  }

  void _goToScoresOnce() {
    if (!mounted || _navigatedToScores) return;
    _navigatedToScores = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        fadeTo(ScoreScreen(gameId: widget.gameId)),
            (route) => false,
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
        title: const Text('Host — Live Submissions'),
      ),
      // FIX: your enum is GameNavTab, not GameNav. Also pass gameId (optional but useful for Map tab).
      bottomNavigationBar: GameNavBar(current: GameNavTab.none, gameId: widget.gameId),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreRefs.gameDoc(_repo.db, widget.gameId).snapshots(),
        builder: (context, gameSnap) {
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

          if (statusRaw == 'finished') {
            _goToScoresOnce();
          }

          // Build roster of non-host players (deviceId preferred, fallback nickname)
          final roster = <_RosterEntry>[];
          final seen = <String>{}; // de-dupe by deviceId if present
          final hostNicknames = <String>{};

          // collect host nicknames to filter legacy string entries
          for (final e in rawPlayers) {
            if (e is Map) {
              final m = Map<String, dynamic>.from(e);
              final did = (m['deviceId'] as String?)?.trim() ?? '';
              final nick = (m['nickname'] as String?)?.trim() ?? '';
              final isHost = (hostDeviceIdField.isNotEmpty && did == hostDeviceIdField) ||
                  (did.isNotEmpty && roles[did] == 'host') ||
                  (_isHostId(did)) ||
                  _isHostNickname(nick);
              if (isHost && nick.isNotEmpty) hostNicknames.add(nick);
            }
          }

          for (final e in rawPlayers) {
            if (e is Map) {
              final m = Map<String, dynamic>.from(e);
              final did = (m['deviceId'] as String?)?.trim() ?? '';
              final nick = (m['nickname'] as String?)?.trim() ?? '';

              final isHost = (hostDeviceIdField.isNotEmpty && did == hostDeviceIdField) ||
                  (did.isNotEmpty && roles[did] == 'host') ||
                  (_isHostId(did)) ||
                  _isHostNickname(nick);
              if (isHost) continue;

              String id;
              if (did.isNotEmpty) {
                if (seen.contains(did)) continue;
                seen.add(did);
                id = did;
              } else {
                // legacy: no deviceId stored, use nickname if not a host nick
                if (nick.isEmpty || hostNicknames.contains(nick)) continue;
                id = nick;
              }
              final label = nick.isNotEmpty ? nick : id;
              roster.add(_RosterEntry(id: id, label: label));
            } else if (e is String) {
              final nick = e.trim();
              if (nick.isEmpty || hostNicknames.contains(nick)) continue;
              roster.add(_RosterEntry(id: nick, label: nick));
            }
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
                    .orderBy('createdAt', descending: true)
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

                  // Latest-by-(clueId, playerId)
                  final latestByClueByPlayer = <String, Map<String, Map<String, dynamic>>>{};
                  final whenMap = <String, Map<String, int>>{};
                  int _extractSubmissionMillis(Map<String, dynamic> m) {
                    final ts = m['updatedAt'] ?? m['submittedAt'] ?? m['createdAt'];
                    if (ts is Timestamp) return ts.millisecondsSinceEpoch;
                    if (ts is int) return ts;
                    if (ts is num) return ts.toInt();
                    return -1;
                  }

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

                  // End Game gating
                  final allCluesHaveOne = clues.every(
                        (c) => (latestByClueByPlayer[c.id]?.isNotEmpty ?? false),
                  );
                  bool everyoneSubmittedAll = false;
                  if (roster.isNotEmpty) {
                    everyoneSubmittedAll = clues.every((c) {
                      final mp = latestByClueByPlayer[c.id] ?? const {};
                      return roster.every((r) => mp.containsKey(r.id));
                    });
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          itemCount: clues.length,
                          itemBuilder: (context, i) {
                            final clue = clues[i];
                            final clueSubs = latestByClueByPlayer[clue.id] ?? const <String, Map<String, dynamic>>{};

                            final hostHeroTag = 'host-${clue.id}';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${i + 1} / ${clues.length}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w700,
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
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              PageRouteBuilder(
                                                pageBuilder: (_, __, ___) => _FullScreenPhoto(
                                                  heroTag: hostHeroTag,
                                                  networkUrl: clue.imageUrl,
                                                  caption: 'Host Photo',
                                                ),
                                                transitionsBuilder: (_, animation, __, child) =>
                                                    FadeTransition(opacity: animation, child: child),
                                              ),
                                            );
                                          },
                                          child: Hero(
                                            tag: hostHeroTag,
                                            child: Image.network(
                                              clue.imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                              const Center(child: Icon(Icons.broken_image, color: Colors.white70)),
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

                                    // FIX: pass the actual roster (not finalRoster) and hostUrl for Compare
                                    _PlayerGallery(
                                      roster: roster,
                                      submissionsForClue:
                                      Map<String, Map<String, dynamic>>.from(clueSubs),
                                      heroPrefix: 'clue-${clue.id}',
                                      hostUrl: clue.imageUrl,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      SafeArea(
                        top: false,
                        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B0000), // Dark red
                              foregroundColor: Colors.white,            // White text
                            ),
                            onPressed: allCluesHaveOne
                                ? () async {
                              if (!everyoneSubmittedAll) {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF241A5E),
                                    title: const Text('End game now?', style: TextStyle(color: Colors.white)),
                                    content: const Text(
                                      'Not every player has submitted for every clue. You can still end the game now and reveal scores.',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF8B0000), // Match dark red inside dialog
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        child: const Text('End Game'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok != true) return;
                              }

                              try {
                                await FirestoreRefs.gameDoc(_repo.db, widget.gameId).set(
                                  {
                                    'status': 'finished',
                                    'finishedAt': FieldValue.serverTimestamp(),
                                  },
                                  SetOptions(merge: true),
                                );
                                _goToScoresOnce();
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to end game: $e')),
                                );
                              }
                            }
                                : null,
                            child: Text(
                              allCluesHaveOne
                                  ? (everyoneSubmittedAll
                                  ? 'End Game (All submissions in)'
                                  : 'End Game (Some missing)')
                                  : 'Waiting for first submissions…',
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
    );
  }
}

class _RosterEntry {
  final String id; // deviceId or nickname
  final String label;
  _RosterEntry({required this.id, required this.label});
}

class _PlayerGallery extends StatelessWidget {
  const _PlayerGallery({
    required this.roster,
    required this.submissionsForClue,
    required this.heroPrefix,
    required this.hostUrl, // added to enable Compare
  });

  final List<_RosterEntry> roster;
  final Map<String, Map<String, dynamic>> submissionsForClue; // playerId -> sub
  final String heroPrefix;
  final String hostUrl;

  @override
  Widget build(BuildContext context) {
    if (roster.isEmpty && submissionsForClue.isEmpty) {
      return const Text('No submissions yet.', style: TextStyle(color: Colors.white70));
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
          hostUrl: hostUrl,
        ));
      }
    } else {
      submissionsForClue.forEach((pid, sub) {
        tiles.add(_PlayerTile(
          playerId: pid,
          label: pid,
          imageUrl: sub['imageUrl'] as String?,
          heroTag: '$heroPrefix-$pid',
          score: (sub['score'] as num?)?.toDouble(),
          hostUrl: hostUrl,
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
    required this.hostUrl,
  });

  final String playerId;
  final String label; // shown under the tile
  final String? imageUrl; // null => not submitted
  final String heroTag;
  final double? score;
  final String hostUrl;

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
                color: const Color(0xFF100A1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                _initials(label),
                style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(height: 6),
            nameLabel,
            const SizedBox(height: 2),
            const Text('No submission', style: TextStyle(color: Colors.white54, fontSize: 11)),
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
              if (imageUrl == null || imageUrl!.isEmpty) return;
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => _CompareImagesScreen(
                    hostUrl: hostUrl,
                    playerUrl: imageUrl!,
                    hostHero: 'host_' + heroTag,
                    playerHero: heroTag,
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
                            child: const Icon(Icons.broken_image, color: Colors.white70),
                          ),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: _TinyTagButton(
                          text: 'Compare',
                          onTap: () {
                            if (imageUrl == null || imageUrl!.isEmpty) return;
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => _CompareImagesScreen(
                                  hostUrl: hostUrl,
                                  playerUrl: imageUrl!,
                                  hostHero: 'host_' + heroTag,
                                  playerHero: heroTag,
                                ),
                                transitionsBuilder: (_, animation, __, child) =>
                                    FadeTransition(opacity: animation, child: child),
                              ),
                            );
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
          Text(
            score == null ? 'Scoring…' : 'Score ${score!.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
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
    Color bg;
    Color fg;
    String text;

    if (score == null) {
      bg = Colors.white10;
      fg = Colors.white70;
      text = '…';
    } else {
      final v = score!.clamp(0, 100).toInt();
      text = '$v';
      if (v >= 80) {
        bg = Colors.green.withOpacity(0.3);
        fg = Colors.white;
      } else if (v >= 50) {
        bg = Colors.orange.withOpacity(0.3);
        fg = Colors.white;
      } else {
        bg = Colors.red.withOpacity(0.3);
        fg = Colors.white;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

/// Simple full-screen network/asset/file image with pinch-to-zoom + Hero + caption
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
    const darkBg = Color(0xFF3E2C8B);

    Widget imageWidget;
    if (networkUrl != null && networkUrl!.isNotEmpty) {
      imageWidget = Image.network(
        networkUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white70)),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
      );
    } else if (assetPath != null && assetPath!.isNotEmpty) {
      imageWidget = Image.asset(assetPath!, fit: BoxFit.contain);
    } else if (filePath != null && filePath!.isNotEmpty) {
      imageWidget = Image.file(File(filePath!), fit: BoxFit.contain);
    } else {
      imageWidget = const Center(child: Icon(Icons.broken_image, color: Colors.white70));
    }

    return WillPopScope (
        onWillPop: () async {
          final shouldLeave=backConfirmation(context: context, screenType: ScreenType.gameScreen);
          return shouldLeave ?? false;
        },

    child: Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(backgroundColor: darkBg),
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(minScale: 0.5, maxScale: 5, child: imageWidget),
            ),
          ),
          if (caption != null && caption!.trim().isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }
}

/// Small pill-style button for overlay chips (e.g., Compare)
class _TinyTagButton extends StatelessWidget {
  const _TinyTagButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF100A1E).withOpacity(0.8),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

/// Side-by-side compare screen with pinch-zoom + optional Hero
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
        errorBuilder: (_, __, ___) =>
        const Center(child: Text('Image failed to load', style: TextStyle(color: Colors.white70))),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
      );
      final viewer = InteractiveViewer(minScale: 0.5, maxScale: 5, child: img);
      return hero == null ? viewer : Hero(tag: hero, child: viewer);
    }

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(backgroundColor: darkBg, title: const Text('Compare Images')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          if (isWide) {
            return Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Host Clue', style: TextStyle(color: Colors.white70)),
                      ),
                      Expanded(child: Center(child: zoomable(hostUrl, hero: hostHero))),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, color: Colors.black26),
                Expanded(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Player', style: TextStyle(color: Colors.white70)),
                      ),
                      Expanded(child: Center(child: zoomable(playerUrl, hero: playerHero))),
                    ],
                  ),
                ),
              ],
            );
          }
          // Stacked for phones
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: Text('Host Clue', style: TextStyle(color: Colors.white70))),
              ),
              SizedBox(height: constraints.maxHeight * 0.45, child: zoomable(hostUrl, hero: hostHero)),
              const Divider(height: 16, thickness: 1, color: Colors.black26),
              const Center(child: Text('Player', style: TextStyle(color: Colors.white70))),
              SizedBox(height: constraints.maxHeight * 0.45, child: zoomable(playerUrl, hero: playerHero)),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}
