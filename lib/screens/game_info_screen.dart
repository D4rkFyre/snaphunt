// lib/screens/game_info_screen.dart
import 'package:flutter/material.dart';
import 'package:snaphunt/widgets/game_nav_bar.dart';

class GameInfoScreen extends StatelessWidget {
  const GameInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3E2C8B),
      appBar: AppBar(
          backgroundColor: const Color(0xFF3E2C8B),
          title: const Text('How SnapHunt Works')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Quick Rundown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('• Recreate the host’s clue photos inside the game area.'),
          Text('• You get up to 3 attempts per clue. Latest submission counts.'),
          Text('• Scores use image similarity and geometry checks.'),
          Text('• Stay within the geofence; outside shots may be rejected.'),
          SizedBox(height: 16),
          Text('Tips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Line up angles and lighting, and watch your remaining attempts.'),
        ],
      ),
      bottomNavigationBar: const GameNavBar(current: GameNavTab.info),
    );
  }
}
