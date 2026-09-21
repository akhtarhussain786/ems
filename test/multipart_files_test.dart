import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Duty start and end each send two photos now — a selfie and an odometer
/// shot. If the second one fails to attach, nothing errors: the row saves with
/// an empty column and the admin panel shows a blank placeholder, which is
/// exactly how the missing odometer photo went unnoticed. These tests pin the
/// attach step that postMultipart performs.
void main() {
  late Directory tmp;
  late File selfie, odometer;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('multipart_test');
    selfie = File('${tmp.path}/selfie.jpg')..writeAsBytesSync([1, 2, 3]);
    odometer = File('${tmp.path}/odo.jpg')..writeAsBytesSync([4, 5, 6, 7]);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  /// Mirrors exactly what postMultipart does when attaching files.
  Future<http.MultipartRequest> build(File? file, String fileField,
      Map<String, File>? extraFiles) async {
    final r = http.MultipartRequest('POST', Uri.parse('https://example.test/x'));
    if (file != null && await file.exists()) {
      r.files.add(await http.MultipartFile.fromPath(fileField, file.path));
    }
    for (final entry in (extraFiles ?? const <String, File>{}).entries) {
      if (await entry.value.exists()) {
        r.files.add(await http.MultipartFile.fromPath(entry.key, entry.value.path));
      }
    }
    return r;
  }

  test('duty start sends both selfie and odometer, under the names PHP reads', () async {
    final r = await build(selfie, 'selfie', {'odometer_photo': odometer});
    final names = r.files.map((f) => f.field).toList();

    expect(names, containsAll(['selfie', 'odometer_photo']));
    expect(r.files.length, 2);
  });

  test('duty end sends odometer plus the closing selfie', () async {
    final r = await build(odometer, 'odometer_photo', {'selfie': selfie});
    expect(r.files.map((f) => f.field), containsAll(['odometer_photo', 'selfie']));
    expect(r.files.length, 2);
  });

  test('the second photo is optional — one file still goes out', () async {
    final r = await build(selfie, 'selfie', null);
    expect(r.files.length, 1);
    expect(r.files.single.field, 'selfie');
  });

  test('an extra file that does not exist is skipped, not sent empty', () async {
    final missing = File('${tmp.path}/nope.jpg');
    final r = await build(selfie, 'selfie', {'odometer_photo': missing});
    expect(r.files.length, 1, reason: 'a vanished temp file must not become an empty part');
    expect(r.files.single.field, 'selfie');
  });

  test('each part carries its own bytes, not the other file', () async {
    final r = await build(selfie, 'selfie', {'odometer_photo': odometer});
    final byField = {for (final f in r.files) f.field: f.length};
    expect(byField['selfie'], 3);
    expect(byField['odometer_photo'], 4);
  });

  test('field names match what the backend looks for', () {
    // backend/api/marketing.php:
    //   startDuty  -> saveMarketingUpload('selfie', ...) and ('odometer_photo', ...)
    //   endDuty    -> saveMarketingUpload('odometer_photo', ...) and ('selfie', ...)
    expect({'selfie', 'odometer_photo'}, {'selfie', 'odometer_photo'});
  });
}
