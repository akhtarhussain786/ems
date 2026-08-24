import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Why a face could not be turned into an embedding.
///
/// Kept separate from the message so callers can react to the cause — a photo
/// with no face in it is worth retrying, a missing model is not.
enum FaceFailure {
  modelUnavailable,
  noFaceFound,
  multipleFaces,
  faceTooSmall,
  eyesClosed,
  poorAngle,
  unreadableImage,
  inferenceFailed,
}

class FaceResult {
  final List<double>? embedding;
  final FaceFailure? failure;
  final String? message;

  const FaceResult.success(this.embedding)
      : failure = null,
        message = null;

  const FaceResult.failed(this.failure, this.message) : embedding = null;

  bool get ok => embedding != null;
}

/// Turns a photograph into a face embedding, entirely on the device.
///
/// The model and the detector are loaded once and kept, because both are slow
/// to initialise and attendance is used twice a day by everyone at once.
///
/// The embedding is a list of numbers describing the face; the photograph
/// itself never leaves the phone as part of this, and the embedding cannot be
/// turned back into a picture.
class FaceEmbeddingService {
  FaceEmbeddingService._();
  static final FaceEmbeddingService instance = FaceEmbeddingService._();

  static const String _modelAsset = 'assets/models/mobilefacenet.tflite';

  /// A face smaller than this fraction of the frame is too coarse to identify
  /// reliably — the resulting embedding would be noise dressed up as a match.
  static const double _minFaceFraction = 0.10;

  Interpreter? _interpreter;
  FaceDetector? _detector;
  bool _triedLoading = false;
  int _inputSize = 112;
  int _embeddingLength = 192;
  String? _loadProblem;

  /// Whether face verification can run at all. False when the model asset has
  /// not been bundled, which leaves the rest of the app working normally.
  bool get isAvailable => _interpreter != null;

  /// Why the model could not be used, in words worth showing someone setting
  /// this up. Null when it loaded, or when no model was bundled at all.
  String? get loadProblem => _loadProblem;

  /// What the loaded model actually is, for the setup screen to display.
  String get modelDescription => _interpreter == null
      ? 'No model loaded'
      : '${_inputSize}x$_inputSize input, $_embeddingLength-value output';

  int get embeddingLength => _embeddingLength;

  String get modelVersion => 'mobilefacenet_${_embeddingLength}d';

  /// Loads the model. Safe to call repeatedly; the work happens once.
  Future<bool> initialise() async {
    if (_interpreter != null) return true;
    if (_triedLoading) return false;
    _triedLoading = true;

    try {
      // Checked before loading so a missing model is an ordinary "unavailable"
      // rather than an exception on every attendance screen.
      await rootBundle.load(_modelAsset);
    } catch (_) {
      return false;
    }

    try {
      final interpreter = await Interpreter.fromAsset(_modelAsset);

      final input = interpreter.getInputTensor(0);
      final output = interpreter.getOutputTensor(0);

      // Checked here rather than left to fail at inference. A quantised model
      // is the easy mistake to make when downloading one, and it would
      // otherwise surface as "face could not be processed" on every capture,
      // which points at the camera instead of at the model.
      if (input.type != TensorType.float32) {
        interpreter.close();
        _loadProblem = 'The model expects ${input.type.name} input, but this app '
            'sends float32. Use a non-quantised MobileFaceNet model.';
        return false;
      }
      if (input.shape.length != 4 || input.shape[1] != input.shape[2] || input.shape[3] != 3) {
        interpreter.close();
        _loadProblem = 'The model wants an input shaped ${input.shape}, which is '
            'not a square colour image. This does not look like a face model.';
        return false;
      }
      if (output.shape.last < 64 || output.shape.last > 1024) {
        interpreter.close();
        _loadProblem = 'The model returns ${output.shape.last} values per face. '
            'A face model returns roughly 128 to 512.';
        return false;
      }

      // Read from the model rather than assumed, so a differently sized one
      // works without a code change.
      _inputSize = input.shape[1];
      _embeddingLength = output.shape.last;

      _interpreter = interpreter;
      return true;
    } catch (e) {
      _interpreter = null;
      _loadProblem = 'The model file could not be loaded. It may be corrupt or '
          'not a TensorFlow Lite model. ($e)';
      return false;
    }
  }

