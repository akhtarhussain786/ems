import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yatharthems_apps/services/face_embedding_service.dart';

/// Covers the arithmetic the enrollment screen relies on to decide whether the
/// captures belong to the same person. The model itself needs a device, but
/// these are plain numbers, and getting them wrong would either reject genuine
/// employees or accept the wrong face — so they are worth pinning down.
void main() {
  final service = FaceEmbeddingService.instance;

  /// A deterministic pseudo-random vector, standing in for one face.
  List<double> face(int seed, {int dimensions = 128}) {
    final rng = Random(seed);
    return List.generate(dimensions, (_) => rng.nextDouble() * 2 - 1);
  }

  /// The same face captured again: the same vector with a little noise.
  List<double> again(List<double> v, int seed, {double noise = 0.15}) {
    final rng = Random(seed);
    return v.map((x) => x + (rng.nextDouble() * 2 - 1) * noise).toList();
  }

  group('similarity', () {
    test('a vector matches itself exactly', () {
      final a = face(1);
      expect(service.similarity(a, a), closeTo(1.0, 1e-9));
    });

    test('two captures of one face score well above the match threshold', () {
      final a = face(2);
      final score = service.similarity(a, again(a, 3))!;
      expect(score, greaterThan(0.9));
    });

    test('two different faces score near zero', () {
      final score = service.similarity(face(4), face(5))!;
      expect(score.abs(), lessThan(0.3));
    });

    test('vectors of different lengths are not comparable', () {
      expect(service.similarity(face(6), face(7, dimensions: 64)), isNull);
    });

    test('an empty vector is not comparable', () {
      expect(service.similarity([], []), isNull);
    });

    test('a vector with no direction is not comparable', () {
      final zero = List<double>.filled(128, 0.0);
      expect(service.similarity(zero, face(8)), isNull);
    });

    test('the result never escapes -1..1', () {
      final a = face(9);
      final opposite = a.map((x) => -x).toList();
      expect(service.similarity(a, opposite), closeTo(-1.0, 1e-9));
    });
  });

  group('averaging captures into one template', () {
    test('averaging one capture gives that capture back, normalised', () {
      final a = face(10);
      final result = service.averageEmbeddings([a])!;
      expect(service.similarity(result, a), closeTo(1.0, 1e-9));
    });

    test('the template is unit length, matching what the server stores', () {
      final template = service.averageEmbeddings([face(11), face(12)])!;
      final magnitude =
          sqrt(template.fold<double>(0, (sum, x) => sum + x * x));
      expect(magnitude, closeTo(1.0, 1e-9));
    });

    test('a template built from one face still matches that face', () {
      final a = face(13);
      final template =
          service.averageEmbeddings([a, again(a, 14), again(a, 15)])!;
      expect(service.similarity(template, again(a, 16))!, greaterThan(0.9));
      // ...and not somebody else.
      expect(service.similarity(template, face(17))!.abs(), lessThan(0.3));
    });

    test('captures of different lengths are refused rather than averaged', () {
      expect(
        service.averageEmbeddings([face(18), face(19, dimensions: 64)]),
        isNull,
      );
    });

    test('no captures gives no template', () {
      expect(service.averageEmbeddings([]), isNull);
    });
  });

  test('the model is reported unavailable until it is bundled', () {
    // The .tflite asset is not present in the test environment, so nothing
    // should claim face verification is ready.
    expect(service.isAvailable, isFalse);
  });
}
