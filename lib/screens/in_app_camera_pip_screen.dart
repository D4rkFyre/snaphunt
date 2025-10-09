import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class InAppCameraPipScreen extends StatefulWidget {
  final String hostClueImageUrl;
  final bool clueAbove; // kept for compatibility; if true shows a bar above instead of PiP

  const InAppCameraPipScreen({
    super.key,
    required this.hostClueImageUrl,
    this.clueAbove = false,
  });

  @override
  State<InAppCameraPipScreen> createState() => _InAppCameraPipScreenState();
}

class _InAppCameraPipScreenState extends State<InAppCameraPipScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _busy = true;
  bool _permissionGranted = false;

  // PiP state
  Offset _pipOffset = const Offset(12, 12); // from top-right later via layout calc
  double _pipWidth = 140.0;
  bool _pipLarge = false;

  // For dragging
  Offset? _dragStartGlobal;
  Offset? _dragStartPipOffset;

  @override
  void initState() {
    super.initState();
    _initOnce();
  }

  Future<void> _initOnce() async {
    setState(() => _busy = true);

    final status = await Permission.camera.request();
    _permissionGranted = status.isGranted;
    if (!_permissionGranted) {
      if (mounted) Navigator.pop(context, null);
      return;
    }

    try {
      _cameras = await availableCameras();
    } catch (_) {
      _cameras = const [];
    }

    // Pick a “back-ish” camera if available, otherwise first camera (emulators)
    final cam = _pickBackOrFirst();
    await _startController(cam);

    if (!mounted) return;
    setState(() => _busy = false);
  }

  CameraDescription? _pickBackOrFirst() {
    if (_cameras == null || _cameras!.isEmpty) return null;
    final backs = _cameras!.where((c) => c.lensDirection == CameraLensDirection.back);
    if (backs.isNotEmpty) return backs.first;
    return _cameras!.first;
  }

  Future<void> _startController(CameraDescription? cam) async {
    if (cam == null) return;
    final old = _controller;
    _controller = CameraController(
      cam,
      ResolutionPreset.high,     // lower if files are too big for your scorer
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await _controller!.initialize();
    } finally {
      await old?.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) return;
    try {
      setState(() => _busy = true);
      final shot = await _controller!.takePicture();
      final dir = await getTemporaryDirectory();
      final out = File('${dir.path}/snaphunt_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await out.writeAsBytes(await shot.readAsBytes());
      if (mounted) Navigator.pop(context, XFile(out.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e')),
      );
      setState(() => _busy = false);
    }
  }

  // ----- PiP helpers -----
  void _togglePipSize() {
    setState(() {
      _pipLarge = !_pipLarge;
      _pipWidth = _pipLarge ? 200.0 : 140.0;
    });
  }

  Widget _pipThumb() {
    // Keep aspect 4:3 for most clue photos; adjust if you store aspect somewhere
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.network(
          widget.hostClueImageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (c, w, p) => p == null ? w : const Center(child: CircularProgressIndicator()),
          errorBuilder: (c, e, s) => const ColoredBox(color: Colors.black26),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camReady = _controller?.value.isInitialized ?? false;

    // Optional layout: a bar above the camera (kept for compatibility)
    if (widget.clueAbove) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.photo, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text('Host clue', style: TextStyle(color: Colors.white)),
                    const Spacer(),
                    SizedBox(width: 120, child: _pipThumb()),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    camReady
                        ? CameraPreview(_controller!)
                        : const Center(child: CircularProgressIndicator()),
                    _topBar(),
                    _bottomShutter(),
                    if (_busy && camReady) _busyOverlay(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default: PiP draggable window over a corner
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Keep PiP within bounds after orientation/size changes
            final maxX = constraints.maxWidth - _pipWidth - 12;
            final maxY = constraints.maxHeight - (_pipWidth * 3 / 4) - 12; // 4:3 height
            final clamped = Offset(
              _pipOffset.dx.clamp(12.0, maxX),
              _pipOffset.dy.clamp(12.0 + 48.0, maxY), // +48 to avoid clashing with top bar
            );

            if (clamped != _pipOffset) {
              // ignore: invalid_use_of_protected_member
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _pipOffset = clamped);
              });
            }

            return Stack(
              children: [
                Positioned.fill(
                  child: camReady
                      ? CameraPreview(_controller!)
                      : const Center(child: CircularProgressIndicator()),
                ),

                // Draggable PiP
                Positioned(
                  left: _pipOffset.dx,
                  top: _pipOffset.dy,
                  child: GestureDetector(
                    onPanStart: (details) {
                      _dragStartGlobal = details.globalPosition;
                      _dragStartPipOffset = _pipOffset;
                    },
                    onPanUpdate: (details) {
                      if (_dragStartGlobal == null || _dragStartPipOffset == null) return;
                      final delta = details.globalPosition - _dragStartGlobal!;
                      setState(() {
                        _pipOffset = Offset(
                          (_dragStartPipOffset!.dx + delta.dx)
                              .clamp(12.0, maxX),
                          (_dragStartPipOffset!.dy + delta.dy)
                              .clamp(12.0 + 48.0, maxY),
                        );
                      });
                    },
                    onPanEnd: (_) {
                      _dragStartGlobal = null;
                      _dragStartPipOffset = null;
                    },
                    onDoubleTap: _togglePipSize, // quick size toggle
                    child: Container(
                      width: _pipWidth,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Host clue',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          _pipThumb(),
                        ],
                      ),
                    ),
                  ),
                ),

                _topBar(),
                _bottomShutter(),
                if (_busy && camReady) _busyOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topBar() {
    return Positioned(
      left: 8,
      right: 8,
      top: 8,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context, null),
          ),
          const Spacer(),
          // No flip button — per request
        ],
      ),
    );
  }

  Widget _bottomShutter() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 20,
      child: Center(
        child: GestureDetector(
          onTap: _busy ? null : _takePhoto,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _busyOverlay() {
    return const Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
