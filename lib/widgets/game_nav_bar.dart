// lib/widgets/game_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:snaphunt/screens/map_screen.dart';
import 'package:snaphunt/screens/game_info_screen.dart';

import 'package:snaphunt/services/route_transitions.dart';

enum GameNavTab { none, map, info }

class GameNavBar extends StatelessWidget {
  final GameNavTab current;
  final String? gameId; // if null, Map button will show a hint instead of navigating
  final bool useSafeArea;
  final String? tokensText; // ADDED: optional tokens display

  const GameNavBar({
    super.key,
    required this.current,
    this.gameId,
    this.useSafeArea = true,
    this.tokensText, // ADDED
  });

  void _onSelect(BuildContext context, GameNavTab tab) {
    final nav = Navigator.of(context);

    // If the user taps the currently-selected tab (Map or Info) again,
    // close that screen by popping if possible.
    if (tab == current) {
      if (nav.canPop()) {
        nav.pop();
      }
      return;
    }

    if (tab == GameNavTab.map) {
      if (gameId == null || gameId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Map is available once you’re in a game.')),
        );
        return;
      }
      nav.push(slideUp(MapScreen(gameId: gameId!)));
      return;
    }

    if (tab == GameNavTab.info) {
      nav.push(slideUp(const GameInfoScreen()));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFC943); // yellow
    const fg = Color(0xFF3E2C8B); // purple

    final selected = current;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: useSafeArea,
      child: Stack(
        children: [
          BottomAppBar(
            color: bg,
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavBtn(
                  asset: 'assets/icons/map.svg',
                  semantic: 'Map',
                  selected: selected == GameNavTab.map,
                  onTap: () => _onSelect(context, GameNavTab.map),
                  color: fg,
                ),
                _NavBtn(
                  asset: 'assets/icons/info-circle.svg',
                  semantic: 'Game Info',
                  selected: selected == GameNavTab.info,
                  onTap: () => _onSelect(context, GameNavTab.info),
                  color: fg,
                ),
              ],
            ),
          ),
          if (tokensText != null && tokensText!.isNotEmpty)
            Positioned(
              right: 12,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF100A1E).withOpacity(0.88),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  tokensText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final String asset;
  final String semantic;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _NavBtn({
    super.key,
    required this.asset,
    required this.semantic,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semantic,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 64,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: SvgPicture.asset(asset, width: 28, color: color),
          ),
        ),
      ),
    );
  }
}
