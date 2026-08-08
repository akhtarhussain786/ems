import 'dart:io';
import 'package:flutter/widgets.dart';
import 'constants.dart';

/// Resolves which avatar to show.
///
/// The photo used to be read only from a locally picked file, so signing in on
/// a second device showed the placeholder even though the account had a photo.
/// The server copy is the account's real avatar; the local file is only a
/// stand-in for the device that picked it, shown until the upload lands.
class ProfileImage {
  /// Absolute URL for a stored `profile_photo` value, or null when there isn't one.
  static String? urlFor(dynamic storedPath) {
    if (storedPath == null) return null;

    final path = storedPath.toString().trim();
    if (path.isEmpty || path == 'null') return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;

    return '${AppConstants.baseUrl}/${path.replaceFirst(RegExp(r'^/+'), '')}';
  }

  /// Server copy first, then a local file that is known to exist.
  /// Returns null when neither is available, so callers show their initial.
  static ImageProvider? resolve({dynamic serverPhoto, String? localPath}) {
    final url = urlFor(serverPhoto);
    if (url != null) return NetworkImage(url);

    if (localPath != null && localPath.isNotEmpty) {
      return FileImage(File(localPath));
    }
    return null;
  }
}
