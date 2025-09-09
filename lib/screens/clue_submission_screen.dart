// lib/screens/photo_tasks_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoTasksScreen extends StatefulWidget {
  const PhotoTasksScreen({super.key});

  @override
  State<PhotoTasksScreen> createState() => _PhotoTasksScreenState();
}

class _PhotoTasksScreenState extends State<PhotoTasksScreen> {
  final ImagePicker _picker = ImagePicker();
  final int _taskCount = 6;

  // Simulated upload so you can see the modal UX.
  static const bool _simulateUpload = true;

  late final List<_TaskState> _tasks = List.generate(
    _taskCount,
        (_) => _TaskState(promptAsset: 'assets/pictures/picture.png'),
  );

  Future<void> _submit(int index) async {
    if (_tasks[index].done) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF3E2C8B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            const Divider(height: 0, color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.white),
              title: const Text('Take a Photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (file == null) return;

    _showUploadingDialog();

    try {
      // Simulate upload
      await Future.delayed(const Duration(milliseconds: 1200));

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss modal

      setState(() {
        _tasks[index].submission = file;
        _tasks[index].done = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submission saved.')),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss modal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  void _showUploadingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _UploadingDialog(),
    );
  }

  void _openFullScreenAsset(String assetPath, String heroTag) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            _FullScreenPhoto(assetPath: assetPath, heroTag: heroTag),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _openFullScreenFile(String filePath, String heroTag) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            _FullScreenPhoto(filePath: filePath, heroTag: heroTag),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF3E2C8B); // solid dark background
    const accent = Color(0xFFFFC943); // your yellow accent

    return Scaffold(
      backgroundColor: darkBg,
      // Right-side drawer for profile/settings
      endDrawer: Drawer(
        backgroundColor: darkBg,
        child: ListView(
          padding: EdgeInsets.zero,
          children: const [
            DrawerHeader(
              decoration: BoxDecoration(color: accent),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.person, color: Colors.white),
              title: Text('Profile', style: TextStyle(color: Colors.white)),
            ),
            ListTile(
              leading: Icon(Icons.settings, color: Colors.white),
              title: Text('Settings', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),

      // FIXED top bar (standard AppBar is pinned at top by default)
      // solid background, centered title, back arrow, and trailing profile icon
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: const Text(
          'Clues',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600, // medium bold
          ),
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.person, color: Colors.white),
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),

      // Content scrolls under the fixed app bar
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final task = _tasks[index];
          final isDone = task.done;
          final heroPrompt = 'prompt-$index';
          final heroSubmission = 'submission-$index';

          return Card(
            color: const Color(0xFF5D4BB2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Prompt image (tap to expand)
                  GestureDetector(
                    onTap: () => _openFullScreenAsset(task.promptAsset, heroPrompt),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Hero(
                          tag: heroPrompt,
                          child: Image.asset(
                            task.promptAsset,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text(
                                'Missing asset: assets/pictures/picture.png',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Submit / Done button (accent → green when done)
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isDone ? null : () => _submit(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDone ? Colors.greenAccent : accent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: Text(isDone ? 'Done' : 'Submit'),
                    ),
                  ),

                  // Tiny preview row (only after submission)
                  if (isDone && task.submission != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Tappable thumbnail of user's submission
                        GestureDetector(
                          onTap: () => _openFullScreenFile(
                              task.submission!.path, heroSubmission),
                          child: Hero(
                            tag: heroSubmission,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(task.submission!.path),
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Your photo (tap to expand)',
                            style: TextStyle(color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'View full size',
                          onPressed: () => _openFullScreenFile(
                              task.submission!.path, heroSubmission),
                          icon: const Icon(Icons.open_in_full,
                              color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TaskState {
  _TaskState({required this.promptAsset});
  final String promptAsset;
  bool done = false;
  XFile? submission;
}

/// Centered uploading popup
class _UploadingDialog extends StatelessWidget {
  const _UploadingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF3E2C8B),
      insetPadding: const EdgeInsets.symmetric(horizontal: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Uploading your photo....',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Full-screen image viewer (asset or file) with pinch-to-zoom
class _FullScreenPhoto extends StatelessWidget {
  const _FullScreenPhoto({
    required this.heroTag,
    this.assetPath,
    this.filePath,
  }) : assert(assetPath != null || filePath != null, 'Provide an image source');

  final String heroTag;
  final String? assetPath;
  final String? filePath;

  @override
  Widget build(BuildContext context) {
    final Widget image = assetPath != null
        ? Image.asset(assetPath!, fit: BoxFit.contain)
        : Image.file(File(filePath!), fit: BoxFit.contain);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: image,
          ),
        ),
      ),
    );
  }
}