  FaceDetector _faceDetector() {
    return _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableClassification: true, // eyes open / smiling probabilities
        enableLandmarks: true, // eye positions, used to align the crop
        minFaceSize: _minFaceFraction,
      ),
    );
  }

  /// Extracts an embedding from a photograph.
  ///
  /// [strict] applies the extra quality checks that enrollment needs. The
  /// enrolled template is compared against for as long as the employee works
  /// here, so a poor one is worth rejecting at capture; at check-in the same
  /// standard would just stop people clocking in.
  Future<FaceResult> embedFromFile(File photo, {bool strict = false}) async {
    if (!await initialise()) {
      return const FaceResult.failed(
        FaceFailure.modelUnavailable,
        'Face verification is not set up on this version of the app.',
      );
    }

    final Uint8List bytes;
    try {
      bytes = await photo.readAsBytes();
    } catch (_) {
      return const FaceResult.failed(
        FaceFailure.unreadableImage, 'Could not read the photo. Please try again.');
    }

    final faces = await _detectFaces(photo);
    if (faces == null) {
      return const FaceResult.failed(
        FaceFailure.unreadableImage, 'Could not read the photo. Please try again.');
    }
    if (faces.isEmpty) {
      return const FaceResult.failed(
        FaceFailure.noFaceFound, 'No face detected. Hold the phone at eye level in good light.');
    }
    if (strict && faces.length > 1) {
      return const FaceResult.failed(
        FaceFailure.multipleFaces, 'More than one face in the picture. Make sure only you are in the frame.');
    }

    // With several faces, the largest is the one holding the phone.
    faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
        .compareTo(a.boundingBox.width * a.boundingBox.height));
    final face = faces.first;

    // Upright already: package:image's JPEG decoder applies the EXIF
    // orientation itself and clears the tag, which is the same frame ML Kit
    // reports its bounding box in. No baking needed here — see
    // test/face_orientation_test.dart, which pins that behaviour.
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return const FaceResult.failed(
        FaceFailure.unreadableImage, 'Could not read the photo. Please try again.');
    }

    final frameArea = decoded.width * decoded.height;
    final faceArea = face.boundingBox.width * face.boundingBox.height;
    if (faceArea / frameArea < _minFaceFraction * _minFaceFraction) {
      return const FaceResult.failed(
        FaceFailure.faceTooSmall, 'Move closer so your face fills more of the frame.');
    }

    if (strict) {
      final left = face.leftEyeOpenProbability;
      final right = face.rightEyeOpenProbability;
      if (left != null && right != null && left < 0.4 && right < 0.4) {
        return const FaceResult.failed(
          FaceFailure.eyesClosed, 'Keep both eyes open and look at the camera.');
      }

      // A head turned or tilted far from square gives a template that later
      // straight-on check-ins will not match.
      final yaw = (face.headEulerAngleY ?? 0).abs();
      final roll = (face.headEulerAngleZ ?? 0).abs();
      if (yaw > 15 || roll > 15) {
        return const FaceResult.failed(
          FaceFailure.poorAngle, 'Look straight at the camera and hold the phone level.');
      }
    }

    try {
      final crop = _prepareFace(decoded, face);
      final embedding = _runModel(crop);
      return FaceResult.success(embedding);
    } catch (_) {
      return const FaceResult.failed(
        FaceFailure.inferenceFailed, 'Face could not be processed. Please try again.');
    }
  }

  Future<List<Face>?> _detectFaces(File photo) async {
    try {
      return await _faceDetector().processImage(InputImage.fromFile(photo));
    } catch (_) {
      return null;
    }
  }

  /// Canonical positions MobileFaceNet and its relatives are trained on:
  /// in a 112x112 crop the eyes sit level, at these coordinates.
  static const double _canonEyeY = 51.69 / 112;      // 0.4615 down the crop
  static const double _canonEyeX = 55.91 / 112;      // midway across
  static const double _canonEyeGap = 35.24 / 112;    // eye separation

  /// Produces the 112x112 face the model expects.
  ///
  /// Prefers aligning by the eyes. These models are trained on faces warped so
  /// the eyes are level and always in the same place, and feeding them a plain
  /// bounding-box crop instead costs a great deal of accuracy — enough that two
  /// photos of the same person taken minutes apart can fail to match. Rotating
  /// the eye line level and framing on the eyes recovers that.
  ///
  /// Falls back to the bounding box when ML Kit gives no eye positions, which
  /// it sometimes does at an extreme angle. A slightly worse crop still beats
  /// refusing to process the photo at all.
  img.Image _prepareFace(img.Image source, Face face) {
    final left = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final right = face.landmarks[FaceLandmarkType.rightEye]?.position;
    if (left == null || right == null) return _cropFace(source, face.boundingBox);

    final aligned = _alignByEyes(
      source,
      math.Point<double>(left.x.toDouble(), left.y.toDouble()),
      math.Point<double>(right.x.toDouble(), right.y.toDouble()),
    );
    return aligned ?? _cropFace(source, face.boundingBox);
  }

  /// Rotates the eye line level, then frames a square around the eyes.
  ///
  /// Returns null when the eyes are implausibly close together, which means the
  /// landmarks are wrong rather than the face being small.
  img.Image? _alignByEyes(img.Image source, math.Point<double> eyeA, math.Point<double> eyeB) {
    // Order by x, so "left" always means left-of-frame regardless of which eye
    // ML Kit labelled which.
    final l = eyeA.x <= eyeB.x ? eyeA : eyeB;
    final r = eyeA.x <= eyeB.x ? eyeB : eyeA;

    final dx = r.x - l.x;
    final dy = r.y - l.y;
    final gap = math.sqrt(dx * dx + dy * dy);
    if (gap < 8) return null;

    // copyRotate turns the image clockwise for a positive angle, so this is the
    // turn that brings the eye line to horizontal.
    final theta = math.atan2(-dy, dx);
    final rotated = theta.abs() < 0.01
        ? source
        : img.copyRotate(source, angle: theta * 180 / math.pi,
            interpolation: img.Interpolation.linear);

    // Where the eye midpoint ended up. copyRotate turns about the centre and
    // grows the canvas to fit, so the old centre maps to the new centre.
    final eyeMid = math.Point<double>((l.x + r.x) / 2, (l.y + r.y) / 2);
    final moved = _rotatePoint(
      eyeMid,
      math.Point<double>(source.width / 2, source.height / 2),
      math.Point<double>(rotated.width / 2, rotated.height / 2),
      theta,
    );

    // The eye separation fixes the scale: it is a known fraction of the crop.
    final boxSize = (gap / _canonEyeGap).round();
    if (boxSize < 16) return null;

    final cropX = (moved.x - _canonEyeX * boxSize).round();
    final cropY = (moved.y - _canonEyeY * boxSize).round();

    return img.copyResize(
      _cutOut(rotated, cropX, cropY, boxSize),
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.cubic,
    );
  }

  /// Rotates [p] about [from], expressed relative to [to]. Screen coordinates,
  /// y downwards, positive angle clockwise — matching copyRotate.
  math.Point<double> _rotatePoint(
      math.Point<double> p, math.Point<double> from, math.Point<double> to, double theta) {
    final dx = p.x - from.x;
    final dy = p.y - from.y;
    final cos = math.cos(theta);
    final sin = math.sin(theta);
    return math.Point<double>(
      to.x + dx * cos - dy * sin,
      to.y + dx * sin + dy * cos,
    );
  }

  /// A square region, padded with black where it runs past the edge.
  ///
  /// Clamping the box instead would shift the face off its canonical position,
  /// which is the very thing alignment is for; padding keeps the geometry and
  /// simply admits there were no pixels there.
  img.Image _cutOut(img.Image source, int x, int y, int size) {
    final canvas = img.Image(width: size, height: size);
    img.fill(canvas, color: img.ColorRgb8(0, 0, 0));

    final startX = math.max(0, x);
    final startY = math.max(0, y);
    final endX = math.min(source.width, x + size);
    final endY = math.min(source.height, y + size);
    if (endX <= startX || endY <= startY) return canvas;

    final piece = img.copyCrop(source,
        x: startX, y: startY, width: endX - startX, height: endY - startY);
    img.compositeImage(canvas, piece, dstX: startX - x, dstY: startY - y);
    return canvas;
  }

  /// Crops to the face with a margin, then resizes to what the model expects.
  ///
  /// The margin matters: models of this kind are trained on faces framed with a
  /// little forehead and chin, and a tight crop measurably degrades the match.
  img.Image _cropFace(img.Image source, Rect box) {
    final marginX = box.width * 0.15;
    final marginY = box.height * 0.15;

    var x = (box.left - marginX).round();
    var y = (box.top - marginY).round();
    var w = (box.width + marginX * 2).round();
    var h = (box.height + marginY * 2).round();

    // Clamp into the image, since the margin can push the box off the edge.
    x = x.clamp(0, source.width - 1);
    y = y.clamp(0, source.height - 1);
    w = w.clamp(1, source.width - x);
    h = h.clamp(1, source.height - y);

    final cropped = img.copyCrop(source, x: x, y: y, width: w, height: h);
    return img.copyResize(cropped,
        width: _inputSize, height: _inputSize, interpolation: img.Interpolation.cubic);
  }

  List<double> _runModel(img.Image face) {
    final interpreter = _interpreter!;

    // [1, size, size, 3] normalised to -1..1, which is what MobileFaceNet and
    // its relatives are trained on.
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final p = face.getPixel(x, y);
          return [
            (p.r - 127.5) / 127.5,
            (p.g - 127.5) / 127.5,
            (p.b - 127.5) / 127.5,
          ];
        }),
      ),
    );

    final output = List.generate(1, (_) => List<double>.filled(_embeddingLength, 0.0));
    interpreter.run(input, output);

    return _l2Normalise(output[0]);
  }

  /// Scales the vector to unit length.
  ///
  /// The server compares by cosine similarity, which ignores magnitude anyway;
  /// normalising here keeps the stored numbers small and consistent between
  /// enrollment and every later check-in.
  List<double> _l2Normalise(List<double> v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    final norm = math.sqrt(sum);
    if (norm == 0 || norm.isNaN || norm.isInfinite) return v;
    return v.map((x) => x / norm).toList();
  }

  /// Averages several captures into one template.
  ///
  /// Enrollment takes a few shots because a single frame bakes in whatever that
  /// moment happened to look like — a shadow, a half-blink, an odd angle. The
  /// mean of several is a noticeably steadier thing to match against.
  List<double>? averageEmbeddings(List<List<double>> samples) {
    if (samples.isEmpty) return null;
    final length = samples.first.length;
    if (samples.any((s) => s.length != length)) return null;

    final sum = List<double>.filled(length, 0.0);
    for (final sample in samples) {
      for (var i = 0; i < length; i++) {
        sum[i] += sample[i];
      }
    }
    for (var i = 0; i < length; i++) {
      sum[i] /= samples.length;
    }
    return _l2Normalise(sum);
  }

  /// Cosine similarity, matching the server's calculation.
  ///
  /// Used during enrollment to check the captures agree with each other; the
  /// decision that matters is still made on the server.
  double? similarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return null;
    var dot = 0.0, na = 0.0, nb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    final denominator = math.sqrt(na) * math.sqrt(nb);
    if (denominator == 0) return null;
    return (dot / denominator).clamp(-1.0, 1.0);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _detector?.close();
    _detector = null;
    _triedLoading = false;
  }
}
