import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

/// A check-in used to carry the same photo twice — as a multipart file and as
/// base64 — and the server read only the base64, discarding the file unread.
/// On a field connection the wasted bytes pushed the request past the timeout
/// and the attendance was simply lost. These pin the size arithmetic.
void main() {
  /// base64 grows by 4 bytes for every 3, plus padding.
  int base64Size(int bytes) => base64Encode(List<int>.filled(bytes, 0)).length;

  group('check-in upload size', () {
    test('base64 is about a third larger than the raw file', () {
      expect(base64Size(30000) / 30000, closeTo(1.333, 0.01));
    });

    test('the median photo: sending both was 2.3x what was needed', () {
      const raw = 29 * 1024;                 // median on the server
      final both = raw + base64Size(raw);    // old behaviour
      final now = raw;                       // file only
      expect(both / now, closeTo(2.33, 0.05));
      expect(now, lessThan(both));
    });

    test('the worst observed photo drops well below the old total', () {
      const raw = 1163 * 1024;               // largest stored photo
      final both = raw + base64Size(raw);
      expect(both, greaterThan(2700 * 1024), reason: 'over 2.7MB in one request');
      expect(raw, lessThan(1200 * 1024));
    });

    test('a 90s budget carries the median photo on a slow uplink', () {
      const raw = 29 * 1024;
      const slowUplinkBytesPerSec = 20 * 1024;   // ~160 kbit/s, poor mobile data
      expect(raw / slowUplinkBytesPerSec, lessThan(90));
    });

    test('15s could not carry the old double payload at that speed', () {
      const raw = 288 * 1024;                    // employee 18's average
      final both = raw + base64Size(raw);
      const slowUplinkBytesPerSec = 20 * 1024;
      expect(both / slowUplinkBytesPerSec, greaterThan(15),
          reason: 'this is the timeout that was being hit');
      expect(raw / slowUplinkBytesPerSec, lessThan(90),
          reason: 'and the same photo now fits the new budget');
    });
  });
}
