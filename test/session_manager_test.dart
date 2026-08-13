import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yatharthems_apps/services/session_manager.dart';
import 'package:yatharthems_apps/utils/constants.dart';

/// A token shaped exactly like the ones backend/helpers/jwt_helper.php issues.
String buildToken({required int exp}) {
  // header/payload only — the signature is never checked client side
  const header = 'eyJ0eXAiOiAiSldUIiwgImFsZyI6ICJIUzI1NiJ9';
  final payload = base64Url
      .encode('{"user_id":12,"role":"employee","iat":1,"exp":$exp}'.codeUnits)
      .replaceAll('=', '');
  return '$header.$payload.c2lnbmF0dXJl';
}

int nowEpoch() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionManager.instance.load(force: true);
  });

  test('reads the expiry out of the JWT exp claim', () async {
    final exp = nowEpoch() + 43200;
    await SessionManager.instance.saveSession(buildToken(exp: exp));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AppConstants.tokenExpiryKey), exp);
    expect(SessionManager.instance.isExpired, isFalse);
    expect(await SessionManager.instance.hasValidSession(), isTrue);
  });

  test('reports an elapsed token as expired', () async {
    await SessionManager.instance.saveSession(buildToken(exp: nowEpoch() - 1));

    expect(SessionManager.instance.isExpired, isTrue);
    expect(await SessionManager.instance.hasValidSession(), isFalse);
  });

  test('falls back to expires_in when the token is not a JWT', () async {
    await SessionManager.instance.saveSession('opaque-token', expiresIn: 43200);

    expect(SessionManager.instance.isExpired, isFalse);

    await SessionManager.instance.saveSession('opaque-token', expiresIn: -1);
    expect(SessionManager.instance.isExpired, isTrue);
  });

  test('no session means nothing to expire', () async {
    await SessionManager.instance.clear();

    expect(SessionManager.instance.hasToken, isFalse);
    expect(SessionManager.instance.isExpired, isFalse);
  });

  test('recovers expiry for tokens stored before this key existed', () async {
    // an old build left a token behind but never recorded when it lapses
    SharedPreferences.setMockInitialValues({
      AppConstants.loginKey: buildToken(exp: nowEpoch() - 1),
    });
    await SessionManager.instance.load(force: true);

    expect(SessionManager.instance.isExpired, isTrue);
    expect(await SessionManager.instance.hasValidSession(), isFalse);
  });

  test('clear wipes token, user and expiry', () async {
    await SessionManager.instance
        .saveSession(buildToken(exp: nowEpoch() + 43200));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, '{"id":1}');

    await SessionManager.instance.clear();

    expect(prefs.getString(AppConstants.loginKey), isNull);
    expect(prefs.getString(AppConstants.userKey), isNull);
    expect(prefs.getInt(AppConstants.tokenExpiryKey), isNull);
    expect(SessionManager.instance.hasToken, isFalse);
  });
}
