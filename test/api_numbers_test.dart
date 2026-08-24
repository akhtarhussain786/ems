import 'package:flutter_test/flutter_test.dart';
import 'package:yatharthems_apps/utils/helpers.dart';

/// MySQL hands DECIMAL columns back as strings and PHP passes them straight
/// through, so money and distances reach the app as "10000.00", not 10000.0.
/// Every screen that showed a rupee figure crashed on that.
void main() {
  group('numbers arriving from the API', () {
    test('a DECIMAL column arrives as a string and still reads as a number', () {
      expect(Helpers.asDouble('10000.00'), 10000.0);
      expect(Helpers.asDouble('2.50'), 2.50);
    });

    test('the crash that started this: formatting the string as currency', () {
      // '₹${amount.toStringAsFixed(2)}' threw NoSuchMethodError on a String.
      expect(Helpers.asDouble('10000.00').toStringAsFixed(2), '10000.00');
    });

    test('a real number is passed through untouched', () {
      expect(Helpers.asDouble(1234.5), 1234.5);
      expect(Helpers.asNum(7), 7);
    });

    test('a missing figure reads as zero rather than crashing the screen', () {
      expect(Helpers.asDouble(null), 0.0);
      expect(Helpers.asDouble(''), 0.0);
      expect(Helpers.asDouble('not a number'), 0.0);
      expect(Helpers.asDouble([]), 0.0);
    });

    test('whitespace and negatives are read correctly', () {
      expect(Helpers.asDouble(' 42.75 '), 42.75);
      expect(Helpers.asDouble('-15.20'), -15.20);
    });

    test('asInt rounds, for kilometres and counts', () {
      expect(Helpers.asInt('12'), 12);
      expect(Helpers.asInt('12.6'), 13);
      expect(Helpers.asInt(null), 0);
    });

    test('a zero budget still divides safely, as the campaigns screen does', () {
      final budget = Helpers.asDouble('0.00');
      final results = Helpers.asDouble('5');
      final progress = budget > 0 ? (results / budget * 100).clamp(0, 100) : 0.0;
      expect(progress, 0.0);
    });
  });
}
