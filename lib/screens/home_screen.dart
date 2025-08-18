// lib/screens/home_screen.dart
import 'find_game_screen.dart';
import 'host_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// ---------------------------------------------------------------------------
/// HomeScreen
/// ---------------------------------------------------------------------------
/// Purpose
/// - Simple **landing hub**: choose to Host a game or Join a game.
///
/// What this screen does
/// - Shows two big tappable icons:
///   - **Host** → navigates to `HostGameScreen`
///   - **Join** → navigates to `JoinGameScreen`
/// - Includes a decorative bottom navigation bar (icons only).
///
/// Notes
/// - `_selectedIndex` currently just updates the highlighted icon in the bottom
///   nav; it does not swap the main content here (navigation is via the icons).
/// - If you later want true tabs, you can render different bodies based on
///   `_selectedIndex` instead of pushing new routes.
/// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Index for the decorative bottom nav
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;  // visual only in this screen
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Brand background color
      backgroundColor: const Color(0xFF3E2C8B),

      appBar: AppBar(
        title: const Text(
          "Snaphunt",
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

      // Center column with two large actions: Host and Join
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // -------------------------------
            // Host
            // -------------------------------
            const Text(
              'Host',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Big tappable icon -> HostGameScreen
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HostGameScreen(),
                  ),
                );
              },
              child: SvgPicture.asset(
                'assets/icons/maps.svg',
                width: 160,
                height: 160,
              ),
            ),

            const SizedBox(height: 40),

            // -------------------------------
            // Join
            // -------------------------------
            const Text(
              'Join',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Big tappable icon -> JoinGameScreen
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const JoinGameScreen(),
                  ),
                );
              },
              child: SvgPicture.asset(
                'assets/icons/camera.svg',
                width: 160, // bigger icon if needed
                height: 160,
              ),
            ),
          ],
        ),
      ),

      // Decorative bottom nav (icons only)
      // Currently does not change the body; just updates the selected icon.
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFFFFC943),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/book.svg',
              color: const Color(0xFF3E2C8B),
              width: 28,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/trophy-fill.svg',
              color: const Color(0xFF3E2C8B),
              width: 28,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/person-circle.svg',
              color: const Color(0xFF3E2C8B),
              width: 28,
            ),
            label: '',
          ),
        ],
      ),
    );
  }
}
