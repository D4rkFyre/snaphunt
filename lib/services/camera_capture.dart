// lib/services/camera_capture.dart
import 'package:image_picker/image_picker.dart';

class CameraCapture {
  CameraCapture._();

  /// Opens the device camera and returns the captured photo (or null if canceled).
  static Future<XFile?> takePhoto({
    int imageQuality = 85,      // Matches your current pipeline
    double maxWidth = 2000,     // Keeps images comfortably below scorer limits
    double maxHeight = 2000,
    CameraDevice preferred = CameraDevice.rear,
  }) async {
    final picker = ImagePicker();
    return picker.pickImage(
      source: ImageSource.camera,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      preferredCameraDevice: preferred,
    );
  }
}
