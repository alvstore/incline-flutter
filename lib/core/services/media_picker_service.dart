import '../theme/incline_colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Camera and Gallery Avatar Selection Service
/// Enables members to update profile avatars from camera capture or photo gallery.
class MediaPickerService {
  static final MediaPickerService instance = MediaPickerService._internal();
  MediaPickerService._internal();

  final ImagePicker _picker = ImagePicker();

  /// Prompts the user to pick an image from Camera or Gallery via an M3 bottom sheet
  Future<XFile?> pickAvatarImage(BuildContext context) async {
    ImageSource? source;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Update Member Avatar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose an image for your Incline club pass & member profile',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: InclineColors.accentOrange,
                  foregroundColor: Colors.black,
                  child: Icon(Icons.camera_alt_rounded, size: 20),
                ),
                title: const Text('Take a Photo (Camera)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Capture using device camera', style: TextStyle(fontSize: 11)),
                onTap: () {
                  source = ImageSource.camera;
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: InclineColors.cardSurface,
                  foregroundColor: InclineColors.accentOrange,
                  child: Icon(Icons.photo_library_rounded, size: 20),
                ),
                title: const Text('Choose from Photos (Gallery)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Select from photo library', style: TextStyle(fontSize: 11)),
                onTap: () {
                  source = ImageSource.gallery;
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return null;

    try {
      final file = await _picker.pickImage(
        source: source!,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.front,
      );
      return file;
    } catch (e) {
      debugPrint('[INCLINE] pickAvatarImage error: $e');
      return null;
    }
  }

  /// Directly captures a photo from the camera
  Future<XFile?> takePhoto() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.front,
      );
    } catch (e) {
      debugPrint('[INCLINE] takePhoto error: $e');
      return null;
    }
  }

  /// Directly selects an image from the device gallery
  Future<XFile?> chooseFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
    } catch (e) {
      debugPrint('[INCLINE] chooseFromGallery error: $e');
      return null;
    }
  }
}
