import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import 'api_service.dart';

/// Outcome of changing the profile photo.
class ProfilePhotoResult {
  /// True only once the server has stored the file.
  final bool success;
  final String message;

  /// The picked file on this device, shown while the upload is in flight.
  final String localPath;

  /// Where the server stored it. Null when the upload did not succeed.
  final String? serverPhoto;

  const ProfilePhotoResult({
    required this.success,
    required this.message,
    required this.localPath,
    this.serverPhoto,
  });
}

/// Single place that changes a user's avatar.
///
/// The screen and the settings page each had their own picker, and only one of
/// them uploaded — the other saved to SharedPreferences and reported success,
/// so the photo existed on one handset and nowhere else. Both now go through
/// here, so the photo always reaches the server and follows the account.
class ProfilePhotoService {
  /// Picks an image and uploads it. Returns null if the user cancelled.
  static Future<ProfilePhotoResult?> pickAndUpload(ImagePicker picker) async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 80,
    );
    if (image == null) return null;

    final prefs = await SharedPreferences.getInstance();
    // Kept only as a placeholder until the server copy is available.
    await prefs.setString('profile_image_path', image.path);

    try {
      final res = await ApiService().updateProfilePhoto(File(image.path));

      if (res['success'] != true) {
        return ProfilePhotoResult(
          success: false,
          message: res['message']?.toString() ?? 'Photo upload failed',
          localPath: image.path,
        );
      }

      // The backend returns where it stored the file so the new avatar can be
      // shown without a second round trip.
      final stored = (res['profile_photo_url'] ?? res['profile_photo'])?.toString();
      if (stored != null && stored.isNotEmpty) {
        await cacheServerPhoto(prefs, stored);
      }

      return ProfilePhotoResult(
        success: true,
        message: res['message']?.toString() ?? 'Profile photo updated',
        localPath: image.path,
        serverPhoto: stored,
      );
    } catch (e) {
      return ProfilePhotoResult(
        success: false,
        message: 'Upload failed — the photo is saved on this device only.',
        localPath: image.path,
      );
    }
  }

  /// Mirrors the stored path into the cached user record, so the avatar survives
  /// a restart and every screen reading that record picks it up.
  static Future<void> cacheServerPhoto(
      SharedPreferences prefs, String photo) async {
    final raw = prefs.getString(AppConstants.userKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        decoded['profile_photo'] = photo;
        await prefs.setString(AppConstants.userKey, jsonEncode(decoded));
      }
    } catch (_) {
      // A corrupt cache is not worth failing an otherwise successful upload.
    }
  }
}
