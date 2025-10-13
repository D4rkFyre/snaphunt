// lib/screens/in_app_camera_no_clue_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class InAppCameraNoClueScreen extends StatefulWidget {
  const InAppCameraNoClueScreen({super.key});

  @override
  State<InAppCameraNoClueScreen> createState() => _InAppCameraNoClueScreenState();
}

class _InAppCameraNoClueScreenState extends State<InAppCameraNoClueScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _busy = true;
  bool _permissionGranted = false;

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

    await _startController(_pickBackOrFirst());
    if (!mounted) return;
    setState(() => _busy = false);
  }

  CameraDescription? _pickBackOrFirst() {
    if (_cameras == null || _cameras!.isEmpty) return null;
    final backs = _cameras!.where((c) => c.lensDirection == CameraLensDirection.back);
    if (backs.isNotEmpty) return backs.first;
    return _cameras!.first; // emulator fallback
  }

  Future<void> _startController(CameraDescription? cam) async {
    if (cam == null) return;
    final old = _controller;
    _controller = CameraController(
      cam,
      ResolutionPreset.high, // lower if your scorer needs smaller files
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
      final out = File('${dir.path}/snaphunt_host_${DateTime.now().millisecondsSinceEpoch}.jpg');
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

  @override
  Widget build(BuildContext context) {
    final camReady = _controller?.value.isInitialized ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: camReady
                  ? CameraPreview(_controller!)
                  : const Center(child: CircularProgressIndicator()),
            ),
            // Top bar (close only — no flip)
            Positioned(
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
                ],
              ),
            ),
            // Bottom shutter
            Positioned(
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
            ),
            if (_busy && camReady)
              const Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
