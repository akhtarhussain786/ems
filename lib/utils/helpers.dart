import 'package:intl/intl.dart';

class Helpers {
  /// Reads a number that arrived from the API.
  ///
  /// MySQL returns DECIMAL columns as strings, and PHP's json_encode passes
  /// them through as JSON strings — so `amount` arrives as "10000.00", not
  /// 10000.0. Calling a num method on that throws NoSuchMethodError at build
  /// time and takes the whole screen down with a red error box.
  ///
  /// Anything unreadable, including null, counts as zero: a missing figure
  /// should render as 0 rather than crash the page it appears on.
  static num asNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value.trim()) ?? 0;
    return 0;
  }

  /// The same value as a double, for arithmetic and toStringAsFixed.
  static double asDouble(dynamic value) => asNum(value).toDouble();

  /// The same value as an int, for counts and kilometre readings.
  static int asInt(dynamic value) => asNum(value).round();


  static String formatTime(String? dateTime) {
    if (dateTime == null) return '--:--';
    try {
      final dt = DateTime.parse(dateTime);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '--:--';
    }
  }

  static String formatDate(String? date) {
    if (date == null) return '--';
    try {
      final dt = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return '--';
    }
  }

  static String formatDuration(String? time) {
    if (time == null || time == '00:00:00') return '0h 0m';
    final parts = time.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return '${h}h ${m}m';
  }

  static String getStatusColor(String status) {
    switch (status) {
      case 'present':
        return '#22c55e';
      case 'late':
        return '#f59e0b';
      case 'half-day':
        return '#ef4444';
      case 'absent':
        return '#dc2626';
      default:
        return '#6b7280';
    }
  }

  static String getDayOfWeek(String date) {
    try {
      final dt = DateTime.parse(date);
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return weekdays[dt.weekday - 1];
    } catch (_) {
      return '';
    }
  }

  static String getStatusEmoji(String status) {
    switch (status) {
      case 'present':
        return 'P';
      case 'late':
        return 'L';
      case 'half-day':
        return 'HD';
      case 'absent':
        return 'A';
      default:
        return '-';
    }
  }
}
