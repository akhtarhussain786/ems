import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages first-time login onboarding status per user.
///
/// Ensures onboarding is shown only once per user account on a device,
/// without interfering with session management, JWT tokens, remember me, or logout.
class OnboardingService {
  static const String _keyPrefix = 'onboarding_completed_';

  /// Returns true if the given [userId] has completed the onboarding flow on this device.
  static Future<bool> hasCompletedOnboarding(String? userId) async {
    if (userId == null || userId.trim().isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix${userId.trim()}';
      return prefs.getBool(key) ?? false;
    } catch (e) {
      debugPrint('OnboardingService.hasCompletedOnboarding error: $e');
      return false;
    }
  }

  /// Marks onboarding as completed for the given [userId].
  static Future<void> setOnboardingCompleted(String? userId) async {
    if (userId == null || userId.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix${userId.trim()}';
      await prefs.setBool(key, true);
    } catch (e) {
      debugPrint('OnboardingService.setOnboardingCompleted error: $e');
    }
  }

  /// Resets onboarding status for testing / debug purposes.
  static Future<void> resetOnboarding(String? userId) async {
    if (userId == null || userId.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix${userId.trim()}';
      await prefs.remove(key);
    } catch (e) {
      debugPrint('OnboardingService.resetOnboarding error: $e');
    }
  }
}
