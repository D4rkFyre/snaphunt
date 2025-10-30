// lib/screens/in_app_camera_pip_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

enum PipMode { window, maximized, minimized }
enum _ResizeAnchor { topLeft, topRight, bottomLeft, bottomRight }

class InAppCameraPipScreen extends StatefulWidget {
  final String hostClueImageUrl;
  final bool clueAbove; // legacy header mode


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
  FlashMode _flashMode = FlashMode.off;

  // PiP core state
  PipMode _mode = PipMode.minimized;        // start minimized per request
  Offset _pipOffset = const Offset(16, 80); // top-left of the window
  double? _hostAspect;                      // width / height (null => 4/3)
  double _pipWidth = 260;                   // height derived by aspect

  // Sizing thresholds
  // We keep a small safety floor, but actual min width is computed dynamically.
  final double _minWidthBase = 200;         // conservative floor
  final double _maxWidthFactor = 0.9;       // 90% of screen when maximizing

  // Restore snapshot for Windows-like maximize/restore & minimize/restore
  Offset? _restoreOffset;
  double? _restoreWidth;
  bool _hasOpenedOnce = false;              // first-tap opens maximized

  // Minimized chip placement
  static const double _bubbleBottomPad = 24; // keep above shutter a bit

  @override
  void initState() {
    super.initState();
    _initOnce();
    _probeHostImageAspect();
  }

