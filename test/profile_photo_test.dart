import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yatharthems_apps/services/profile_photo_service.dart';
import 'package:yatharthems_apps/utils/constants.dart';
import 'package:yatharthems_apps/utils/profile_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolving which avatar to show', () {
    test('turns the relative path the API returns into an absolute URL', () {
      expect(
        ProfileImage.urlFor('uploads/profiles/profile_7_123.jpg'),
        '${AppConstants.baseUrl}/uploads/profiles/profile_7_123.jpg',
      );
    });

    test('leaves an absolute URL alone and tolerates a leading slash', () {
      expect(ProfileImage.urlFor('https://cdn.example.com/a.jpg'),
          'https://cdn.example.com/a.jpg');
      expect(ProfileImage.urlFor('/uploads/profiles/a.jpg'),
          '${AppConstants.baseUrl}/uploads/profiles/a.jpg');
    });

    test('treats absent, empty and the string "null" as no photo', () {
      expect(ProfileImage.urlFor(null), isNull);
      expect(ProfileImage.urlFor(''), isNull);
      expect(ProfileImage.urlFor('   '), isNull);
      expect(ProfileImage.urlFor('null'), isNull);
    });

    test('prefers the account photo over a file picked on this device', () {
      final image = ProfileImage.resolve(
        serverPhoto: 'uploads/profiles/a.jpg',
        localPath: '/data/user/0/cache/local.jpg',
      );
      expect(image, isA<NetworkImage>());
    });

    test('falls back to the local file only while there is no server copy', () {
      expect(
        ProfileImage.resolve(serverPhoto: null, localPath: '/tmp/local.jpg'),
        isA<FileImage>(),
      );
    });

    test('shows nothing when the account has no photo and none was picked', () {
      // A second device, freshly installed: this is the case that used to fail.
      expect(ProfileImage.resolve(serverPhoto: null, localPath: null), isNull);
      expect(ProfileImage.resolve(serverPhoto: '', localPath: ''), isNull);
    });
  });

  group('caching the uploaded photo', () {
    test('records the server path so it survives a restart', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.userKey: jsonEncode({'name': 'Zafar', 'employee_code': 'E1'}),
      });
      final prefs = await SharedPreferences.getInstance();

      await ProfilePhotoService.cacheServerPhoto(prefs, 'uploads/profiles/a.jpg');

      final cached = jsonDecode(prefs.getString(AppConstants.userKey)!);
      expect(cached['profile_photo'], 'uploads/profiles/a.jpg');
      expect(cached['name'], 'Zafar', reason: 'must not clobber other fields');
    });

    test('is a no-op when there is no cached user yet', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await ProfilePhotoService.cacheServerPhoto(prefs, 'uploads/profiles/a.jpg');

      expect(prefs.getString(AppConstants.userKey), isNull);
    });

    test('survives a corrupt cache instead of throwing', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.userKey: 'not json at all',
      });
      final prefs = await SharedPreferences.getInstance();

      await ProfilePhotoService.cacheServerPhoto(prefs, 'uploads/profiles/a.jpg');
      // reaching here without an exception is the assertion
      expect(prefs.getString(AppConstants.userKey), 'not json at all');
    });
  });
}
