import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yatharthems_apps/services/face_embedding_service.dart';

/// The heavy half of face verification now runs on a background isolate, so the
/// UI thread stays free. These check that moving it there did not change what it
/// produces — the pixels the model sees, and in what order.
void main() {
  /// A picture with a distinctly coloured square where the "face" is.
  img.Image scene({int w = 1200, int h = 1600}) {
    final im = img.Image(width: w, height: h);
    img.fill(im, color: img.ColorRgb8(20, 20, 20));
    img.fillRect(im,
        x1: 400, y1: 500, x2: 800, y2: 900, color: img.ColorRgb8(200, 120, 60));
    return im;
  }

  test('produces exactly inputSize x inputSize x 3 bytes', () {
    final bytes = img.encodeJpg(scene());
    final r = prepareFaceForModel(FacePrepRequest(
      bytes: bytes, boxLeft: 400, boxTop: 500, boxWidth: 400, boxHeight: 400,
      leftEyeX: null, leftEyeY: null, rightEyeX: null, rightEyeY: null,
      inputSize: 112, minFaceFraction: 0.10,
    ));
    expect(r.failure, isNull);
    expect(r.rgb, isNotNull);
    expect(r.rgb!.length, 112 * 112 * 3);
  });

  test('the crop actually contains the face, not the background', () {
    final bytes = img.encodeJpg(scene());
    final r = prepareFaceForModel(FacePrepRequest(
      bytes: bytes, boxLeft: 400, boxTop: 500, boxWidth: 400, boxHeight: 400,
      leftEyeX: null, leftEyeY: null, rightEyeX: null, rightEyeY: null,
      inputSize: 112, minFaceFraction: 0.10,
    ));
    // centre pixel of the crop should be the face colour, not the dark backdrop
    const centre = ((56 * 112) + 56) * 3;
    expect(r.rgb![centre], greaterThan(120), reason: 'red channel of the face square');
    expect(r.rgb![centre + 2], lessThan(140), reason: 'blue channel is low');
  });

  test('a face too small in the frame is refused, not silently cropped', () {
    final bytes = img.encodeJpg(scene());
    final r = prepareFaceForModel(FacePrepRequest(
      bytes: bytes, boxLeft: 10, boxTop: 10, boxWidth: 30, boxHeight: 30,
      leftEyeX: null, leftEyeY: null, rightEyeX: null, rightEyeY: null,
      inputSize: 112, minFaceFraction: 0.10,
    ));
    expect(r.rgb, isNull);
    expect(r.failure, 'tooSmall');
  });

  test('unreadable bytes fail cleanly rather than throwing', () {
    final r = prepareFaceForModel(FacePrepRequest(
      bytes: img.encodeJpg(scene()).sublist(0, 20),
      boxLeft: 0, boxTop: 0, boxWidth: 100, boxHeight: 100,
      leftEyeX: null, leftEyeY: null, rightEyeX: null, rightEyeY: null,
      inputSize: 112, minFaceFraction: 0.10,
    ));
    expect(r.rgb, isNull);
    expect(r.failure, isNotNull);
  });

  test('eye alignment path also returns a full-size buffer', () {
    final bytes = img.encodeJpg(scene());
    final r = prepareFaceForModel(FacePrepRequest(
      bytes: bytes, boxLeft: 400, boxTop: 500, boxWidth: 400, boxHeight: 400,
      leftEyeX: 500, leftEyeY: 640, rightEyeX: 700, rightEyeY: 680, // tilted
      inputSize: 112, minFaceFraction: 0.10,
    ));
    expect(r.failure, isNull);
    expect(r.rgb!.length, 112 * 112 * 3);
  });

  test('downscaling keeps the face where the box says it is', () {
    // A very large photo takes the downscale path; a small one does not.
    for (final dim in [[600, 800], [3000, 4000]]) {
      final im = img.Image(width: dim[0], height: dim[1]);
      img.fill(im, color: img.ColorRgb8(20, 20, 20));
      final fx = (dim[0] * 0.33).round(), fy = (dim[1] * 0.31).round();
      final fw = (dim[0] * 0.33).round(), fh = (dim[1] * 0.25).round();
      img.fillRect(im, x1: fx, y1: fy, x2: fx + fw, y2: fy + fh,
          color: img.ColorRgb8(200, 120, 60));

      final r = prepareFaceForModel(FacePrepRequest(
        bytes: img.encodeJpg(im),
        boxLeft: fx.toDouble(), boxTop: fy.toDouble(),
        boxWidth: fw.toDouble(), boxHeight: fh.toDouble(),
        leftEyeX: null, leftEyeY: null, rightEyeX: null, rightEyeY: null,
        inputSize: 112, minFaceFraction: 0.10,
      ));
      const centre = ((56 * 112) + 56) * 3;
      expect(r.rgb![centre], greaterThan(120),
          reason: 'face found at ${dim[0]}x${dim[1]}');
    }
  });
}
