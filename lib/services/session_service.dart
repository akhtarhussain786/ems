import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const Duration sessionTimeout = Duration(hours: 12);
  static const String loginTimestampKey = 'login_timestamp';

  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(loginTimestampKey);

    if (timestamp == null) return false;

    final loginTime = DateTime.parse(timestamp);
    final currentTime = DateTime.now();
    final difference = currentTime.difference(loginTime);

    return difference < sessionTimeout;
  }

  static Future<Duration> getRemainingSessionTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(loginTimestampKey);

    if (timestamp == null) return Duration.zero;

    final loginTime = DateTime.parse(timestamp);
    final currentTime = DateTime.now();
    final difference = currentTime.difference(loginTime);

    if (difference >= sessionTimeout) return Duration.zero;

    return sessionTimeout - difference;
  }
}