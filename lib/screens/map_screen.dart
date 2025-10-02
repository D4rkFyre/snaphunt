// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snaphunt/widgets/game_nav_bar.dart';

class MapScreen extends StatelessWidget {
  final String gameId;
  const MapScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: const GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(37.7749, -122.4194), // placeholder
          zoom: 12,
        ),
      ),
      bottomNavigationBar: GameNavBar(current: GameNavTab.map, gameId: gameId),
    );
  }
}
