// lib/screens/photo_tasks_screen.dart
import 'dart:io'; // for File
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// Uncomment when you want real uploads
// import 'package:firebase_storage/firebase_storage.dart';

class PhotoTasksScreen extends StatefulWidget {
  const PhotoTasksScreen({super.key});

  @override
  State<PhotoTasksScreen> createState() => _PhotoTasksScreenState();
}

class _PhotoTasksScreenState extends State<PhotoTasksScreen> {
  final ImagePicker _picker = ImagePicker();
  final int _taskCount = 6;

  // Toggle this to false and use the Firebase code in _uploadSubmission()
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

    // Show progress modal
    _showUploadingDialog();

    try {
      final url = await _uploadSubmission(file);

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss modal

      setState(() {
        _tasks[index].submission = file;
        _tasks[index].downloadUrl = url; // may be null if simulated
        _tasks[index].done = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submission saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss modal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  /// Shows a centered, blocking progress dialog.
  void _showUploadingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _UploadingDialog(),
    );
  }

  /// Upload logic. Returns a download URL if available, else null.
  Future<String?> _uploadSubmission(XFile file) async {
    if (_simulateUpload) {
      // Simulate a short upload so you can see the modal working.
      await Future.delayed(const Duration(milliseconds: 1200));
      return null;
    }

    // --- Real Firebase Storage upload (uncomment imports too) ---
    // final storage = FirebaseStorage.instance;
    // final ref = storage
    //     .ref()
    //     .child('submissions/${DateTime.now().millisecondsSinceEpoch}_${file.name}');
    // await ref.putFile(File(file.path));
    // final url = await ref.getDownloadURL();
    // return url;
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
    final accent = const Color(0xFFFFC943);
    return Scaffold(
      backgroundColor: const Color(0xFF3E2C8B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3E2C8B),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Photo Tasks',
          style: TextStyle(
            color: Colors.yellowAccent,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
                    onTap: () =>
                        _openFullScreenAsset(task.promptAsset, heroPrompt),
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

                  // Submit / Done button
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
                        // Tappable thumbnail
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
                        Expanded(
                          child: Text(
                            task.downloadUrl == null
                                ? 'Your photo (tap to expand)'
                                : 'Uploaded ✓ (tap to view)',
                            style: const TextStyle(color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _openFullScreenFile(
                              task.submission!.path, heroSubmission),
                          icon: const Icon(Icons.open_in_full,
                              color: Colors.white70),
                          tooltip: 'View full size',
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
  String? downloadUrl; // set if you do real uploads
}

/// Centered overlay dialog with spinner + text.
/// Blocks taps and auto-dismissed programmatically.
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
            SizedBox(height: 4),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Uploading your photo....',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Full-screen viewer with pinch-to-zoom (supports asset or file)
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
