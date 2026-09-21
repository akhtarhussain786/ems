import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Pins the orientation behaviour the face pipeline relies on.
///
/// ML Kit reads a photo upright, honouring its EXIF orientation tag. If
/// package:image did not do the same, the bounding box would be cropped out of
/// a sideways buffer and the embedding would describe a shoulder rather than a
/// face. It does do the same — the JPEG decoder applies the tag and clears it —
/// so no bakeOrientation call is needed. These tests fail loudly if a future
/// version of the package changes that, because the failure it would cause is
/// silent: faces that simply stop matching.
void main() {
  /// A landscape image tagged "rotate 90° clockwise", as a camera writes.
  img.Image taggedSideways() {
    final image = img.Image(width: 120, height: 60);
    img.fill(image, color: img.ColorRgb8(10, 120, 200));
    image.exif.imageIfd.orientation = 6;
    return image;
  }

  test('the JPEG decoder returns the image upright', () {
    final decoded = img.decodeImage(img.encodeJpg(taggedSideways()))!;

    expect(decoded.width, 60);
    expect(decoded.height, 120, reason: 'width and height swapped, so the tag was applied');
  });

  test('and clears the tag, so nothing downstream rotates it a second time', () {
    final decoded = img.decodeImage(img.encodeJpg(taggedSideways()))!;

    expect(decoded.exif.imageIfd.orientation, isNull);
    expect(img.bakeOrientation(decoded).width, decoded.width,
        reason: 'baking again must be a no-op');
  });

  test('an untagged image is returned exactly as it was', () {
    final plain = img.Image(width: 100, height: 40);
    img.fill(plain, color: img.ColorRgb8(0, 0, 0));
    final decoded = img.decodeImage(img.encodeJpg(plain))!;

    expect(decoded.width, 100);
    expect(decoded.height, 40);
  });

  test('copyResize does not rotate an already-decoded image', () {
    // _cropFace resizes the crop, and copyResize bakes orientation when the
    // tag is set. Since decoding clears it, the crop cannot be rotated again.
    final decoded = img.decodeImage(img.encodeJpg(taggedSideways()))!;
    final resized = img.copyResize(decoded, width: 112, height: 112);

    expect(resized.width, 112);
    expect(resized.height, 112);
  });
}
