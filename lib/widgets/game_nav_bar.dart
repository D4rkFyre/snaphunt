// lib/widgets/game_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:snaphunt/screens/map_screen.dart';
import 'package:snaphunt/screens/game_info_screen.dart';

enum GameNavTab { none, map, info }

class GameNavBar extends StatelessWidget {
  final GameNavTab current;
  final String? gameId; // if null, Map button will show a hint instead of navigating
  final bool useSafeArea;

  const GameNavBar({
    super.key,
    required this.current,
    this.gameId,
    this.useSafeArea = true,
  });

  void _onSelect(BuildContext context, GameNavTab tab) {
    if (tab == current) return;

    if (tab == GameNavTab.map) {
      if (gameId == null || gameId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Map is available once you’re in a game.')),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MapScreen(gameId: gameId!)),
      );
      return;
    }

    if (tab == GameNavTab.info) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GameInfoScreen()),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFC943); // your yellow
    const fg = Color(0xFF3E2C8B); // your purple

    final selected = current;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: useSafeArea,
      child: BottomAppBar(
        color: bg,
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavBtn(
              asset: 'assets/icons/maps.svg',
              semantic: 'Map',
              selected: selected == GameNavTab.map,
              onTap: () => _onSelect(context, GameNavTab.map),
              color: fg,
            ),
            _NavBtn(
              asset: 'assets/icons/book.svg',
              semantic: 'Game Info',
              selected: selected == GameNavTab.info,
              onTap: () => _onSelect(context, GameNavTab.info),
              color: fg,
            ),
          ],
        ),
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
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Semantics(
          label: semantic,
          button: true,
          selected: selected,
          child: Opacity(
            opacity: selected ? 1.0 : 0.65,
            child: Center(
              child: SvgPicture.asset(asset, width: 28, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
