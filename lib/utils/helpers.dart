import 'package:intl/intl.dart';

class Helpers {
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
