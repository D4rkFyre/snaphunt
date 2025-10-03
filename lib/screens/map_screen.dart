// lib/screens/map_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'package:snaphunt/widgets/game_nav_bar.dart';
import 'package:snaphunt/services/firestore_refs.dart';

class MapScreen extends StatefulWidget {
  final String gameId;
  const MapScreen({super.key, required this.gameId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller =
  Completer<GoogleMapController>();

  bool _locationAllowed = false;
  bool _centering = false;
  Marker? _meMarker;
  StreamSubscription<Position>? _posSub;

  // Track last fitted area to avoid refitting every frame.
  double? _lastCenterLat, _lastCenterLng, _lastRadiusMeters;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final allowed = await _ensurePermission();
    if (!mounted) return;
    setState(() => _locationAllowed = allowed);

    if (allowed) {
      // Seed with current position…
      final current = await _getCurrentPosition();
      if (mounted && current != null) {
        _updateMeMarker(LatLng(current.latitude, current.longitude));
      }
      // …and keep it updated via stream.
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 3, // meters
        ),
      ).listen((pos) {
        if (!mounted) return;
        _updateMeMarker(LatLng(pos.latitude, pos.longitude));
      });
    }
  }

  void _updateMeMarker(LatLng p) {
    setState(() {
      _meMarker = Marker(
        markerId: const MarkerId('me'),
        position: p,
      );
    });
  }

  Future<void> _centerOnMe() async {
    if (_meMarker == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available yet.')),
      );
      return;
    }
    setState(() => _centering = true);
    try {
      final controller = await _controller.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _meMarker!.position, zoom: 16),
        ),
      );
    } finally {
      if (mounted) setState(() => _centering = false);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreRefs.gameDoc(db, widget.gameId).snapshots(),
        builder: (context, gameSnap) {
          final gameData = gameSnap.data?.data();

          final double? centerLat =
          (gameData?['centerLat'] as num?)?.toDouble();
          final double? centerLng =
          (gameData?['centerLng'] as num?)?.toDouble();
          final double? radiusMeters =
          (gameData?['radiusMeters'] as num?)?.toDouble();

          // Fallback if no game area yet
          final initialTarget = (centerLat != null && centerLng != null)
              ? LatLng(centerLat, centerLng)
              : const LatLng(37.4220, -122.0841); // fallback
          final initialZoom =
          (radiusMeters != null) ? _zoomForRadius(radiusMeters) : 13.0;

          // Try to fit the camera to the circle when data is available/changes.
          if (centerLat != null &&
              centerLng != null &&
              radiusMeters != null) {
            _fitCameraToGameAreaIfNeeded(centerLat, centerLng, radiusMeters);
          }

          final circles = <Circle>{};
          if (centerLat != null && centerLng != null && radiusMeters != null) {
            circles.add(
              Circle(
                circleId: const CircleId('game_area'),
                center: LatLng(centerLat, centerLng),
                radius: radiusMeters,
                strokeWidth: 2,
                strokeColor: Colors.purple.withValues(alpha: 0.8),
                fillColor: Colors.purple.withValues(alpha: 0.15),
              ),
            );
          }

          // Only our “me” pin, if available (no clue markers/labels).
          final markers = <Marker>{
            if (_meMarker != null) _meMarker!,
          };

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialTarget,
                  zoom: initialZoom,
                ),
                myLocationEnabled: false, // we draw our own pin
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                markers: markers,
                circles: circles,
                onMapCreated: (controller) {
                  if (!_controller.isCompleted) _controller.complete(controller);
                },
              ),
              // Small top chip with radius info (low visual weight)
              if (radiusMeters != null)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Radius: ${radiusMeters.toStringAsFixed(0)} m',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'center_me',
        onPressed: _centering ? null : _centerOnMe,
        tooltip: 'Center on my location',
        child: _centering
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.my_location),
      ),
      bottomNavigationBar:
      GameNavBar(current: GameNavTab.map, gameId: widget.gameId),
    );
  }

  /// Fit camera to the game circle (center + radius) if it changed since last fit.
  Future<void> _fitCameraToGameAreaIfNeeded(
      double centerLat,
      double centerLng,
      double radiusMeters,
      ) async {
    // Avoid repeated fits unless the area changed meaningfully.
    const epsilon = 0.000001; // ~0.1m latitude-scale
    final sameCenter = (_lastCenterLat != null &&
        _lastCenterLng != null &&
        (centerLat - _lastCenterLat!).abs() < epsilon &&
        (centerLng - _lastCenterLng!).abs() < epsilon);
    final sameRadius =
    (_lastRadiusMeters != null &&
        (radiusMeters - _lastRadiusMeters!).abs() < 0.5);

    if (sameCenter && sameRadius) return;

    final controller = await _controller.future;

    final bounds = _boundsFromCircle(centerLat, centerLng, radiusMeters);

    // Apply a little padding so the circle edge is visible.
    const padding = 48.0;

    try {
      await controller.moveCamera(
        CameraUpdate.newLatLngBounds(bounds, padding),
      );
      _lastCenterLat = centerLat;
      _lastCenterLng = centerLng;
      _lastRadiusMeters = radiusMeters;
    } catch (_) {
      // If the map hasn't fully laid out yet, retry on next frame.
      // (Rare, but can happen on first build.)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await controller.moveCamera(
            CameraUpdate.newLatLngBounds(bounds, padding),
          );
          _lastCenterLat = centerLat;
          _lastCenterLng = centerLng;
          _lastRadiusMeters = radiusMeters;
        } catch (_) {
          // Swallow: if it still fails, user can use FAB; not a fatal error.
        }
      });
    }
  }

  /// Convert center + radius (meters) to a LatLngBounds box.
  LatLngBounds _boundsFromCircle(
      double centerLat,
      double centerLng,
      double radiusMeters,
      ) {
    // Earth radius (mean) in meters.
    const earthR = 6371008.8;

    final latRad = centerLat * math.pi / 180.0;

    // Latitude delta in degrees.
    final dLat = (radiusMeters / earthR) * (180.0 / math.pi);

    // Longitude delta in degrees (accounts for latitude).
    final dLng =
        (radiusMeters / (earthR * math.cos(latRad))) * (180.0 / math.pi);

    final sw = LatLng(centerLat - dLat, centerLng - dLng);
    final ne = LatLng(centerLat + dLat, centerLng + dLng);

    // Ensure bounds are valid (google_maps_flutter expects ne >= sw).
    final south = math.min(sw.latitude, ne.latitude);
    final north = math.max(sw.latitude, ne.latitude);
    final west = math.min(sw.longitude, ne.longitude);
    final east = math.max(sw.longitude, ne.longitude);

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  /// Request & check permission without blocking UI.
  Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (_) {
      return null;
    }
  }

  /// Heuristic zoom by radius (only used for the very first frame before fit).
  double _zoomForRadius(double radiusMeters) {
    final levels = [50, 100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600];
    final zooms = [18.0, 17.0, 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 9.0];
    for (int i = 0; i < levels.length; i++) {
      if (radiusMeters <= levels[i]) return zooms[i];
    }
    return 8.5;
  }
}
