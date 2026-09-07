import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Identifies the handset an account is allowed to sign in from.
///
/// Passwords get shared between colleagues, so the credential alone says
/// nothing about who is signing in. Binding an account to one device means a
/// borrowed password is not enough on somebody else's phone.
class DeviceIdentity {
  DeviceIdentity._internal();
  static final DeviceIdentity instance = DeviceIdentity._internal();

  static const String _fallbackKey = 'device_fallback_id';

  String? _cachedId;
  String? _cachedName;

  /// Stable identifier for this device.
  ///
  /// Prefers Android's own id, which survives reinstalling the app. Falls back
  /// to a value generated once and kept in preferences — that one is lost if
  /// app data is cleared, which is why it is only the fallback.
  Future<String> id() async {
    if (_cachedId != null) return _cachedId!;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await DeviceInfoPlugin().androidInfo;
        if (info.id.isNotEmpty) return _cachedId = info.id;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        final vendorId = info.identifierForVendor;
        if (vendorId != null && vendorId.isNotEmpty) return _cachedId = vendorId;
      }
    } catch (e) {
      debugPrint('DeviceIdentity: platform id unavailable, using fallback: $e');
    }

    return _cachedId = await _fallbackId();
  }

  /// Something an admin can recognise in the panel, e.g. "Redmi Note 12".
  Future<String> name() async {
    if (_cachedName != null) return _cachedName!;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await DeviceInfoPlugin().androidInfo;
        return _cachedName = '${info.manufacturer} ${info.model}'.trim();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        return _cachedName = info.name;
      }
    } catch (e) {
      debugPrint('DeviceIdentity: device name unavailable: $e');
    }
    return _cachedName = 'Unknown device';
  }

  Future<String> _fallbackId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_fallbackKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final rand = Random.secure();
    final generated = List<int>.generate(16, (_) => rand.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    await prefs.setString(_fallbackKey, generated);
    return generated;
  }
}
