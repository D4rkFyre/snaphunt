// lib/screens/home_screen.dart
import 'find_game_screen.dart';
import 'host_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:snaphunt/services/device_id.dart';
import 'package:snaphunt/services/rejoin_service.dart';
import 'package:snaphunt/widgets/game_nav_bar.dart';
import 'package:snaphunt/services/route_transitions.dart';


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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = await DeviceId.get();
      if (!mounted) return;
      await RejoinService.promptRejoinIfApplicable(
        context: context,
        deviceId: id,
      );
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

            // Big tappable icon -> HostGameScreen (slides DOWN from top)
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(slideDownFromTop(const HostGameScreen()));
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

            // Big tappable icon -> JoinGameScreen (slides UP from bottom)
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(slideUpFromBottom(const JoinGameScreen()));
              },
              child: SvgPicture.asset(
                'assets/icons/camera.svg',
                width: 160, // bigger icon if needed
                height: 160,
              ),
            ),

            const SizedBox(height: 24),

            TextButton(
              onPressed: () async {
                final id = await DeviceId.get();
                if (!context.mounted) return;
                await RejoinService.promptRejoinIfApplicable(
                  context: context,
                  deviceId: id,
                );
              },
              child: const Text(
                'Rejoin Game',
                style: TextStyle(color: Colors.yellowAccent, fontSize: 16),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: const GameNavBar(current: GameNavTab.none),
    );
  }
}