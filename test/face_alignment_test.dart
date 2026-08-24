import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// The alignment geometry, checked independently of the model.
///
/// MobileFaceNet expects the eyes level and in a fixed place in a 112x112
/// crop. Getting that transform wrong does not throw — it quietly produces
/// embeddings that do not match, which is exactly the failure that is hard to
/// notice. These tests check the arithmetic that _alignByEyes performs.
void main() {
  const canonEyeY = 51.69 / 112;
  const canonEyeX = 55.91 / 112;
  const canonEyeGap = 35.24 / 112;

  /// Mirrors _rotatePoint in the service.
  math.Point<double> rotatePoint(math.Point<double> p, math.Point<double> from,
      math.Point<double> to, double theta) {
    final dx = p.x - from.x, dy = p.y - from.y;
    final c = math.cos(theta), s = math.sin(theta);
    return math.Point<double>(to.x + dx * c - dy * s, to.y + dx * s + dy * c);
  }

  test('copyRotate turns clockwise for a positive angle', () {
    final im = img.Image(width: 3, height: 3);
    img.fill(im, color: img.ColorRgb8(0, 0, 0));
    im.setPixelRgb(2, 1, 255, 0, 0); // middle-right

    final r = img.copyRotate(im, angle: 90);
    expect(r.getPixel(1, 2).r, greaterThan(128),
        reason: 'middle-right moved to bottom-middle: clockwise');
  });

  test('the chosen angle brings a tilted eye line level', () {
    for (final tiltDegrees in [-30.0, -12.0, 0.0, 7.5, 25.0]) {
      final tilt = tiltDegrees * math.pi / 180;
      const gap = 60.0;
      // A tilted eye pair.
      final dx = gap * math.cos(tilt), dy = gap * math.sin(tilt);

      final theta = math.atan2(-dy, dx); // what the service computes
      // Apply that rotation to the eye vector.
      final c = math.cos(theta), s = math.sin(theta);
      final rotatedDy = dx * s + dy * c;

      expect(rotatedDy, closeTo(0, 1e-9),
          reason: 'a $tiltDegrees° tilt should end up level');
    }
  });

  test('rotating about the centre maps the old centre to the new centre', () {
    final from = math.Point<double>(50, 40), to = math.Point<double>(60, 55);
    final moved = rotatePoint(from, from, to, 0.7);
    expect(moved.x, closeTo(to.x, 1e-9));
    expect(moved.y, closeTo(to.y, 1e-9));
  });

  test('the eye midpoint lands on its canonical spot in the crop', () {
    const gap = 40.0;
    final boxSize = (gap / canonEyeGap).round();
    final eyeMid = math.Point<double>(200, 150);

    final cropX = eyeMid.x - canonEyeX * boxSize;
    final cropY = eyeMid.y - canonEyeY * boxSize;

    // Where the eyes sit once that crop is scaled to 112.
    final scale = 112 / boxSize;
    final eyeInCrop = math.Point<double>(
        (eyeMid.x - cropX) * scale, (eyeMid.y - cropY) * scale);

    expect(eyeInCrop.x, closeTo(55.91, 0.6));
    expect(eyeInCrop.y, closeTo(51.69, 0.6));
  });

  test('eye separation scales to the canonical 35 pixels', () {
    for (final gap in [20.0, 40.0, 130.0]) {
      final boxSize = (gap / canonEyeGap).round();
      expect(gap * (112 / boxSize), closeTo(35.24, 0.6),
          reason: 'a face at any distance normalises to the same scale');
    }
  });

  test('a face at the frame edge is padded, not shifted off its position', () {
    // _cutOut composites onto a black square rather than clamping the box.
    final source = img.Image(width: 100, height: 100);
    img.fill(source, color: img.ColorRgb8(255, 255, 255));

    const x = -20, y = -20, size = 60;
    final canvas = img.Image(width: size, height: size);
    img.fill(canvas, color: img.ColorRgb8(0, 0, 0));
    final piece = img.copyCrop(source,
        x: math.max(0, x), y: math.max(0, y),
        width: math.min(source.width, x + size) - math.max(0, x),
        height: math.min(source.height, y + size) - math.max(0, y));
    img.compositeImage(canvas, piece, dstX: math.max(0, x) - x, dstY: math.max(0, y) - y);

    expect(canvas.width, size);
    expect(canvas.getPixel(0, 0).r, lessThan(10), reason: 'outside the image: padded black');
    expect(canvas.getPixel(size - 1, size - 1).r, greaterThan(200),
        reason: 'inside the image: real pixels, still at the right offset');
  });
}
