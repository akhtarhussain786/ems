import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// Global navigator key so the session layer can force a logout from anywhere —
/// including from inside ApiService, which has no BuildContext of its own.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Owns the auth token and the moment it stops being valid.
///
/// Expiry is stored as an absolute timestamp rather than tracked with a Timer,
/// so it survives the app being backgrounded or killed by the OS.
class SessionManager {
  SessionManager._internal();
  static final SessionManager instance = SessionManager._internal();

  String? _token;
  int? _expiryEpoch; // seconds since epoch, mirrors the JWT `exp` claim
  bool _loaded = false;
  bool _loggingOut = false;

  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.loginKey);
    _expiryEpoch = prefs.getInt(AppConstants.tokenExpiryKey);

    // Tokens saved by older builds have no expiry recorded. Recover it from the
    // JWT itself so those sessions expire too, instead of living forever.
    if (_token != null && _token!.isNotEmpty && _expiryEpoch == null) {
      _expiryEpoch = _expFromJwt(_token!);
      if (_expiryEpoch != null) {
        await prefs.setInt(AppConstants.tokenExpiryKey, _expiryEpoch!);
      }
    }
    _loaded = true;
  }

  Future<String?> getToken() async {
    await load();
    return _token;
  }

  /// Persists a freshly issued token together with its expiry.
  ///
  /// The JWT `exp` claim is authoritative because it comes from the server's own
  /// clock; [expiresIn] from the login response is only a fallback.
  Future<void> saveSession(String token, {int? expiresIn}) async {
    final prefs = await SharedPreferences.getInstance();

    _token = token;
    _expiryEpoch = _expFromJwt(token) ??
        (expiresIn != null ? _nowEpoch() + expiresIn : null);
    _loaded = true;
    _loggingOut = false;

    await prefs.setString(AppConstants.loginKey, token);
    if (_expiryEpoch != null) {
      await prefs.setInt(AppConstants.tokenExpiryKey, _expiryEpoch!);
    } else {
      await prefs.remove(AppConstants.tokenExpiryKey);
    }
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Whether the stored token is past its expiry. Cheap and synchronous so it
  /// can be polled from a ticker. Returns false when there is no session to
  /// expire, or when the expiry is unknown — the 401 path is the backstop there.
  bool get isExpired {
    if (!hasToken) return false;
    final exp = _expiryEpoch;
    if (exp == null) return false;
    return _nowEpoch() >= exp;
  }

  Future<bool> hasValidSession() async {
    await load();
    return hasToken && !isExpired;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    _token = null;
    _expiryEpoch = null;
    _loaded = true;

    await prefs.remove(AppConstants.loginKey);
    await prefs.remove(AppConstants.userKey);
    await prefs.remove(AppConstants.tokenExpiryKey);
    await prefs.remove(AppConstants.loginTimestampKey);
  }

  /// Clears the session and sends the user back to login.
  ///
  /// Safe to call from several failing requests at once — only the first one
  /// navigates. The guard is released on the next successful login.
  Future<void> forceLogout({
    String reason = 'Session expired. Please login again.',
  }) async {
    if (_loggingOut) return;
    _loggingOut = true;

    await clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.autoLogoutFlagKey, true);
    await prefs.setString(AppConstants.autoLogoutReasonKey, reason);

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      // No navigator yet (e.g. during startup). The session is already cleared,
      // so splash will route to login on its own.
      _loggingOut = false;
      return;
    }

    // Not awaited: pushNamedAndRemoveUntil only completes when the login route
    // is popped, which would never happen here.
    navigator.pushNamedAndRemoveUntil(AppConstants.loginRoute, (route) => false);
  }

  int _nowEpoch() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// Reads the `exp` claim out of a JWT without verifying the signature —
  /// the server does the verifying; this is only used to know when to stop asking.
  int? _expFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      payload = payload.padRight(
        payload.length + ((4 - payload.length % 4) % 4),
        '=',
      );

      final decoded = jsonDecode(utf8.decode(base64.decode(payload)));
      if (decoded is! Map) return null;

      final exp = decoded['exp'];
      if (exp is int) return exp;
      return int.tryParse('$exp');
    } catch (_) {
      return null;
    }
  }
}
