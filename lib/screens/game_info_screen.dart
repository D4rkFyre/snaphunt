import 'package:flutter/material.dart';
import 'package:snaphunt/widgets/game_nav_bar.dart';

class GameInfoScreen extends StatelessWidget {
  const GameInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF3E2C8B);      // app purple
    const card = Color(0xFF5D4BB2);    // lighter purple card
    const accent = Color(0xFFFFC943);  // brand yellow

    Widget sectionTitle(String text, {IconData icon = Icons.info_outline}) {
      return Row(
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 0.2,
            ),
          ),
        ],
      );
    }

    Widget bullet(String text) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: Colors.white70, height: 1.4)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      );
    }

    Widget tag(String label, Color color, {String? sub}) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.55)),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                sub,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
        ],
      );
    }

    Widget infoCard({required Widget child}) {
      return Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: child,
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('How SnapHunt Works'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // What is SnapHunt?
          infoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle('What is SnapHunt?', icon: Icons.camera_alt_outlined),
                const SizedBox(height: 8),
                const Text(
                  'SnapHunt is a real-time photo scavenger hunt. The host posts “clue” photos, and players '
                      'recreate them as closely as possible inside the game area. Each clue is scored for visual similarity — your latest photo always counts!',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // How to Play
          infoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle('How to Play', icon: Icons.play_circle_outline),
                const SizedBox(height: 8),
                bullet('Open a clue and study the host’s image.'),
                bullet('Use the in-app camera to take your shot and match it closely.'),
                bullet('Stay inside the game area — submissions outside the geofence won’t count.'),
                bullet('You can retry a clue later if you have tokens left.'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Attempts & Tokens
          infoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle('Attempts & Tokens', icon: Icons.autorenew),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    tag('First: FREE', Colors.lightBlueAccent),
                    tag('2 retries/clue', Colors.orangeAccent),
                    tag('Uses tokens', Colors.greenAccent),
                  ],
                ),
                const SizedBox(height: 10),
                bullet('Every player starts with a limited number of tokens.'),
                bullet('Your first attempt on each clue costs nothing.'),
                bullet('Each re-take uses 1 token.'),
                bullet('You can retry a clue up to 2 times — if you have tokens available.'),
                bullet('Your remaining tokens are displayed in the bottom navigation bar.'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Scoring & Hints (with visuals)
          infoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle('Scoring & Hints', icon: Icons.emoji_events_outlined),
                const SizedBox(height: 8),
                bullet('Your photo is compared to the host’s using image similarity and geometry alignment.'),
                bullet('Scores range from 0–100 — higher means a better match.'),
                const SizedBox(height: 8),
                const Text(
                  'During the game, full scores stay hidden. Instead, you’ll see a quick hint tag on each submission:',
                  style: TextStyle(color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    tag('LOW', const Color(0xFFE53935), sub: '< 30'),
                    tag('MID', const Color(0xFFFFA000), sub: '30–69'),
                    tag('HIGH', const Color(0xFF43A047), sub: '70+'),
                  ],
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    '“HIGH” means you’re nearly identical to the host image — nice work!',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Comparing Views
          infoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle('Comparing Views', icon: Icons.compare),
                const SizedBox(height: 8),
                bullet('Tap “Compare Images” on your submission card to view your shot beside the host’s.'),
                bullet('Hosts can view every player’s side-by-side comparison live during the match.'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Location rules
          infoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle('Location Rules', icon: Icons.my_location_outlined),
                const SizedBox(height: 8),
                bullet('Make sure location services are turned on and allowed for the app.'),
                bullet('You must be inside the geofence to submit your photo.'),
                bullet('If GPS accuracy drops, try moving to a more open area for a stronger signal.'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Pro tips
          infoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle('Pro Tips', icon: Icons.lightbulb_outline),
                const SizedBox(height: 8),
                bullet('Match angles, framing, and lighting — details boost your similarity score.'),
                bullet('Use “Compare Images” before spending tokens on re-takes.'),
                bullet('Plan your retries wisely across all clues — not just one.'),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Footer
          Center(
            child: Column(
              children: [
                const Icon(Icons.camera_enhance_rounded,
                    color: Colors.white70, size: 42),
                const SizedBox(height: 8),
                Text(
                  'Have fun and hunt smart. 😎',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const GameNavBar(current: GameNavTab.info),
    );
  }
}
