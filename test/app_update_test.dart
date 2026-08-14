import 'package:flutter_test/flutter_test.dart';
import 'package:yatharthems_apps/services/app_update_service.dart';

void main() {
  group('version comparison', () {
    int cmp(String a, String b) => AppUpdateService.compareVersions(a, b);

    test('compares numerically, not as text', () {
      // The cases string comparison gets wrong.
      expect(cmp('1.0.9', '1.0.10'), lessThan(0));
      expect(cmp('1.9.0', '1.10.0'), lessThan(0));
      expect(cmp('1.10.0', '1.9.0'), greaterThan(0));
    });

    test('equal versions compare equal', () {
      expect(cmp('1.2.0', '1.2.0'), 0);
      expect(cmp('2.0.0', '2.0.0'), 0);
    });

    test('missing segments count as zero', () {
      expect(cmp('1.2', '1.2.0'), 0);
      expect(cmp('1', '1.0.0'), 0);
      expect(cmp('1.2', '1.2.1'), lessThan(0));
    });

    test('ignores build and pre-release suffixes', () {
      expect(cmp('1.2.0+7', '1.2.0'), 0);
      expect(cmp('1.2.0-beta', '1.2.0'), 0);
      expect(cmp('1.2.0+1', '1.3.0+9'), lessThan(0));
    });

    test('major beats minor beats patch', () {
      expect(cmp('2.0.0', '1.99.99'), greaterThan(0));
      expect(cmp('1.3.0', '1.2.99'), greaterThan(0));
    });

    test('garbage does not throw', () {
      expect(() => cmp('', '1.0.0'), returnsNormally);
      expect(() => cmp('abc', '1.0.0'), returnsNormally);
      expect(cmp('', '1.0.0'), lessThan(0));
    });
  });

  group('parsing the API response', () {
    Map<String, dynamic> payload({
      String version = '1.3.0',
      String url = 'https://ems.yatharthinstitution.in/ems/backend/uploads/apk/a.apk',
      dynamic force = false,
    }) =>
        {
          'success': true,
          'latest_version': version,
          'minimum_version': '1.0.0',
          'apk_url': url,
          'update_title': 'New Update Available',
          'update_message': 'Please update.',
          'file_size': '25 MB',
          'file_size_bytes': 26214400,
          'force_update': force,
          'sha256': 'abc123',
        };

    test('reads a well-formed release', () {
      final info = AppUpdateInfo.fromJson(payload())!;
      expect(info.latestVersion, '1.3.0');
      expect(info.minimumVersion, '1.0.0');
      expect(info.fileSizeBytes, 26214400);
      expect(info.sha256, 'abc123');
      expect(info.forceUpdate, isFalse);
    });

    test('accepts the several shapes force_update arrives in', () {
      expect(AppUpdateInfo.fromJson(payload(force: true))!.forceUpdate, isTrue);
      expect(AppUpdateInfo.fromJson(payload(force: 1))!.forceUpdate, isTrue);
      expect(AppUpdateInfo.fromJson(payload(force: '1'))!.forceUpdate, isTrue);
      expect(AppUpdateInfo.fromJson(payload(force: 0))!.forceUpdate, isFalse);
    });

    test('rejects a payload that would prompt an update to nowhere', () {
      expect(AppUpdateInfo.fromJson(payload(version: '')), isNull);
      expect(AppUpdateInfo.fromJson(payload(url: '')), isNull);
      // Never trust a non-http scheme from the server.
      expect(AppUpdateInfo.fromJson(payload(url: 'file:///data/evil.apk')), isNull);
      expect(AppUpdateInfo.fromJson(payload(url: 'javascript:alert(1)')), isNull);
    });
  });

  group('update decision', () {
    // Mirrors the rules in AppUpdateService.check().
    ({bool mandatory, bool prompt}) decide(
        String installed, String latest, String minimum, bool force) {
      final newer = AppUpdateService.compareVersions(installed, latest) < 0;
      final belowMin = AppUpdateService.compareVersions(installed, minimum) < 0;
      final mandatory = (force && newer) || belowMin;
      return (mandatory: mandatory, prompt: mandatory || newer);
    }

    test('same version prompts nothing', () {
      final d = decide('1.0.0', '1.0.0', '1.0.0', false);
      expect(d.prompt, isFalse);
    });

    test('newer available, force off, is optional', () {
      final d = decide('1.0.0', '1.1.0', '1.0.0', false);
      expect(d.prompt, isTrue);
      expect(d.mandatory, isFalse);
    });

    test('below the minimum is mandatory even with force off', () {
      final d = decide('1.0.0', '1.1.0', '1.1.0', false);
      expect(d.mandatory, isTrue);
    });

    test('force flag makes an available update mandatory', () {
      final d = decide('1.0.0', '1.1.0', '1.0.0', true);
      expect(d.mandatory, isTrue);
    });

    test('force flag cannot force an update to the version already installed', () {
      final d = decide('1.1.0', '1.1.0', '1.0.0', true);
      expect(d.prompt, isFalse, reason: 'nothing newer to install');
    });

    test('1.0.9 installed against 1.0.10 latest prompts', () {
      expect(decide('1.0.9', '1.0.10', '1.0.0', false).prompt, isTrue);
    });
  });
}
