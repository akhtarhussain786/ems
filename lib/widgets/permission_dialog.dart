import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Reusable, modern permission-explanation dialog.
///
/// Shows a beautiful dialog explaining why a permission is needed before
/// triggering the native Android prompt. Handles granted, denied, and
/// permanently-denied states.
///
/// Returns `true` when the permission was granted, `false` otherwise.
Future<bool> requestPermissionWithExplanation(
  BuildContext context, {
  required Permission permission,
  required String title,
  required String message,
  required IconData icon,
  required String primaryButtonText,
}) async {
  // Already granted — nothing to do.
  if (await permission.isGranted) return true;

  // If permanently denied, go straight to the "Open Settings" dialog.
  if (await permission.isPermanentlyDenied) {
    if (!context.mounted) return false;
    return await _showPermanentlyDeniedDialog(context, title: title, message: message, icon: icon);
  }

  // Show the explanation dialog first.
  if (!context.mounted) return false;
  final shouldRequest = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PermissionExplanationDialog(
      title: title,
      message: message,
      icon: icon,
      primaryButtonText: primaryButtonText,
    ),
  );

  if (shouldRequest != true) return false;

  // Request the actual system permission.
  final status = await permission.request();

  if (status.isGranted) return true;

  // If the user denied and the OS won't ask again, offer "Open Settings".
  if (status.isPermanentlyDenied) {
    if (!context.mounted) return false;
    return await _showPermanentlyDeniedDialog(context, title: title, message: message, icon: icon);
  }

  return false;
}

// ---------------------------------------------------------------------------
// Permanently denied → offer to open system settings
// ---------------------------------------------------------------------------
Future<bool> _showPermanentlyDeniedDialog(
  BuildContext context, {
  required String title,
  required String message,
  required IconData icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.settings_rounded, color: Colors.orange[700], size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Permission Required',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This permission has been denied. Please enable it from your device settings to use this feature.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      'Not Now',
                      style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await openAppSettings();
                      if (ctx.mounted) Navigator.pop(ctx, false);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  return result == true;
}

// ---------------------------------------------------------------------------
// Explanation dialog shown BEFORE the native permission prompt
// ---------------------------------------------------------------------------
class _PermissionExplanationDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String primaryButtonText;

  const _PermissionExplanationDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.primaryButtonText,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A5F).withValues(alpha: 0.25),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      'Not Now',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      primaryButtonText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
