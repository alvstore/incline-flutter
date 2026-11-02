import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Camera and Gallery Media Selection Service.
/// Note: Member profile photos are bound to optical turnstiles and MIPS biometric access,
/// so members cannot alter their biometric photo directly from the client.
class MediaPickerService {
  static final MediaPickerService instance = MediaPickerService._internal();
  MediaPickerService._internal();

  final ImagePicker _picker = ImagePicker();

  /// @deprecated Member profile photos are synchronized with MIPS turnstile hardware
  /// and must be captured and verified by front desk staff. Do not invoke for member profiles.
  @Deprecated('Member avatars are locked to staff biometric enrollment.')
  Future<XFile?> pickAvatarImage(BuildContext context) async {
    return null;
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