  Future<void> _initOnce() async {
    setState(() => _busy = true);

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) Navigator.pop(context, null);
      return;
    }

    try {
      _cameras = await availableCameras();
    } catch (_) {
      _cameras = const [];
    }

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
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await _controller!.initialize();
    } finally {
      await old?.dispose();
    }
  }

  Future<void> _probeHostImageAspect() async {
    try {
      final provider = NetworkImage(widget.hostClueImageUrl);
      final stream = provider.resolve(const ImageConfiguration());
      final c = Completer<ImageInfo>();
      late final ImageStreamListener listener;
      listener = ImageStreamListener((info, _) {
        c.complete(info);
        stream.removeListener(listener);
      }, onError: (e, s) {
        if (!c.isCompleted) c.completeError(e, s);
        stream.removeListener(listener);
      });
      stream.addListener(listener);

      final info = await c.future;
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (w > 0 && h > 0 && mounted) {
        setState(() => _hostAspect = w / h);
      }
    } catch (_) {/* fallback to 4/3 */}
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final newMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;

    try {
      await _controller!.setFlashMode(newMode);
      if (mounted) setState(() => _flashMode = newMode);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle flash: $e')),
      );
    }
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

  // ===== Helpers =====
  double get _aspect => _hostAspect ?? (4 / 3);

  // Adaptive minimum width: enough room for big icons + spacing + some label,
  // while respecting a conservative base floor.
  double _effectiveMinWidth(BuildContext context) {
    final textScale = MediaQuery.of(context).textScaleFactor;

    const iconSize = 26.0; // min/max icons
    const hitPad   = 10.0; // padding around each icon in _chromeAction
    const inter    = 14.0; // spacing between icons
    const sidePad  = 20.0; // left+right row padding (10 + 10)

    // Two large buttons:
    final iconGroup = 2 * (iconSize + hitPad * 2) + inter; // 106 px

    // Reasonable space for label, scaled with a11y text size:
    final labelMin = 70.0 * textScale;

    const buffer = 8.0;

    final needed = iconGroup + sidePad + labelMin + buffer;
    return needed > _minWidthBase ? needed : _minWidthBase;
  }

  Offset _clampOffset(BoxConstraints b, Offset o, double w, double aspect) {
    final h = w / aspect;
    final maxX = b.maxWidth - w - 12;
    final maxY = b.maxHeight - h - 12;
    return Offset(
      o.dx.clamp(12.0, maxX),
      o.dy.clamp(60.0, maxY), // keep out of top bar
    );
  }

  // Compute "maximized target" and a good "windowed default" (for first restore)
  ({double maxW, double maxH, Offset centeredOffset, double defaultWindowW, Offset defaultWindowOffset})
  _maxTargets(BoxConstraints b) {
    final aspect = _aspect;
    final minW = _effectiveMinWidth(context);

    final maxW = b.maxWidth * _maxWidthFactor;
    final maxH = b.maxHeight * _maxWidthFactor;
    final wIfH = maxH * aspect;
    final targetW = wIfH <= maxW ? wIfH : maxW;
    final targetH = targetW / aspect;
    final centered = Offset((b.maxWidth - targetW) / 2, (b.maxHeight - targetH) / 2);

    final defaultWindowW = (b.maxWidth * 0.6).clamp(minW, b.maxWidth * _maxWidthFactor);
    final defaultWindowH = defaultWindowW / aspect;
    final defaultCentered =
    Offset((b.maxWidth - defaultWindowW) / 2, (b.maxHeight - defaultWindowH) / 2);

    return (maxW: targetW, maxH: targetH, centeredOffset: centered, defaultWindowW: defaultWindowW, defaultWindowOffset: defaultCentered);
  }

  // ===== Controls =====
  void _minimize() {
    // snapshot current state for restore
    _restoreWidth  = _pipWidth;
    _restoreOffset = _pipOffset;
    setState(() => _mode = PipMode.minimized);
  }

  void _toggleMaximize(BoxConstraints bounds) {
    final aspect = _aspect;
    final minW = _effectiveMinWidth(context);

    if (_mode == PipMode.maximized) {
      // Restore to previous custom size/position
      setState(() {
        _mode = PipMode.window;
        if (_restoreWidth != null && _restoreOffset != null) {
          _pipWidth = _restoreWidth!.clamp(minW, bounds.maxWidth * _maxWidthFactor);
          _pipOffset = _clampOffset(bounds, _restoreOffset!, _pipWidth, aspect);
        }
      });
    } else {
      // Snapshot then center & maximize (~90% of screen)
      final t = _maxTargets(bounds);
      setState(() {
        _restoreWidth  = _restoreWidth  ?? (bounds.maxWidth * 0.6).clamp(minW, bounds.maxWidth * _maxWidthFactor);
        _restoreOffset = _restoreOffset ?? t.defaultWindowOffset;
        _pipWidth = t.maxW;
        _pipOffset = t.centeredOffset;
        _mode = PipMode.maximized;
      });
    }
  }

  // Corner resizing with aspect lock
  void _resizeFromCorner(_ResizeAnchor anchor, DragUpdateDetails d, BoxConstraints b) {
    final aspect = _aspect;
    final minW = _effectiveMinWidth(context);

    final x = _pipOffset.dx;
    final y = _pipOffset.dy;
    final w = _pipWidth;
    final h = w / aspect;

    final dx = d.delta.dx;
    final dy = d.delta.dy;

    // Convert both axes to "width-equivalent" deltas for aspect-locked sizing.
    double dWFromDx, dWFromDy;
    switch (anchor) {
      case _ResizeAnchor.bottomRight:
        dWFromDx = dx;            // → grows to the right
        dWFromDy = dy * aspect;   // → grows downward
        break;
      case _ResizeAnchor.topRight:
        dWFromDx = dx;            // → grows to the right
        dWFromDy = -dy * aspect;  // dragging down increases height → width grows
        break;
      case _ResizeAnchor.bottomLeft:
        dWFromDx = -dx;           // dragging left increases width
        dWFromDy = dy * aspect;   // dragging down increases height → width grows
        break;
      case _ResizeAnchor.topLeft:
        dWFromDx = -dx;           // dragging left increases width
        dWFromDy = -dy * aspect;  // dragging up increases height → width grows
        break;
    }

    // Pick whichever movement is dominant to feel natural.
    final chosenDeltaW = (dWFromDx.abs() >= dWFromDy.abs()) ? dWFromDx : dWFromDy;

    // New size (aspect-locked via width), clamped to adaptive min/max.
    final newW = (w + chosenDeltaW).clamp(minW, b.maxWidth * _maxWidthFactor);
    final newH = newW / aspect;

    // Adjust top-left so the dragged corner stays under the finger.
    double newX = x, newY = y;
    switch (anchor) {
      case _ResizeAnchor.bottomRight:
      // top-left stays fixed
        break;

      case _ResizeAnchor.topRight: {
        // top-right corner moves with the finger
        final right = x + w + dx;
        newX = right - newW;
        newY = y + dy;
        break;
      }

      case _ResizeAnchor.bottomLeft: {
        // bottom-left corner moves with the finger
        final bottom = y + h + dy;
        newX = x + dx;
        newY = bottom - newH;
        break;
      }

      case _ResizeAnchor.topLeft:
      // top-left corner moves with the finger
        newX = x + dx;
        newY = y + dy;
        break;
    }

    setState(() {
      _pipWidth  = newW;
      _pipOffset = _clampOffset(b, Offset(newX, newY), newW, aspect);
      // If user resizes while maximized, it's now a custom window state.
      if (_mode == PipMode.maximized) _mode = PipMode.window;
    });
  }

  // ===== UI Pieces =====
  Widget _hostThumb() {
    final aspect = _aspect;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: aspect,
        child: Container(
          color: Colors.black.withValues(alpha: 0.25), // subtle letterbox
          alignment: Alignment.center,
          child: Image.network(
            widget.hostClueImageUrl,
            fit: BoxFit.contain, // full image visible, no crop
            loadingBuilder: (c, w, p) =>
            p == null ? w : const Center(child: CircularProgressIndicator()),
            errorBuilder: (c, e, s) => const ColoredBox(color: Colors.black26),
          ),
        ),
      ),
    );
  }

  // Minimized chip at bottom-left: icon + "Host image"
  Widget _minimizedIcon(BoxConstraints bounds) {
    return Positioned(
      left: 12,
      bottom: _bubbleBottomPad,
      child: GestureDetector(
        onTap: () {
          final t = _maxTargets(bounds);
          final minW = _effectiveMinWidth(context);
          setState(() {
            // First open → maximize & center; seed a default restore state
            if (!_hasOpenedOnce) {
              _restoreWidth  = t.defaultWindowW;
              _restoreOffset = t.defaultWindowOffset;
              _pipWidth      = t.maxW;
              _pipOffset     = t.centeredOffset;
              _mode = PipMode.maximized;
              _hasOpenedOnce = true;
              return;
            }
            // Subsequent opens → restore last custom window state (if any)
            _mode = PipMode.window;
            if (_restoreWidth != null && _restoreOffset != null) {
              final w = _restoreWidth!.clamp(minW, bounds.maxWidth * _maxWidthFactor);
              _pipWidth  = w;
              _pipOffset = _clampOffset(bounds, _restoreOffset!, w, _aspect);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade700, width: 1.4),
          ),
          child: const Row(
            children: [
              Icon(Icons.image_outlined, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Host image',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Resizable/movable window
  Widget _windowPip(BoxConstraints bounds) {
    final aspect = _aspect;

    // Keep visible if layout changes
    final clamped = _clampOffset(bounds, _pipOffset, _pipWidth, aspect);
    if (clamped != _pipOffset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _pipOffset = clamped);
      });
    }

    // Drag to move (pan)
    void onDrag(DragUpdateDetails d) {
      setState(() {
        _pipOffset = _clampOffset(bounds, _pipOffset + d.delta, _pipWidth, aspect);
      });
    }

    final height = _pipWidth / aspect;

    return Positioned(
      left: _pipOffset.dx,
      top: _pipOffset.dy,
      child: GestureDetector(
        onPanUpdate: onDrag,          // move whole window
        onDoubleTap: () => _toggleMaximize(bounds),
        child: Container(
          width: _pipWidth,
          height: height,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),                     // see-through
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700, width: 1.6),     // dark grey border
          ),
          child: Stack(
            children: [
              // Content
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 40, 10, 10), // room for titlebar
                  child: _hostThumb(),
                ),
              ),

              // Titlebar with big, spaced Min / Max (fat-finger friendly)
              Positioned(
                top: 4,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    const Text(
                      'Host clue',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    _chromeAction(
                      icon: Icons.remove, // thicker than minimize
                      tooltip: 'Minimize',
                      onTap: _minimize,
                    ),
                    const SizedBox(width: 14),
                    _chromeAction(
                      icon: _mode == PipMode.maximized
                          ? Icons.crop_square_rounded // "restore"
                          : Icons.check_box_outline_blank_rounded, // "maximize"
                      tooltip: _mode == PipMode.maximized ? 'Restore' : 'Maximize',
                      onTap: () => _toggleMaximize(bounds),
                    ),
                  ],
                ),
              ),

              // ── Invisible corner resize hit-areas (all four corners) ───
              // (No visible arrows; drag any corner to resize.)
              Positioned(
                left: 0, top: 0,
                child: _cornerHit(onPanUpdate: (d) => _resizeFromCorner(_ResizeAnchor.topLeft, d, bounds)),
              ),
              Positioned(
                right: 0, top: 0,
                child: _cornerHit(onPanUpdate: (d) => _resizeFromCorner(_ResizeAnchor.topRight, d, bounds)),
              ),
              Positioned(
                left: 0, bottom: 0,
                child: _cornerHit(onPanUpdate: (d) => _resizeFromCorner(_ResizeAnchor.bottomLeft, d, bounds)),
              ),
              Positioned(
                right: 0, bottom: 0,
                child: _cornerHit(onPanUpdate: (d) => _resizeFromCorner(_ResizeAnchor.bottomRight, d, bounds)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Big, easy-to-tap titlebar icon
  Widget _chromeAction({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final btn = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),        // big hit target
        child: Icon(icon, size: 26, color: Colors.white),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip, child: btn);
  }

  // Invisible corner hit target for resizing
  Widget _cornerHit({required void Function(DragUpdateDetails) onPanUpdate}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: onPanUpdate,
      child: const SizedBox(width: 28, height: 28), // generous touch target
    );
  }

  // ===== Scaffold/UI =====
  @override
  Widget build(BuildContext context) {
    final camReady = _controller?.value.isInitialized ?? false;

    // Optional legacy header mode
    if (widget.clueAbove) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    const Icon(Icons.photo, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text('Host clue', style: TextStyle(color: Colors.white)),
                    const Spacer(),
                    SizedBox(width: 96, child: _hostThumb()),
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

    // Default: camera with pip
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned.fill(
                  child: camReady
                      ? CameraPreview(_controller!)
                      : const Center(child: CircularProgressIndicator()),
                ),
                if (_mode == PipMode.minimized)
                  _minimizedIcon(constraints)
                else
                  _windowPip(constraints),
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
          // no flip button
          IconButton(
            icon: Icon(
              _flashMode == FlashMode.off
                  ? Icons.flash_off
                  : Icons.flash_on,
              color: Colors.white,
            ),
            onPressed: _toggleFlash,
          ),
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
